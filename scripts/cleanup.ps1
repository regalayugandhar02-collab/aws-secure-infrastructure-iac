param (
    [string]$Region = "ap-south-1",
    [string]$ProjectName = "secure-cloud"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "         CLEANING UP AWS INFRASTRUCTURE RESOURCES          " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow

# Find and delete S3 Buckets created for the project
Write-Host "[+] Cleaning up project S3 Buckets..." -ForegroundColor Cyan
$bucketJson = aws s3api list-buckets --query "Buckets[?starts_with(Name, '$ProjectName-audit')].Name" --output json
if ($bucketJson) {
    $buckets = $bucketJson | ConvertFrom-Json
    foreach ($b in $buckets) {
        Write-Host "  [-] Deleting objects and bucket: $b"
        aws s3 rm "s3://$b" --recursive --region $Region | Out-Null
        aws s3api delete-bucket --bucket $b --region $Region | Out-Null
    }
}

# Find VPC
$vpcId = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" --query "Vpcs[0].VpcId" --output text --region $Region)

if ($vpcId -and $vpcId -ne "None") {
    Write-Host "[+] Found VPC: $vpcId. Deleting associated resources..." -ForegroundColor Cyan

    # Detach & Delete IGW
    $igwJson = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpcId" --query "InternetGateways[].InternetGatewayId" --output json --region $Region
    if ($igwJson) {
        $igws = $igwJson | ConvertFrom-Json
        foreach ($igw in $igws) {
            Write-Host "  [-] Detaching and deleting IGW: $igw"
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpcId --region $Region | Out-Null
            aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $Region | Out-Null
        }
    }

    # Delete Subnets
    $subnetJson = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[].SubnetId" --output json --region $Region
    if ($subnetJson) {
        $subnets = $subnetJson | ConvertFrom-Json
        foreach ($s in $subnets) {
            Write-Host "  [-] Deleting Subnet: $s"
            aws ec2 delete-subnet --subnet-id $s --region $Region | Out-Null
        }
    }

    # Delete Custom Route Tables
    $rtJson = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpcId" "Name=association.main,Values=false" --query "RouteTables[].RouteTableId" --output json --region $Region
    if ($rtJson) {
        $rts = $rtJson | ConvertFrom-Json
        foreach ($rt in $rts) {
            Write-Host "  [-] Deleting Route Table: $rt"
            aws ec2 delete-route-table --route-table-id $rt --region $Region | Out-Null
        }
    }

    # Delete Custom Security Groups
    $sgJson = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].GroupId" --output json --region $Region
    if ($sgJson) {
        $sgs = $sgJson | ConvertFrom-Json
        foreach ($sg in $sgs) {
            Write-Host "  [-] Deleting Security Group: $sg"
            aws ec2 delete-security-group --group-id $sg --region $Region | Out-Null
        }
    }

    # Delete VPC
    Write-Host "  [-] Deleting VPC: $vpcId"
    aws ec2 delete-vpc --vpc-id $vpcId --region $Region | Out-Null
    Write-Host "[OK] VPC Cleanup Completed!" -ForegroundColor Green
} else {
    Write-Host "[INFO] No VPC found with Name tag: $ProjectName-vpc" -ForegroundColor Yellow
}

Write-Host "==========================================================" -ForegroundColor Green
