param (
    [string]$Region = "ap-south-1",
    [string]$ProjectName = "secure-cloud",
    [string]$VpcCidr = "10.0.0.0/16"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AWS SECURE INFRASTRUCTURE DEPLOYMENT (POWERSHELL)      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check AWS CLI Authentication
try {
    $callerJson = aws sts get-caller-identity --output json
    $callerIdentity = $callerJson | ConvertFrom-Json
    Write-Host "[OK] AWS CLI Authenticated as Account: $($callerIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS CLI is not configured or failed to authenticate." -ForegroundColor Red
    exit 1
}

# Auto-detect region if default is needed
if (-not $Region) {
    $Region = "ap-south-1"
}
Write-Host "[INFO] Deploying to AWS Region: $Region" -ForegroundColor Cyan

# 2. Create VPC
Write-Host "`n[+] Creating Custom VPC ($VpcCidr)..." -ForegroundColor Yellow
$tagSpec = "ResourceType=vpc,Tags=[{Key=Name,Value=$ProjectName-vpc},{Key=Compliance,Value=CIS-Benchmark}]"
$vpcJson = aws ec2 create-vpc --cidr-block $VpcCidr --region $Region --tag-specifications $tagSpec --output json
$vpcObj = $vpcJson | ConvertFrom-Json
$vpcId = $vpcObj.Vpc.VpcId
Write-Host "[OK] VPC Created: $vpcId" -ForegroundColor Green

# Enable DNS Hostnames and DNS Support
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\`"Value\`":true}" --region $Region
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support "{\`"Value\`":true}" --region $Region

# 3. Create Internet Gateway
Write-Host "`n[+] Creating Internet Gateway..." -ForegroundColor Yellow
$igwTag = "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$ProjectName-igw}]"
$igwJson = aws ec2 create-internet-gateway --region $Region --tag-specifications $igwTag --output json
$igwObj = $igwJson | ConvertFrom-Json
$igwId = $igwObj.InternetGateway.InternetGatewayId
aws ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $igwId --region $Region
Write-Host "[OK] Internet Gateway Created and Attached: $igwId" -ForegroundColor Green

# 4. Create Subnets
$az1 = "${Region}a"
$az2 = "${Region}b"

Write-Host "`n[+] Creating Subnets in $az1 and $az2..." -ForegroundColor Yellow

$pub1Tag = "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-1}]"
$pubSub1Json = aws ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.1.0/24" --availability-zone $az1 --region $Region --tag-specifications $pub1Tag --output json
$pubSub1 = ($pubSub1Json | ConvertFrom-Json).Subnet.SubnetId

$pub2Tag = "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-2}]"
$pubSub2Json = aws ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.2.0/24" --availability-zone $az2 --region $Region --tag-specifications $pub2Tag --output json
$pubSub2 = ($pubSub2Json | ConvertFrom-Json).Subnet.SubnetId

$priv1Tag = "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-1}]"
$privSub1Json = aws ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.10.0/24" --availability-zone $az1 --region $Region --tag-specifications $priv1Tag --output json
$privSub1 = ($privSub1Json | ConvertFrom-Json).Subnet.SubnetId

$priv2Tag = "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-2}]"
$privSub2Json = aws ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.11.0/24" --availability-zone $az2 --region $Region --tag-specifications $priv2Tag --output json
$privSub2 = ($privSub2Json | ConvertFrom-Json).Subnet.SubnetId

Write-Host "[OK] Public Subnets: $pubSub1, $pubSub2" -ForegroundColor Green
Write-Host "[OK] Private Subnets: $privSub1, $privSub2" -ForegroundColor Green

# 5. Route Tables
Write-Host "`n[+] Configuring Route Tables..." -ForegroundColor Yellow
$pubRtTag = "ResourceType=route-table,Tags=[{Key=Name,Value=$ProjectName-public-rt}]"
$pubRtJson = aws ec2 create-route-table --vpc-id $vpcId --region $Region --tag-specifications $pubRtTag --output json
$pubRt = ($pubRtJson | ConvertFrom-Json).RouteTable.RouteTableId

aws ec2 create-route --route-table-id $pubRt --destination-cidr-block "0.0.0.0/0" --gateway-id $igwId --region $Region | Out-Null
aws ec2 associate-route-table --subnet-id $pubSub1 --route-table-id $pubRt --region $Region | Out-Null
aws ec2 associate-route-table --subnet-id $pubSub2 --route-table-id $pubRt --region $Region | Out-Null

$privRtTag = "ResourceType=route-table,Tags=[{Key=Name,Value=$ProjectName-private-rt}]"
$privRtJson = aws ec2 create-route-table --vpc-id $vpcId --region $Region --tag-specifications $privRtTag --output json
$privRt = ($privRtJson | ConvertFrom-Json).RouteTable.RouteTableId

aws ec2 associate-route-table --subnet-id $privSub1 --route-table-id $privRt --region $Region | Out-Null
aws ec2 associate-route-table --subnet-id $privSub2 --route-table-id $privRt --region $Region | Out-Null
Write-Host "[OK] Route Tables Configured and Associated" -ForegroundColor Green

# 6. Security Groups
Write-Host "`n[+] Creating Least-Privilege Security Groups..." -ForegroundColor Yellow
$webSgJson = aws ec2 create-security-group --group-name "$ProjectName-web-sg" --description "Web DMZ SG" --vpc-id $vpcId --region $Region --output json
$webSg = ($webSgJson | ConvertFrom-Json).GroupId

aws ec2 authorize-security-group-ingress --group-id $webSg --protocol tcp --port 80 --cidr "0.0.0.0/0" --region $Region | Out-Null
aws ec2 authorize-security-group-ingress --group-id $webSg --protocol tcp --port 443 --cidr "0.0.0.0/0" --region $Region | Out-Null

$appSgJson = aws ec2 create-security-group --group-name "$ProjectName-app-sg" --description "Internal App SG" --vpc-id $vpcId --region $Region --output json
$appSg = ($appSgJson | ConvertFrom-Json).GroupId
aws ec2 authorize-security-group-ingress --group-id $appSg --protocol tcp --port 8080 --source-group $webSg --region $Region | Out-Null

Write-Host "[OK] Web SG ($webSg) and App SG ($appSg) Created" -ForegroundColor Green

# 7. S3 Bucket
$randVal = Get-Random -Minimum 10000 -Maximum 99999
$bucketName = "$ProjectName-audit-$randVal"
Write-Host "`n[+] Creating Encrypted S3 Bucket: $bucketName..." -ForegroundColor Yellow

if ($Region -eq "us-east-1") {
    aws s3api create-bucket --bucket $bucketName --region $Region | Out-Null
} else {
    aws s3api create-bucket --bucket $bucketName --region $Region --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
}

# CIS S3 Controls
aws s3api put-public-access-block --bucket $bucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region $Region
aws s3api put-bucket-encryption --bucket $bucketName --server-side-encryption-configuration "{\`"Rules\`": [{\`"ApplyServerSideEncryptionByDefault\`": {\`"SSEAlgorithm\`": \`"AES256\`"}}]}" --region $Region
aws s3api put-bucket-versioning --bucket $bucketName --versioning-configuration "Status=Enabled" --region $Region

Write-Host "[OK] CIS-Compliant S3 Bucket Created and Hardened" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] Infrastructure Deployment Completed Successfully!" -ForegroundColor Cyan
Write-Host " VPC ID: $vpcId"
Write-Host " S3 Bucket: $bucketName"
Write-Host " Web SG: $webSg | App SG: $appSg"
Write-Host "==========================================================" -ForegroundColor Cyan
