param(
    [Parameter(Mandatory = $true)] [string]$Region,
    [Parameter(Mandatory = $true)] [string]$InstanceId,
    [string]$SecurityGroupId = "",
    [string]$ElasticIpAllocationId = ""
)

$ErrorActionPreference = "Stop"

Write-Host "Terminating instance $InstanceId ..." -ForegroundColor Cyan
aws ec2 terminate-instances --region $Region --instance-ids $InstanceId | Out-Null
aws ec2 wait instance-terminated --region $Region --instance-ids $InstanceId

if (-not [string]::IsNullOrWhiteSpace($SecurityGroupId)) {
    Write-Host "Deleting security group $SecurityGroupId ..." -ForegroundColor Cyan
    aws ec2 delete-security-group --region $Region --group-id $SecurityGroupId | Out-Null
}

if (-not [string]::IsNullOrWhiteSpace($ElasticIpAllocationId)) {
    Write-Host "Releasing Elastic IP $ElasticIpAllocationId ..." -ForegroundColor Cyan
    aws ec2 release-address --region $Region --allocation-id $ElasticIpAllocationId | Out-Null
}

Write-Host "Cleanup complete." -ForegroundColor Green
