# Person 3 — Detailed Summary
### API, Observability & Infrastructure — Infinity Node

---

## 1. Who You Are in This System

You are the **integration backbone** of Infinity Node. You own three distinct pillars:

| Pillar | What It Covers | Who Depends on It |
|---|---|---|
| **Infrastructure** | AWS resource provisioning — S3, SQS, DynamoDB, ECS, IAM, CloudWatch | Person 1 (needs S3 buckets, metal EC2), Person 2 (needs SQS URLs, DynamoDB tables, IAM roles) |
| **API** | Phoenix HTTP API — the only surface developers interact with directly | External developers, Person 2's scheduler (receives job envelopes via SQS) |
| **Observability** | Telemetry pipeline, OpenTelemetry export, CloudWatch metrics, LiveDashboard | Operations team, all three engineers during debugging and hardening |

**Critical insight:** You are the Day 1 blocker. Person 1 cannot test Firecracker without S3 buckets. Person 2 cannot build the SQS consumer without queue URLs or the state machine without DynamoDB tables. Infrastructure provisioning is your highest-priority first task — before writing a single line of Phoenix code.

---

## 2. The Architecture You Sit In

### Your Position in the Data Flow

```
Developer (HTTP client)
    │
    ▼
[AWS Application Load Balancer]
    │
    ▼
[Phoenix API — YOUR CODE]
    │   ├── Validates input
    │   ├── Writes job to DynamoDB (state: PENDING)
    │   ├── Enqueues job envelope to SQS
    │   └── Generates presigned S3 URLs for artifact upload
    │
    ├──────────► [SQS Queue] ──► Person 2's SQSConsumer
    ├──────────► [DynamoDB]  ──► Person 2 writes state transitions; you READ for result retrieval
    └──────────► [S3]        ──► Developer uploads artifacts; Person 1 writes execution logs
                                 you READ logs for result envelope URLs

[Observability Pipeline — YOUR CODE]
    ├── :telemetry handler ◄── Person 1's WorkerProcess emits events
    ├── OpenTelemetry batch exporter → CloudWatch Logs
    ├── Telemetry.Metrics reporter → CloudWatch Metrics (10s intervals)
    └── Phoenix LiveDashboard with 5 custom pages
```

### Key Architectural Boundaries

- **You do NOT own the job state machine.** Person 2 owns all DynamoDB conditional writes for state transitions. You only *read* job state for the result retrieval endpoint (`GET /v1/jobs/:job_id`).
- **You do NOT own execution.** Person 1's WorkerProcess executes functions in Firecracker VMs. You consume the telemetry events they emit.
- **You DO own the contract.** The `InfinityNode.JobEnvelope` schema is yours. It's the bridge between your API, Person 2's scheduler, and Person 1's execution engine. If this schema is wrong, everyone is blocked.

---

## 3. Your Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| HTTP API | Elixir / Phoenix | Stateless controllers, JSON serialization, Plugs for auth + rate limiting |
| Infrastructure | Terraform (or AWS CDK) | Infrastructure-as-code for all AWS resources |
| Telemetry Collection | Elixir `:telemetry` library | Attach handlers to events emitted by WorkerProcess |
| Telemetry Export | OpenTelemetry Elixir SDK | Batch telemetry records, ship to CloudWatch Logs |
| Metrics Reporting | `Telemetry.Metrics` + `TelemetryMetricsCloudwatch` | Per-node aggregation → CloudWatch Metrics every 10s |
| Dashboard | Phoenix LiveDashboard | Real-time operational UI via WebSocket, custom pages |
| AWS Services | S3, SQS, DynamoDB, ECS, IAM, CloudWatch, SNS | Storage, queueing, state, compute, permissions, observability, alerting |

---

## 4. Phase-by-Phase Breakdown

### Phase 0 — Infrastructure Provisioning (Day 1 — Highest Priority)

**This is the single most important thing you do first.** Both teammates are blocked until you deliver.

