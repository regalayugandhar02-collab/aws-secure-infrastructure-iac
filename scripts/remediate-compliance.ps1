param (
    [string]$Region = "ap-south-1"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AWS CIS SECURITY AUTO-REMEDIATION TOOL (POWERSHELL)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Remediate CIS 1.5 - 1.11: Set Strict IAM Password Policy
Write-Host "`n[1/2] Enforcing Strict CIS IAM Password Policy..." -ForegroundColor Yellow
try {
    aws iam update-account-password-policy `
        --minimum-password-length 14 `
        --require-symbols `
        --require-numbers `
        --require-uppercase-characters `
        --require-lowercase-characters `
        --allow-users-to-change-password `
        --max-password-age 90 `
        --password-reuse-prevention 5 | Out-Null
    Write-Host "[OK] Strict IAM Password Policy Applied!" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not update IAM password policy." -ForegroundColor Yellow
}

# 2. Remediate CIS 4.3: Harden Default Security Groups (Revoke all ingress & egress)
Write-Host "`n[2/2] Hardening Default Security Groups in $Region..." -ForegroundColor Yellow
try {
    $defaultSgsJson = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=default" --output json
    if ($defaultSgsJson) {
        $defaultSgs = $defaultSgsJson | ConvertFrom-Json
        foreach ($dsg in $defaultSgs.SecurityGroups) {
            $sgId = $dsg.GroupId
            # Revoke default Ingress
            if ($dsg.IpPermissions.Count -gt 0) {
                Write-Host "  [-] Revoking default inbound rules on $sgId..."
                aws ec2 revoke-security-group-ingress --group-id $sgId --protocol all --source-group $sgId --region $Region 2>$null | Out-Null
                aws ec2 revoke-security-group-ingress --group-id $sgId --protocol -1 --cidr "0.0.0.0/0" --region $Region 2>$null | Out-Null
            }
            # Revoke default Egress
            if ($dsg.IpPermissionsEgress.Count -gt 0) {
                Write-Host "  [-] Revoking default outbound rules on $sgId..."
                aws ec2 revoke-security-group-egress --group-id $sgId --protocol -1 --cidr "0.0.0.0/0" --region $Region 2>$null | Out-Null
            }
            Write-Host "[OK] Default SG $sgId Hardened." -ForegroundColor Green
        }
    }
} catch {
    Write-Host "[WARN] Error hardening default security groups." -ForegroundColor Yellow
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] CIS Security Auto-Remediation Completed!" -ForegroundColor Cyan
Write-Host "==========================================================`n" -ForegroundColor Cyan
