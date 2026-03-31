# Person 3 — Complete Task Checklist
### Infinity Node — API, Observability & Infrastructure

---

## Phase 0 — Infrastructure Provisioning (Day 1 — BLOCKING)

> **Priority: CRITICAL.** Person 1 and Person 2 cannot start real work until these are done.
>
> **CODEBASE NOTE:** DynamoDB tables (jobs-v1, idempotency-v1, deadletter-v1) already have a
> full schema.yaml and create-tables.ps1 in `infra/dynamodb/`. The schema uses `-v1` suffix,
> `tenant_id` fields, composite GSI keys with sharding, and a separate deadletter table.
> Person 2's `Scheduler.JobStore` already has an adapter pattern.
> Person 1's `Worker.WorkerProcess` emits telemetry at `[:worker, :execution, :complete]`.

### 0.1 — Terraform/CDK Project Setup
- [x] Choose IaC tool: Terraform
- [x] Create `infra/terraform/` directory structure with `main.tf`, `variables.tf`, `outputs.tf`
- [x] Define Terraform provider block (AWS, region from variable)
- [x] Define shared variables: `aws_region`, `project_name` (default: `infinity-node`), `environment`
- [x] Create `.env.example` at project root with all required environment variables

### 0.2 — S3 Buckets
- [x] Create `infinity-node-artifacts` S3 bucket (versioning, encryption, private)
- [x] Create `infinity-node-logs` S3 bucket (30-day expiry, encryption, private)
- [x] Export both bucket names and ARNs in `outputs.tf`

### 0.3 — DynamoDB Tables
> **ALREADY DONE (by Person 2).**
- [x] Tables provisioned via `create-tables.ps1`
- [x] Table names/ARNs referenced in `outputs.tf`

### 0.4 — SQS Queues
- [x] Create `infinity-node-jobs-dlq` dead-letter queue
- [x] Create `infinity-node-jobs` main queue (600s visibility, 4-day retention, long polling, redrive to DLQ)
- [x] Export both queue URLs and ARNs in `outputs.tf`

### 0.5 — IAM Roles
- [x] ECS Task Execution Role + ECS Task Role (SQS, DynamoDB, S3, AutoScaling, SNS, CloudWatch)
- [x] Export both role ARNs in `outputs.tf`

### 0.6 — SNS Topic for Alerts
- [x] `infinity-node-alerts` topic + configurable email subscription

### 0.7 — ECS Cluster Skeleton
- [x] Cluster + API (Fargate) + Worker (EC2) task definitions
- ⬜ **INCOMPLETE:** Require `i3.metal` instance type via capacity provider (needs VPC + capacity provider)

### 0.8 — Application Load Balancer
> ⬜ **INCOMPLETE — BLOCKED:** ALB requires VPC ID and subnet IDs.
> Variables defined in `variables.tf` but values must be provided.
- ⬜ Create ALB + target group + listeners (blocked on VPC config)

### 0.9 — CloudWatch Log Groups
- [x] 3 log groups (api, worker, scheduler) with 14-day retention

### 0.10 — CloudWatch Alarms
- [x] DLQ depth > 0 alarm
- [x] Queue depth > 1000 alarm
- [x] P99 latency > 500ms alarm (custom `InfinityNode` namespace)
- [x] Active worker count = 0 alarm (custom `InfinityNode` namespace)

### 0.11 — Publish Infrastructure Outputs
- ⬜ **INCOMPLETE — BLOCKED:** `terraform init && terraform apply` (requires AWS credentials)
- [x] Outputs document generated in `outputs.tf` + `team_config_summary`
- ⬜ **INCOMPLETE — BLOCKED:** Share with team + verify access

---

## Phase 1 — Job Envelope Schema

### 1.1 — Create Shared Schema Module
- [x] `InfinityNode.JobEnvelope` — builder, validation, JSON serde, resource limit defaults/caps
- [x] `InfinityNode.ResultEnvelope` — type spec matching WorkerProcess output
- [x] `InfinityNode.TelemetryEnvelope` — telemetry event documentation

### 1.2 — Share and Agree on Schema
- ⬜ **INCOMPLETE — BLOCKED:** Share with Person 2 for review (team coordination)
- [x] Confirmed Person 1's WorkerProcess output matches result/telemetry envelopes
- ⬜ **INCOMPLETE — BLOCKED:** Document finalized schema (needs team agreement)

---

## Phase 2 — Phoenix API

### 2.1 — Phoenix Setup
- [x] All deps added to `apps/api/mix.exs` + root `mix.exs`
- ⬜ **INCOMPLETE — BLOCKED:** `mix deps.get` (requires Elixir/Erlang installed)
- [x] `Api.Endpoint`, `Api.Router`, `Api.Application` supervision tree all implemented
- ⬜ **INCOMPLETE — BLOCKED:** Verify Phoenix boots (requires Elixir/Erlang)