| Resource | Name | Configuration Details |
|---|---|---|
| S3 Bucket | `infinity-node-artifacts` | Versioning ON. Stores function tarballs and VM snapshots. |
| S3 Bucket | `infinity-node-logs` | Lifecycle rule: expire objects after 30 days. Stores stdout/stderr per execution. |
| DynamoDB Table | `infinity-node-jobs` | PK: `job_id` (String). GSI: `(state, lease_expires_at)` for lease reaper queries. PITR ON. |
| DynamoDB Table | `infinity-node-idempotency` | PK: `idempotency_key` (String). TTL attribute: `ttl`. Auto-expires after 24h. |
| SQS Queue | `infinity-node-jobs` | Standard (not FIFO). VisibilityTimeout: 600s. Redrive policy: MaxReceiveCount 3 → DLQ. |
| SQS Queue | `infinity-node-jobs-dlq` | Dead-letter queue. Receives messages after 3 failed processing attempts. |
| IAM Role | Task Execution Role | ECR pull, CloudWatch log write — AWS-managed plumbing. |
| IAM Role | Task Role (Application) | SQS read/delete, DynamoDB read/write, S3 read/write, Auto Scaling SetDesiredCapacity, SNS Publish. |
| ECS Cluster | `infinity-node` | Two task definitions: API (Fargate), Worker (EC2 with i3.metal capacity provider). Do NOT launch yet. |
| CloudWatch Log Groups | `/infinity-node/api`, `/infinity-node/worker`, `/infinity-node/scheduler` | Retention: 14 days. |
| CloudWatch Alarms | 4 alarms | DLQ depth > 0, P99 > 500ms for 5min, worker count = 0, queue depth > 1000 for 10min. All → SNS topic. |

**Deliverable:** A Terraform `outputs.tf` (or equivalent) file containing all ARNs, URLs, and table names. Share with Person 1 and Person 2 *before they begin Phase 1*.

---

### Phase 1 — Job Envelope Schema Definition

You own the canonical contract shared across all three apps. This Elixir module must be importable by `apps/api`, `apps/scheduler`, and `apps/worker`.

**Job Envelope** — written to SQS by your API, consumed by Person 2:
```elixir
%{
  job_id:           String.t(),           # UUID v4
  idempotency_key:  String.t(),           # client-provided
  function_id:      String.t(),           # registered function identifier
  artifact_s3_key:  String.t(),           # s3://infinity-node-artifacts/<hash>
  input_payload:    map(),                # arbitrary JSON
  resource_limits:  %{
    cpu_shares:     pos_integer(),        # default: 1024
    memory_mb:      pos_integer(),        # default: 256
    timeout_ms:     pos_integer()         # default: 30_000, max: 300_000
  },
  retry_count:      non_neg_integer(),    # starts at 0, max 3
  enqueued_at:      DateTime.t()
}
```

**Result Envelope** — returned by Person 1's WorkerProcess, consumed by your result retrieval endpoint:
```elixir
%{
  job_id:             String.t(),
  exit_code:          integer(),
  stdout_s3_key:      String.t(),         # logs/{job_id}/stdout
  stderr_s3_key:      String.t(),         # logs/{job_id}/stderr
  wall_time_ms:       non_neg_integer(),
  peak_memory_bytes:  non_neg_integer()
}
```

**Telemetry Envelope** — emitted by Person 1's WorkerProcess via `:telemetry.execute/3`, consumed by your telemetry handler:
```elixir
%{
  job_id:                String.t(),
  function_id:           String.t(),
  function_version:      String.t(),
  node_id:               String.t(),
  vm_slot_index:         non_neg_integer(),
  queue_wait_ms:         non_neg_integer(),
  execution_wall_ms:     non_neg_integer(),
  peak_memory_bytes:     non_neg_integer(),
  exit_code:             integer(),
  failure_reason:        String.t() | nil,
  stdout_s3_key:         String.t(),
  stderr_s3_key:         String.t(),
  cost_receipt:          map() | nil       # stretch goal 6.1
}
```

---

### Phase 2 — Phoenix HTTP API

Five endpoints, all under `/v1/`. Stateless and horizontally scalable behind ALB.

| Endpoint | Method | Purpose | Key Behavior |
|---|---|---|---|
| `/v1/functions` | POST | Register a function | Writes to DynamoDB. Returns `function_id`. |
| `/v1/functions/:id/upload-url` | POST | Get presigned S3 PUT URL | Developer uploads tarball directly to S3. API never touches the binary. |
| `/v1/functions/:id/invoke` | POST | Synchronous invocation | Writes job to DynamoDB (PENDING), enqueues to SQS, **polls DynamoDB every 500ms** until TERMINAL or timeout. Falls back to 202 if timeout exceeded. |
| `/v1/functions/:id/invoke/async` | POST | Async invocation | Same as above but returns 202 + `job_id` immediately. |
| `/v1/jobs/:job_id` | GET | Result retrieval | Consistent DynamoDB read. Returns full envelope if TERMINAL, current state if not, failure reason if dead-lettered. |

