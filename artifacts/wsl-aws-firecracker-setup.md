# WSL + AWS + Firecracker Setup (Completed)

## Provisioned on 2026-03-31

- AWS Region: `us-east-1`
- Prefix: `infinity-node-dev-20260331`
- Account: `963957629631`

### S3 Buckets

- `infinity-node-dev-20260331-artifacts-963957629631`
- `infinity-node-dev-20260331-logs-963957629631`

Both buckets are configured with:

- default encryption: `AES256`
- public access block: enabled

### SQS Queue

- Name: `infinity-node-dev-20260331-jobs`
- URL: `https://sqs.us-east-1.amazonaws.com/963957629631/infinity-node-dev-20260331-jobs`
- ARN: `arn:aws:sqs:us-east-1:963957629631:infinity-node-dev-20260331-jobs`

### DynamoDB Tables

- `infinity-node-dev-20260331-jobs-v1`
- `infinity-node-dev-20260331-idempotency-v1`
- `infinity-node-dev-20260331-deadletter-v1`

TTL status:

- jobs: `ENABLED` (`ttl_archive_at`)
- idempotency: `ENABLED` (`expires_at`)
- deadletter: `ENABLED` (`ttl_archive_at`)

## Local Runtime Readiness

- WSL distro: Ubuntu (WSL2)
- Erlang: `26.2.1`
- Elixir: `1.16.1-otp-26`
- AWS CLI: working (`sts get-caller-identity`)
- Firecracker: installed (`v1.15.0`)
- Jailer: installed (`v1.15.0`)
- `/dev/kvm`: present and user in `kvm` group

## Commands to Run Project Tests in WSL

Use project-pinned versions via `mise`:

```bash
cd /mnt/c/Users/ludic/diva-lopers
~/.local/bin/mise x erlang@26.2.1 elixir@1.16.1-otp-26 -- mix deps.get
~/.local/bin/mise x erlang@26.2.1 elixir@1.16.1-otp-26 -- mix test
```

## Environment Variables for Integration Runs

Set these before integration smoke tests:

```bash
export AWS_REGION=us-east-1
export ARTIFACTS_BUCKET=infinity-node-dev-20260331-artifacts-963957629631
export LOGS_BUCKET=infinity-node-dev-20260331-logs-963957629631
export JOBS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/963957629631/infinity-node-dev-20260331-jobs
export JOBS_TABLE=infinity-node-dev-20260331-jobs-v1
export IDEMPOTENCY_TABLE=infinity-node-dev-20260331-idempotency-v1
export DEADLETTER_TABLE=infinity-node-dev-20260331-deadletter-v1
```

## Note

Docker daemon in WSL was not ready during setup. Firecracker does not require Docker, but any Docker-based local stack should be started separately if needed.
