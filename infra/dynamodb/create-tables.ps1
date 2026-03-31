param(
    [string]$TablePrefix = "infinity-node",
    [string]$Region = "us-east-1"
)

# Canonical schema definition lives in: infra/dynamodb/schema.yaml
# This script is an executable provisioning helper derived from that definition.

$ErrorActionPreference = "Stop"

function Invoke-Aws {
    param([Parameter(Mandatory = $true)][string[]]$Args)

    & aws @Args
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($Args -join ' ')"
    }
}

function New-TempJsonFile {
    param([Parameter(Mandatory = $true)][string]$Content)
    $temp = [System.IO.Path]::GetTempFileName() + ".json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($temp, $Content, $utf8NoBom)
    return $temp
}

$jobsTable = "$TablePrefix-jobs-v1"
$idempotencyTable = "$TablePrefix-idempotency-v1"
$deadletterTable = "$TablePrefix-deadletter-v1"

Write-Host "Creating DynamoDB tables in region $Region..." -ForegroundColor Cyan

$jobsSchema = @"
{
  "TableName": "$jobsTable",
  "BillingMode": "PAY_PER_REQUEST",
  "AttributeDefinitions": [
    {"AttributeName": "job_id", "AttributeType": "S"},
    {"AttributeName": "gsi1_pk", "AttributeType": "S"},
    {"AttributeName": "gsi1_sk", "AttributeType": "S"},
    {"AttributeName": "gsi2_pk", "AttributeType": "S"},
    {"AttributeName": "gsi2_sk", "AttributeType": "S"},
    {"AttributeName": "gsi3_pk", "AttributeType": "S"},
    {"AttributeName": "gsi3_sk", "AttributeType": "S"}
  ],
  "KeySchema": [
    {"AttributeName": "job_id", "KeyType": "HASH"}
  ],
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "by_state_lease",
      "KeySchema": [
        {"AttributeName": "gsi1_pk", "KeyType": "HASH"},
        {"AttributeName": "gsi1_sk", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "by_node_lease",
      "KeySchema": [
        {"AttributeName": "gsi2_pk", "KeyType": "HASH"},
        {"AttributeName": "gsi2_sk", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "by_tenant_state_created",
      "KeySchema": [
        {"AttributeName": "gsi3_pk", "KeyType": "HASH"},
        {"AttributeName": "gsi3_sk", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ],
  "StreamSpecification": {
    "StreamEnabled": true,
    "StreamViewType": "NEW_AND_OLD_IMAGES"
  },
  "Tags": [
    {"Key": "project", "Value": "infinity-node"},
    {"Key": "component", "Value": "scheduler"},
    {"Key": "owner", "Value": "person-2"}
  ]
}
"@

$idempotencySchema = @"
{
  "TableName": "$idempotencyTable",
  "BillingMode": "PAY_PER_REQUEST",
  "AttributeDefinitions": [
    {"AttributeName": "tenant_id", "AttributeType": "S"},
    {"AttributeName": "idempotency_key", "AttributeType": "S"},
    {"AttributeName": "job_id", "AttributeType": "S"},
    {"AttributeName": "created_at", "AttributeType": "N"}
  ],
  "KeySchema": [
    {"AttributeName": "tenant_id", "KeyType": "HASH"},
    {"AttributeName": "idempotency_key", "KeyType": "RANGE"}
  ],
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "by_job_id",
      "KeySchema": [
        {"AttributeName": "job_id", "KeyType": "HASH"},
        {"AttributeName": "created_at", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ],
  "Tags": [
    {"Key": "project", "Value": "infinity-node"},
    {"Key": "component", "Value": "scheduler"},
    {"Key": "owner", "Value": "person-2"}
  ]
}
"@

$deadletterSchema = @"
{
  "TableName": "$deadletterTable",
  "BillingMode": "PAY_PER_REQUEST",
  "AttributeDefinitions": [
    {"AttributeName": "tenant_id", "AttributeType": "S"},
    {"AttributeName": "failed_at_job", "AttributeType": "S"},
    {"AttributeName": "job_id", "AttributeType": "S"},
    {"AttributeName": "failed_at", "AttributeType": "N"}
  ],
  "KeySchema": [
    {"AttributeName": "tenant_id", "KeyType": "HASH"},
    {"AttributeName": "failed_at_job", "KeyType": "RANGE"}
  ],
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "by_job_id",
      "KeySchema": [
        {"AttributeName": "job_id", "KeyType": "HASH"},
        {"AttributeName": "failed_at", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ],
  "StreamSpecification": {
    "StreamEnabled": true,
    "StreamViewType": "NEW_AND_OLD_IMAGES"
  },
  "Tags": [
    {"Key": "project", "Value": "infinity-node"},
    {"Key": "component", "Value": "scheduler"},
    {"Key": "owner", "Value": "person-2"}
  ]
}
"@

$files = @(
    (New-TempJsonFile -Content $jobsSchema),
    (New-TempJsonFile -Content $idempotencySchema),
    (New-TempJsonFile -Content $deadletterSchema)
)

try {
    Invoke-Aws -Args @("dynamodb", "create-table", "--region", $Region, "--cli-input-json", ("file://" + $files[0]))
    Invoke-Aws -Args @("dynamodb", "create-table", "--region", $Region, "--cli-input-json", ("file://" + $files[1]))
    Invoke-Aws -Args @("dynamodb", "create-table", "--region", $Region, "--cli-input-json", ("file://" + $files[2]))

    Invoke-Aws -Args @("dynamodb", "update-time-to-live", "--region", $Region, "--table-name", $idempotencyTable, "--time-to-live-specification", "Enabled=true,AttributeName=expires_at")
    Invoke-Aws -Args @("dynamodb", "update-time-to-live", "--region", $Region, "--table-name", $jobsTable, "--time-to-live-specification", "Enabled=true,AttributeName=ttl_archive_at")
    Invoke-Aws -Args @("dynamodb", "update-time-to-live", "--region", $Region, "--table-name", $deadletterTable, "--time-to-live-specification", "Enabled=true,AttributeName=ttl_archive_at")

    Write-Host "Tables created. Waiting for ACTIVE state..." -ForegroundColor Cyan
    Invoke-Aws -Args @("dynamodb", "wait", "table-exists", "--region", $Region, "--table-name", $jobsTable)
    Invoke-Aws -Args @("dynamodb", "wait", "table-exists", "--region", $Region, "--table-name", $idempotencyTable)
    Invoke-Aws -Args @("dynamodb", "wait", "table-exists", "--region", $Region, "--table-name", $deadletterTable)

    Write-Host "Done: $jobsTable, $idempotencyTable, $deadletterTable" -ForegroundColor Green
}
finally {
    foreach ($file in $files) {
        Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    }
}