**Error Handling:**
- `400` — validation failure (malformed input, unknown function ID)
- `409` — idempotency key conflict (returns existing `job_id`)
- `429` — rate limited (per-IP token bucket via Plug)
- `503` — SQS enqueue failure (surfaced explicitly, **never silently dropped**)

**Authentication:** MVP uses a single static API key checked via `x-api-key` header in a Plug. Not production-ready — marked as TODO.

**Plugs to implement:**
- `AuthPlug` — static API key validation
- `RateLimitPlug` — per-IP token bucket

---

### Phase 3 — Telemetry Envelope + OpenTelemetry Export

**Flow:**
1. Person 1's `WorkerProcess` emits `:telemetry.execute([:infinity_node, :execution, :complete], measurements, metadata)` with the telemetry envelope
2. Your `TelemetryHandler` serializes the envelope
3. Batched export to CloudWatch Logs (flush every 2s or 100 records — whichever comes first)
4. CloudWatch Logs metric filters extract key fields into CloudWatch Metrics

**Lag target:** Under 5 seconds from execution completion to metric appearance in CloudWatch.

---

### Phase 4 — Real-Time Metrics Pipeline

9 metrics aggregated per-node, pushed to CloudWatch every 10 seconds:

| Metric | CloudWatch Namespace | Source |
|---|---|---|
| `active_worker_count` | InfinityNode/Cluster | WorkerPoolSupervisor child count |
| `available_worker_slots` | InfinityNode/Cluster | Registry query |
| `jobs_per_second` | InfinityNode/Throughput | `:telemetry` counter |
| `queue_depth` | InfinityNode/Queue | SQS ApproximateNumberOfMessages |
| `execution_latency_p50` | InfinityNode/Latency | `:telemetry` distribution |
| `execution_latency_p95` | InfinityNode/Latency | `:telemetry` distribution |
| `execution_latency_p99` | InfinityNode/Latency | `:telemetry` distribution |
| `failure_rate` | InfinityNode/Reliability | `:telemetry` counter ratio |
| `dead_letter_count` | InfinityNode/Reliability | DynamoDB scan (5-min poll) |

Technology: `Telemetry.Metrics` + `TelemetryMetricsCloudwatch` — idiomatic Elixir, minimal boilerplate.

---

### Phase 5 — Monitoring Dashboard (Phoenix LiveDashboard)

5 custom pages, all updating in real-time via WebSocket:

| Page | Contents |
|---|---|
| **Cluster Overview** | Active node count, total available slots, jobs/second (rolling 60s) |
| **Queue State** | Live queue depth, dead-letter count, estimated drain time |
| **Latency** | P50/P95/P99 execution latency as rolling 5-minute chart |
| **Job Explorer** | Searchable table of last 100 jobs — state, wall time, node, exit code |
| **Failure Log** | Dead-letter entries with structured failure reasons |

**LiveDashboard must be gated** behind the same `AuthPlug` used on the main API — do not expose internal metrics publicly.

---

### Phase 6 (Stretch) — Event-Driven Trigger System

Webhook endpoint per registered function: `POST /v1/webhooks/:function_id/:token`
- HMAC signature validation against stored token
- Validated payload → job envelope → SQS (identical to normal invocation)
- Returns 202 + `job_id`
- Scheduler is unaware the job came from a webhook — the SQS envelope is identical

---

## 5. Handoff Contracts

### You Deliver To Person 1:
- `infinity-node-artifacts` S3 bucket name/ARN (VM snapshot storage)
- `infinity-node-logs` S3 bucket name (stdout/stderr writes)
- S3 key convention: `logs/{job_id}/stdout` and `logs/{job_id}/stderr`
- IAM task role ARN with S3 write permissions

### You Deliver To Person 2:
- SQS queue URL + DynamoDB table names (shared config / Terraform output)
- Job envelope schema (agreed before code)
- IAM task role ARN with SQS, DynamoDB, and Auto Scaling permissions

### You Need From Person 1:
- `:telemetry` event name and envelope schema
- Confirmation that `execution_wall_ms` and `peak_memory_bytes` are in the telemetry event

### You Need From Person 2:
- Dead-letter table name and SNS topic ARN (for CloudWatch alarm wiring)
- Confirmation of job state fields read by the result retrieval endpoint

---

## 6. Current Codebase Status

