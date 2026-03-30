param(
    [Parameter(Mandatory = $true)] [string]$Region,
    [Parameter(Mandatory = $true)] [string]$VpcId,
    [Parameter(Mandatory = $true)] [string]$SubnetId,
    [Parameter(Mandatory = $true)] [string]$KeyName,
    [Parameter(Mandatory = $true)] [string]$MyIpCidr,
    [string]$InstanceType = "i3.metal",
    [string]$AmiId = "",
    [string]$NameTag = "infinity-node-firecracker-host",
    [switch]$AssociateElasticIp
)

$ErrorActionPreference = "Stop"

function Assert-AwsCliInstalled {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "aws CLI not found. Install AWS CLI v2 first."
    }
}

Assert-AwsCliInstalled

Write-Host "Checking caller identity..." -ForegroundColor Cyan
aws sts get-caller-identity --region $Region | Out-Null

if ([string]::IsNullOrWhiteSpace($AmiId)) {
    Write-Host "Resolving latest Amazon Linux 2023 AMI via SSM..." -ForegroundColor Cyan
    $AmiId = aws ssm get-parameter `
        --region $Region `
        --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 `
        --query Parameter.Value `
        --output text
}

Write-Host "Validating instance type availability in region/subnet AZ..." -ForegroundColor Cyan
$subnetAz = aws ec2 describe-subnets --region $Region --subnet-ids $SubnetId --query "Subnets[0].AvailabilityZone" --output text
$offered = aws ec2 describe-instance-type-offerings --region $Region --location-type availability-zone --filters "Name=instance-type,Values=$InstanceType" "Name=location,Values=$subnetAz" --query "length(InstanceTypeOfferings)" --output text
if ($offered -eq "0") {
    throw "Instance type $InstanceType is not offered in AZ $subnetAz. Choose another subnet or instance type (e.g. c5.metal)."
}

Write-Host "Creating security group..." -ForegroundColor Cyan
$sgName = "${NameTag}-sg"
$sgId = aws ec2 create-security-group --region $Region --vpc-id $VpcId --group-name $sgName --description "Firecracker host access" --query GroupId --output text

aws ec2 create-tags --region $Region --resources $sgId --tags "Key=Name,Value=$sgName" "Key=project,Value=infinity-node" "Key=component,Value=worker-host"

# SSH ingress from operator IP only
aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --ip-permissions "[{\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"IpRanges\":[{\"CidrIp\":\"$MyIpCidr\",\"Description\":\"operator\"}]}]"

$userDataPath = Join-Path $PSScriptRoot "user-data-firecracker.sh"
if (-not (Test-Path $userDataPath)) {
    throw "Missing user data script: $userDataPath"
}

Write-Host "Launching EC2 instance..." -ForegroundColor Cyan
$instanceId = aws ec2 run-instances `
    --region $Region `
    --image-id $AmiId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --subnet-id $SubnetId `
    --security-group-ids $sgId `
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" `
    --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":80,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NameTag},{Key=project,Value=infinity-node},{Key=component,Value=worker-host}]" "ResourceType=volume,Tags=[{Key=project,Value=infinity-node},{Key=component,Value=worker-host}]" `
    --user-data ("file://" + $userDataPath) `
    --query "Instances[0].InstanceId" `
    --output text

Write-Host "Waiting for instance running state..." -ForegroundColor Cyan
aws ec2 wait instance-running --region $Region --instance-ids $instanceId

$publicIp = aws ec2 describe-instances --region $Region --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text

if ($AssociateElasticIp) {
    Write-Host "Allocating and associating Elastic IP..." -ForegroundColor Cyan
    $allocId = aws ec2 allocate-address --region $Region --domain vpc --query AllocationId --output text
    aws ec2 associate-address --region $Region --instance-id $instanceId --allocation-id $allocId | Out-Null
    $publicIp = aws ec2 describe-addresses --region $Region --allocation-ids $allocId --query "Addresses[0].PublicIp" --output text
    Write-Host "Elastic IP AllocationId: $allocId"
}

Write-Host "\n=== EC2 Host Created ===" -ForegroundColor Green
Write-Host "InstanceId : $instanceId"
Write-Host "SecurityGp : $sgId"
Write-Host "Public IP  : $publicIp"
Write-Host "AMI        : $AmiId"
Write-Host "Type       : $InstanceType"
Write-Host "\nSSH:" -ForegroundColor Yellow
Write-Host "ssh -i <path-to-key> ec2-user@$publicIp"

# TODO(other project integration):
# - attach IAM role/profile for S3 snapshot pulls and CloudWatch logs
# - install ECS agent if this host should join ECS capacity provider
