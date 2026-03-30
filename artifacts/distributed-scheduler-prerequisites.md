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

Run these commands in **Administrator PowerShell**:

1. Install Erlang/OTP

```powershell
winget install --id Erlang.ErlangOTP --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
```

2. Install AWS CLI v2

```powershell
winget install --id Amazon.AWSCLI --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
```

3. Install Elixir (skip Erlang dependency because Erlang is already installed)

```powershell
choco install elixir -y --no-progress --ignore-dependencies
```

4. Verify installs

```powershell
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
elixir --version
mix --version
aws --version
```

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