The Elixir umbrella project already exists with:
- **Root `mix.exs`** — shared deps: `ex_aws`, `ex_aws_s3`, `ex_aws_sqs`, `hackney`, `jason`, `telemetry`, `telemetry_metrics`
- **`apps/api/`** — skeleton with `Api.Application` only. **No controllers, no router, no plugs.**
- **`apps/scheduler/`** — skeleton with `Scheduler.Application` only. (Person 2's domain.)
- **`apps/worker/`** — exists. (Person 1's domain.)
- **`config/config.exs`** — has worker config and ExAws region. **Missing API config, SQS URLs, DynamoDB table names.**
- **`infra/dynamodb/create-tables.ps1`** — a PowerShell script for DynamoDB table creation exists.

**What's missing (your work):**
- Phoenix framework not yet added as a dependency to `apps/api`
- No controllers, router, endpoint, or plugs
- No Terraform/CDK infrastructure files (only a DynamoDB PS1 script exists)
- No observability modules (telemetry handler, OTel exporter, metrics reporter)
- No LiveDashboard configuration
- No `runtime.exs` for environment-variable-driven config
- No shared job envelope module

---

## 7. Key Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Infrastructure provisioned late → blocks Person 1 and Person 2 | **Critical** | Provision Phase 0 on Day 1. Share Terraform outputs immediately. |
| SQS visibility timeout too short | Jobs re-enqueue while still running (duplicate execution) | Set to `max_job_timeout × 2`. Default 600s. Configurable. |
| CloudWatch API costs spike | Budget overrun under high telemetry volume | Buffered export: batch of 100 *or* 2-second flush. Monitor PutLogEvents call count. |
| Sync invocation blocks request handler | Thread exhaustion under load | Use `Task` with timeout. Fallback to 202 + `job_id` if timeout exceeded. |
| LiveDashboard exposed publicly | Security — internal metrics leak | Gate behind `AuthPlug`. Same static API key as main API. |
| Job envelope schema mismatch | All three engineers write incompatible code | Define and share the schema in Phase 1. Get Person 2's sign-off before writing code. |

---

## 8. Files You Own

```
apps/api/
    lib/
        api/
            controllers/
                function_controller.ex      ← function registration + presigned upload URL
                invocation_controller.ex     ← sync + async invoke
                job_controller.ex            ← result retrieval (GET /v1/jobs/:job_id)
            plugs/
                auth_plug.ex                 ← static API key check (x-api-key header)
                rate_limit_plug.ex           ← per-IP token bucket
            router.ex                        ← route definitions under /v1/
            endpoint.ex                      ← Phoenix endpoint configuration
        observability/
            telemetry_handler.ex             ← attaches :telemetry handlers for execution events
            otel_exporter.ex                 ← OpenTelemetry → CloudWatch Logs (buffered batch export)
            metrics_reporter.ex              ← Telemetry.Metrics → CloudWatch Metrics (10s intervals)

infra/
    main.tf                                  ← Terraform root module (or CDK equivalent)
    variables.tf                             ← Configurable inputs (region, bucket names, etc.)
    outputs.tf                               ← ARNs, URLs, table names — shared with team
    modules/
        s3.tf                                ← Artifacts + logs buckets
        dynamodb.tf                          ← Jobs table + idempotency table
        sqs.tf                               ← Main queue + DLQ
        iam.tf                               ← Task execution role + task role
        ecs.tf                               ← Cluster + task definitions
        cloudwatch.tf                        ← Log groups + alarms
        alb.tf                               ← Application Load Balancer

config/
    runtime.exs                              ← SQS URL, DynamoDB table names, S3 bucket names (env vars)
```

---

## 9. Success Criteria for Person 3

| Criterion | How to Verify |
|---|---|
| All AWS resources provisioned and published | Terraform outputs file exists with all ARNs/URLs. Person 1 and Person 2 confirm they can access resources. |
| API accepts function registration and invocation | `curl` against all 5 endpoints returns correct responses. |
| Sync invocation returns result | POST invoke → blocks → returns result envelope with stdout/stderr S3 URLs. |
| Async invocation returns 202 | POST invoke/async → immediate 202 + job_id. GET /jobs/:id returns TERMINAL state eventually. |
| Telemetry records appear in CloudWatch | Trigger execution → telemetry record visible in CloudWatch Logs within 5 seconds. |
| LiveDashboard shows live metrics | Queue depth, worker count, latency percentiles update in real-time. |
| Rate limiting works | 100+ rapid requests from same IP → 429 responses after token bucket exhaustion. |
| Idempotency works | Duplicate invocation with same idempotency key → 409 with existing job_id. |
| Alarms fire correctly | Manually push to DLQ → alarm triggers within configured evaluation period. |

---

*Person 3 Summary — Infinity Node v1.0*