### 2.2–2.8 — Plugs, Controllers, Helpers
- [x] AuthPlug (x-api-key header), RateLimitPlug (ETS token bucket)
- [x] FunctionController (register + upload URL + webhook token)
- [x] InvocationController (sync poll + async + idempotency)
- [x] JobController (result retrieval with state-dependent response shapes)
- [x] HealthController (`GET /health`)
- [x] `Api.Helpers.Response`, `Api.ErrorJSON`

---

## Phase 3 — Telemetry Pipeline

- [x] `Api.Observability.TelemetryHandler` — attached to `[:worker, :execution, :complete]`
- [x] `Api.Observability.OtelExporter` — buffered CloudWatch Logs (100 records / 2s flush, 3 retries)
- [x] OTEL_ENDPOINT in `config/runtime.exs`

---

## Phase 4 — Real-Time Metrics Pipeline

- [x] `Api.Observability.MetricsReporter` — 9 metrics to CloudWatch every 10s
- [x] P50/P95/P99 percentiles, worker count, queue depth, failure rate, dead-letter count
- [x] `[:api, :request, :start/stop]` via Plug.Telemetry
- [x] Instrument individual controller actions with custom telemetry (`Api.Plugs.TelemetryPlug`)

---

## Phase 5 — Monitoring Dashboard

- [x] LiveDashboard at `/dashboard` with auth gating
- [x] 5 custom pages: Cluster Overview, Queue State, Latency, Job Explorer, Failure Log
- ⬜ **INCOMPLETE — BLOCKED:** Verify dashboard loads (requires Elixir/Erlang + deps)

---

## Phase 6 — Event-Driven Trigger System (Webhooks)

- [x] `WebhookController` with token validation + HMAC-SHA256 signature verification
- [x] Token generation on function registration (hash stored, plaintext returned once)
- [x] `POST /v1/functions/:id/rotate-webhook-token` endpoint
- [x] `POST /v1/webhooks/:function_id/:token` endpoint (webhook pipeline, no AuthPlug)
- [x] Constant-time comparison to prevent timing attacks

---

## Configuration & Wiring

- [x] `config/runtime.exs` — all 11 environment variables
- [x] `config/dev.exs` — debug logging, noop adapters, localstack template
- [x] `config/prod.exs` — info logging, origin checking, jailer enabled
- [x] `config/test.exs` — port 4002, server: false, test API key
- [x] Supervision tree fully wired (ETS → Telemetry → OtelExporter → MetricsReporter → Endpoint)

---

## Testing

### Unit Tests (written, need `mix test` to run)
- [x] `JobEnvelopeTest` — 9 tests (builder, validation, JSON, defaults, caps, errors, uniqueness)
- [x] `ResultEnvelopeTest` — 3 tests (atom keys, string keys, missing fields)
- [x] `AuthPlugTest` — 4 tests (valid, invalid, missing, empty)
- [x] `RateLimitPlugTest` — 5 tests (normal, burst, exhaustion, per-IP, X-Forwarded-For)
- [x] `OtelExporterTest` — 2 tests (empty buffer, record accumulation)
- ⬜ **INCOMPLETE — BLOCKED:** Run `mix test` (requires Elixir/Erlang)
- [x] Controller tests (FunctionController, InvocationController, JobController) via `Plug.Test`
- [x] MetricsReporter tests — metric collection, limit capping

### Integration Tests
- ⬜ **INCOMPLETE — BLOCKED:** Require running Phoenix + AWS/localstack

### Infrastructure Tests
- ⬜ **INCOMPLETE — BLOCKED:** Require AWS credentials for `terraform plan/apply`

---

## Documentation
- [x] Environment variables documented in `.env.example`
- [x] Root `README.md` with API endpoints, config, Terraform, LiveDashboard, project structure
- [x] Terraform usage documented (init, plan, apply, destroy)
- [x] How to run API locally documented (`mix phx.server`)
- [x] LiveDashboard access URL and auth requirements documented

---

## Summary of All Incomplete Items

### ⬜ Blocked by External Dependencies
| Item | Blocker |
|---|---|
| `mix deps.get` / `mix test` / `mix phx.server` | **Elixir/Erlang not installed on this machine** |
| `terraform init && terraform apply` | **AWS credentials + account required** |
| ALB creation | **VPC ID + subnet IDs required** |
| i3.metal capacity provider | **VPC + capacity provider setup required** |
| Share outputs with team | **Requires terraform apply first** |
| Verify LiveDashboard | **Requires Elixir + deps installed** |

### ⬜ Blocked by Team Coordination
| Item | Blocker |
|---|---|
| Share JobEnvelope schema with Person 2 | Person 2 review needed |
| Document finalized schema | Team agreement needed |

### ⬜ Remaining Code Work
| Item | Priority |
|---|---|
| Controller-level tests via Plug.Test | ~~Medium~~ **DONE** |
| MetricsReporter unit tests | ~~Medium~~ **DONE** |
| Integration tests with localstack | Medium (blocked on deps.get) |
| Custom telemetry for controller actions | ~~Low (stretch)~~ **DONE** |
| README.md + Terraform + LiveDashboard docs | ~~Medium~~ **DONE** |

---

*Task checklist — Person 3 — Infinity Node v1.0*
