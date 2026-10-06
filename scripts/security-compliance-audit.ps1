param (
    [string]$Region = "ap-south-1"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AWS CIS SECURITY COMPLIANCE AUDIT TOOL (POWERSHELL)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$results = @()

function Add-AuditResult {
    param(
        [string]$ControlId,
        [string]$Title,
        [string]$Status,
        [string]$Details
    )
    $script:results += [PSCustomObject]@{
        "Control ID"     = $ControlId
        "Security Check" = $Title
        "Status"         = $Status
        "Details"        = $Details
    }
}

# --- 1. IAM Password Policy (CIS 1.5 - 1.11) ---
Write-Host "`n[1/4] Auditing IAM Password Policy..." -ForegroundColor Yellow
try {
    $iamPolicyJson = aws iam get-account-password-policy --output json 2>$null
    if ($iamPolicyJson) {
        $iamPolicy = $iamPolicyJson | ConvertFrom-Json
        if ($iamPolicy -and $iamPolicy.PasswordPolicy) {
            $p = $iamPolicy.PasswordPolicy
            $passMinLength = $p.MinimumPasswordLength -ge 14
            $passSymbols = $p.RequireSymbols -eq $true
            $passNumbers = $p.RequireNumbers -eq $true
            $passUpper = $p.RequireUppercaseCharacters -eq $true
            $passLower = $p.RequireLowercaseCharacters -eq $true

            if ($passMinLength -and $passSymbols -and $passNumbers -and $passUpper -and $passLower) {
                Add-AuditResult "CIS-1.5-1.11" "IAM Password Policy Strength" "PASS" "Length >= 14, symbols, numbers, and case requirements enforced"
            } else {
                Add-AuditResult "CIS-1.5-1.11" "IAM Password Policy Strength" "FAIL" "Password policy is missing required complexity settings"
            }
        }
    } else {
        Add-AuditResult "CIS-1.5-1.11" "IAM Password Policy Strength" "FAIL" "No custom IAM password policy found in account"
    }
} catch {
    Add-AuditResult "CIS-1.5-1.11" "IAM Password Policy Strength" "FAIL" "Unable to query IAM password policy"
}

# --- 2. S3 Bucket Security (CIS 2.1.1 - 2.1.5) ---
Write-Host "[2/4] Auditing S3 Buckets Security..." -ForegroundColor Yellow
try {
    $bucketListJson = aws s3api list-buckets --query "Buckets[].Name" --output json
    $buckets = $bucketListJson | ConvertFrom-Json
    if ($buckets -and $buckets.Count -gt 0) {
        foreach ($b in $buckets) {
            # Check Public Access Block
            $pabJson = aws s3api get-public-access-block --bucket $b --output json 2>$null
            if ($pabJson) {
                $pab = $pabJson | ConvertFrom-Json
                if ($pab -and $pab.PublicAccessBlockConfiguration.BlockPublicAcls -and $pab.PublicAccessBlockConfiguration.BlockPublicPolicy) {
                    Add-AuditResult "CIS-2.1.1" "S3 Public Access Block [$($b)]" "PASS" "Public Access Block is strictly enabled"
                } else {
                    Add-AuditResult "CIS-2.1.1" "S3 Public Access Block [$($b)]" "FAIL" "Public access is NOT fully blocked"
                }
            } else {
                Add-AuditResult "CIS-2.1.1" "S3 Public Access Block [$($b)]" "FAIL" "Public Access Block configuration not found"
            }

            # Check Default Encryption
            $encJson = aws s3api get-bucket-encryption --bucket $b --output json 2>$null
            if ($encJson) {
                $enc = $encJson | ConvertFrom-Json
                if ($enc -and $enc.ServerSideEncryptionConfiguration) {
                    Add-AuditResult "CIS-2.1.5" "S3 Server-Side Encryption [$($b)]" "PASS" "Default encryption (SSE) is configured"
                } else {
                    Add-AuditResult "CIS-2.1.5" "S3 Server-Side Encryption [$($b)]" "FAIL" "Default encryption is NOT enabled"
                }
            } else {
                Add-AuditResult "CIS-2.1.5" "S3 Server-Side Encryption [$($b)]" "FAIL" "Default encryption is NOT configured"
            }
        }
    } else {
        Add-AuditResult "CIS-2.1" "S3 Bucket Auditing" "INFO" "No S3 buckets found in account"
    }
} catch {
    Add-AuditResult "CIS-2.1" "S3 Bucket Auditing" "FAIL" "Error querying S3 buckets"
}

# --- 3. Security Groups: Ingress Port 22 / 3389 Check (CIS 4.1 & 4.2) ---
Write-Host "[3/4] Auditing Security Group Ingress Rules..." -ForegroundColor Yellow
try {
    $sgsJson = aws ec2 describe-security-groups --region $Region --output json
    $sgs = $sgsJson | ConvertFrom-Json
    $sshViolation = $false
    $rdpViolation = $false

    foreach ($sg in $sgs.SecurityGroups) {
        foreach ($rule in $sg.IpPermissions) {
            $from = $rule.FromPort
            $to = $rule.ToPort
            $isGlobal = ($rule.IpRanges | Where-Object { $_.CidrIp -eq "0.0.0.0/0" }) -ne $null

            if ($isGlobal) {
                if (($from -le 22 -and $to -ge 22) -or $rule.IpProtocol -eq "-1") {
                    $sshViolation = $true
                    Add-AuditResult "CIS-4.1" "SG Port 22 (SSH) Ingress [$($sg.GroupId)]" "FAIL" "Port 22 is open to 0.0.0.0/0"
                }
                if (($from -le 3389 -and $to -ge 3389) -or $rule.IpProtocol -eq "-1") {
                    $rdpViolation = $true
                    Add-AuditResult "CIS-4.2" "SG Port 3389 (RDP) Ingress [$($sg.GroupId)]" "FAIL" "Port 3389 is open to 0.0.0.0/0"
                }
            }
        }
    }

    if (-not $sshViolation) {
        Add-AuditResult "CIS-4.1" "SG Port 22 (SSH) World Ingress" "PASS" "No security groups allow unrestricted SSH (0.0.0.0/0)"
    }
    if (-not $rdpViolation) {
        Add-AuditResult "CIS-4.2" "SG Port 3389 (RDP) World Ingress" "PASS" "No security groups allow unrestricted RDP (0.0.0.0/0)"
    }
} catch {
    Add-AuditResult "CIS-4.1/2" "Security Group Ingress Audit" "FAIL" "Error querying Security Groups"
}

# --- 4. Default Security Group Hardening (CIS 4.3) ---
Write-Host "[4/4] Auditing Default Security Groups..." -ForegroundColor Yellow
try {
    $defaultSgsJson = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=default" --output json
    $defaultSgs = $defaultSgsJson | ConvertFrom-Json
    foreach ($dsg in $defaultSgs.SecurityGroups) {
        $hasRules = ($dsg.IpPermissions.Count -gt 0) -or ($dsg.IpPermissionsEgress.Count -gt 0)
        if (-not $hasRules) {
            Add-AuditResult "CIS-4.3" "Default SG Traffic Hardening [$($dsg.GroupId)]" "PASS" "All inbound and outbound traffic restricted"
        } else {
            Add-AuditResult "CIS-4.3" "Default SG Traffic Hardening [$($dsg.GroupId)]" "FAIL" "Default SG still contains active rules"
        }
    }
} catch {
    Add-AuditResult "CIS-4.3" "Default SG Traffic Hardening" "FAIL" "Error checking default security groups"
}

# --- Display Formatted Audit Report ---
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                COMPLIANCE AUDIT REPORT                   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize

$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
$total = $results.Count

Write-Host "Summary: Total Checks: $total | Passed: $passCount | Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "==========================================================`n" -ForegroundColor Cyan
