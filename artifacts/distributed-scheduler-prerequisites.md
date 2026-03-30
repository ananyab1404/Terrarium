# Distributed Scheduler Prerequisites — Initialization Status

Based on the current workspace context (scheduler + DynamoDB state machine ownership), these are the required local prerequisites:

- Erlang/OTP 25+
- Elixir 1.14+
- AWS CLI v2
- AWS credentials/profile with DynamoDB + SQS permissions

## What Was Initialized

- Erlang/OTP installed successfully (detected at `C:\Program Files\Erlang OTP`)
- AWS CLI v2 installed successfully (detected at `C:\Program Files\Amazon\AWSCLIV2\aws.exe`)
- Elixir installation attempted via Chocolatey, but failed in a non-elevated shell (Windows permissions)

## Next Action (Required)

Run the setup script in **Administrator PowerShell** to finish Elixir install:

- `scripts/person-2/setup-prerequisites.ps1`

The script will:

1. Install missing tools
2. Refresh PATH for the current shell
3. Verify `erl`, `elixir`, `mix`, and `aws`

## AWS Setup Reminder

Before creating tables, configure credentials:

- `aws configure` or SSO profile setup
- Ensure permissions for:
  - `dynamodb:CreateTable`
  - `dynamodb:UpdateTimeToLive`
  - `dynamodb:DescribeTable`
  - `dynamodb:TagResource`

## DynamoDB Artifacts Added

- Schema design: `infra/dynamodb/scheduler-schema-v1.md`
- Table creation script: `infra/dynamodb/create-tables.ps1`
