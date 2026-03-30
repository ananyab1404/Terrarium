# Person 3 — API, Observability & Infrastructure

### Phoenix API · OpenTelemetry · CloudWatch · AWS Infrastructure · Monitoring Dashboard

---

## Your Role in the System

You own **everything the developer touches** and **everything the operator watches**. That means two distinct surfaces:

1. **The inward-facing surface** — AWS infrastructure provisioning (SQS, DynamoDB, S3, ECS, IAM), the Phoenix HTTP API that developers submit functions through, and the job envelope contract that feeds Person 2's scheduler.

2. **The outward-facing surface** — the observability pipeline (telemetry envelopes, OpenTelemetry exporter, CloudWatch), the real-time metrics aggregation, and the monitoring dashboard that shows live cluster state.

You also own the **integration seam** between all three engineers. The infrastructure you provision is what Person 1 and Person 2 build on top of. The schemas you define are what everyone writes to. Get those right and the team moves fast. Get them wrong and everyone's blocked.

---

## Your Part of the Architecture

```
Developer HTTP Client
    │
    ▼
AWS Application Load Balancer
    │
    ▼
[Phoenix API — apps/api]
    ├── POST /v1/functions           ← function registration
    ├── POST /v1/functions/:id/upload-url  ← presigned S3 URL
    ├── POST /v1/functions/:id/invoke      ← sync invocation
    ├── POST /v1/functions/:id/invoke/async ← async invocation
    └── GET  /v1/jobs/:job_id        ← result retrieval

    │  writes job envelope to SQS
    ▼
[SQS Queue]  ←── Person 2 consumes this

[S3]
    ├── function artifacts (uploaded by developer via presigned URL)
    └── execution logs (stdout/stderr — written by Person 1)

[DynamoDB]  ←── Person 2 owns the state machine writes
    └── Person 3 reads job state for result retrieval endpoint

[Observability Pipeline]
    ├── Execution telemetry envelopes  ←── emitted by Person 1's WorkerProcess
    ├── OpenTelemetry collector → CloudWatch Logs
    ├── :telemetry metrics → CloudWatch Metrics
    └── Monitoring dashboard (live: worker count, queue depth, P99 latency)

[AWS Infrastructure — Terraform / CDK]
    ├── ECS cluster + task definitions
    ├── SQS queue + dead-letter queue
    ├── DynamoDB tables (jobs + idempotency)
    ├── S3 buckets (artifacts + logs)
    ├── IAM roles and policies
    ├── Application Load Balancer
    └── CloudWatch log groups + metric alarms
```

---

## Stack You're Working In

- **Elixir / Phoenix** — HTTP API, controllers, plugs, JSON serialization
- **AWS CDK or Terraform** — infrastructure as code (pick one and own it)
- **OpenTelemetry (Elixir SDK)** — telemetry envelope export to CloudWatch
- **Elixir `:telemetry`** — real-time metrics pipeline
- **CloudWatch** — log aggregation, metrics, alarms
- **Grafana or LiveDashboard** — monitoring dashboard (Phoenix LiveDashboard is the fast path)

---

## Phase-by-Phase Breakdown

### Phase 0 — Infrastructure First (Do This Before Anyone Writes Code)

**This is the most important thing you do in the first day.** Person 1 needs an S3 bucket and a metal EC2 instance. Person 2 needs SQS queues and DynamoDB tables. Neither can make real progress until you provision these.

**Provision in this order:**

1. **S3 buckets** (two):
   - `infinity-node-artifacts` — function tarballs, VM snapshots
   - `infinity-node-logs` — execution stdout/stderr objects
   - Enable versioning on artifacts bucket. Set lifecycle rule on logs bucket: expire objects after 30 days.

2. **DynamoDB tables** (two, as designed by Person 2):
   - `infinity-node-jobs` — job state machine table
   - `infinity-node-idempotency` — idempotency key deduplication
   - Enable TTL on idempotency table (`ttl` attribute)
   - Create GSI on jobs table: `(state, lease_expires_at)` — Person 2 needs this for lease reaper queries
   - **Point-in-time recovery: ON.** This is a production data store.

3. **SQS queues** (two):
   - `infinity-node-jobs` — main job queue (Standard, not FIFO)
   - `infinity-node-jobs-dlq` — dead-letter queue (receives jobs after max retries)
   - Set `MaxReceiveCount: 3` on the main queue's redrive policy
   - Set `VisibilityTimeout` on the main queue to match the maximum job wall-clock timeout × 2 (default: 600 seconds)

4. **IAM roles**:
   - ECS task execution role: ECR pull, CloudWatch log write
   - ECS task role (application role): SQS read/delete, DynamoDB read/write, S3 read/write, Auto Scaling set desired capacity, SNS publish
   - Keep these two roles separate. The task execution role is AWS-managed plumbing. The task role is your application's permissions.

5. **ECS cluster skeleton**:
   - Create the ECS cluster
   - Define two task definitions: one for the API service, one for the worker nodes
   - The worker task definition needs to specify the `i3.metal` instance type via a capacity provider
   - Do NOT launch tasks yet — just define them

6. **CloudWatch log groups**:
   - `/infinity-node/api`
   - `/infinity-node/worker`
   - `/infinity-node/scheduler`
   - Set retention to 14 days

**Deliverable:** A Terraform/CDK outputs file or a shared config document with all ARNs, URLs, and table names. Person 1 and Person 2 need these to configure their apps. Publish this before they start Phase 1.

---

### Phase 1 — Job Envelope Schema

**Own this schema.** It is the contract between your API, Person 2's scheduler, and Person 1's execution engine. Define it in a shared Elixir module that all three apps import.

```elixir
defmodule InfinityNode.JobEnvelope do
  @type t :: %{
    job_id: String.t(),             # UUID
    idempotency_key: String.t(),    # client-provided
    function_id: String.t(),        # registered function identifier
    artifact_s3_key: String.t(),    # s3://infinity-node-artifacts/<hash>
    input_payload: map(),           # arbitrary JSON
    resource_limits: %{
      cpu_shares: pos_integer(),    # default: 1024
      memory_mb: pos_integer(),     # default: 256
      timeout_ms: pos_integer()     # default: 30_000, max: 300_000
    },
    retry_count: non_neg_integer(), # starts at 0
    enqueued_at: DateTime.t()
  }
end
```

Share this with Person 2 before either of you writes any code that touches SQS or DynamoDB.

---

### Phase 2 — Phoenix API

**Goal:** A developer-facing HTTP API that is stateless, horizontally scalable, and sits behind the ALB.

The API layer does not contain business logic. It validates input, writes to S3 and SQS, and reads from DynamoDB. No scheduler logic lives here.

**Endpoints:**

`POST /v1/functions`

- Body: `{name, runtime, description}`
- Registers a function record in DynamoDB
- Returns: `{function_id}`

`POST /v1/functions/:function_id/upload-url`

- Generates a presigned S3 PUT URL for artifact upload
- Returns: `{upload_url, artifact_s3_key, expires_in_seconds}`
- The developer uploads the tarball directly to S3 — the API server never handles the binary

`POST /v1/functions/:function_id/invoke`

- Body: `{input_payload, resource_limits?, idempotency_key?}`
- Validates input, writes job to DynamoDB (state: PENDING), enqueues to SQS
- **Synchronous path:** blocks polling DynamoDB every 500ms until state is TERMINAL or timeout
- Returns: `{job_id, exit_code, stdout_url, stderr_url, wall_time_ms, cost_receipt?}`

`POST /v1/functions/:function_id/invoke/async`

- Same as above but returns immediately with `{job_id}` (202 Accepted)

`GET /v1/jobs/:job_id`

- Reads job record from DynamoDB (consistent read)
- If TERMINAL: returns full result envelope
- If not TERMINAL: returns current state + estimated wait time
- If dead-lettered: returns structured failure reason

**Error handling conventions:**

- 400: validation failure (malformed input, unknown function ID)
- 409: idempotency key conflict (return existing job ID)
- 429: rate limit (implement a simple per-IP token bucket via a Plug)
- 503: scheduler unavailable (SQS enqueue failure — surface explicitly, do not silently drop)

**Do not implement authentication in MVP.** Use a single static API key via a Plug header check. Mark it as a TODO for production.

---

### Phase 3 — Telemetry Envelope + OpenTelemetry Export

**Goal:** Every execution produces a structured telemetry record. Every record reaches CloudWatch with under 5-second lag.

**Telemetry envelope schema** (emitted by Person 1's `WorkerProcess` at execution completion):

```elixir
%{
  job_id: String.t(),
  function_id: String.t(),
  function_version: String.t(),
  node_id: String.t(),
  vm_slot_index: non_neg_integer(),
  queue_wait_ms: non_neg_integer(),    # time from enqueue to dispatch
  execution_wall_ms: non_neg_integer(), # time from dispatch to exit
  peak_memory_bytes: non_neg_integer(),
  exit_code: integer(),
  failure_reason: String.t() | nil,
  stdout_s3_key: String.t(),
  stderr_s3_key: String.t(),
  cost_receipt: map() | nil           # stretch goal 6.1
}
```

**How it flows:**

1. Person 1's `WorkerProcess` emits a `:telemetry.execute/3` event with this envelope
2. You attach a handler that serializes the envelope and sends it to the OpenTelemetry collector
3. The collector batches and ships to CloudWatch Logs
4. CloudWatch Logs → metric filters → CloudWatch Metrics

**OpenTelemetry setup:**

```elixir
# In your application supervisor
OpentelemetryExporter.setup()

# CloudWatch exporter config
config :opentelemetry_exporter,
  otlp_endpoint: "https://logs.us-east-1.amazonaws.com",
  otlp_headers: [{"x-amz-log-group", "/infinity-node/worker"}]
```

Use buffered export — batch telemetry records and flush every 2 seconds or when the batch reaches 100 records. This keeps CloudWatch API costs manageable under load.

---

### Phase 4 — Real-Time Metrics Pipeline

**Goal:** Cluster-wide aggregates visible in near-real-time.

Use Elixir's `:telemetry` library to define a metrics pipeline on each node. Metrics are aggregated per-node and reported to CloudWatch every 10 seconds.

**Metrics to expose:**

| Metric                   | Source                           | CloudWatch Namespace       |
| ------------------------ | -------------------------------- | -------------------------- |
| `active_worker_count`    | WorkerPoolSupervisor child count | `InfinityNode/Cluster`     |
| `available_worker_slots` | Registry query                   | `InfinityNode/Cluster`     |
| `jobs_per_second`        | :telemetry counter               | `InfinityNode/Throughput`  |
| `queue_depth`            | SQS ApproximateNumberOfMessages  | `InfinityNode/Queue`       |
| `execution_latency_p50`  | :telemetry distribution          | `InfinityNode/Latency`     |
| `execution_latency_p95`  | :telemetry distribution          | `InfinityNode/Latency`     |
| `execution_latency_p99`  | :telemetry distribution          | `InfinityNode/Latency`     |
| `failure_rate`           | :telemetry counter ratio         | `InfinityNode/Reliability` |
| `dead_letter_count`      | DynamoDB scan (5-min poll)       | `InfinityNode/Reliability` |

**Use `Telemetry.Metrics` and `TelemetryMetricsCloudwatch`** — this is the idiomatic Elixir path and requires minimal boilerplate.

---

### Phase 5 — Monitoring Dashboard

**Goal:** A live operational view showing cluster state. Lag under 5 seconds.

**Fast path: Phoenix LiveDashboard** with custom pages. This is already a dependency in Phoenix and requires no extra infrastructure.

Add these custom pages:

1. **Cluster Overview** — active node count, total available slots, jobs/second (last 60s)
2. **Queue State** — queue depth (live), dead-letter count, estimated drain time at current throughput
3. **Latency** — P50/P95/P99 execution latency as a rolling 5-minute chart
4. **Job Explorer** — searchable table of recent jobs (last 100), showing state, wall time, node, exit code
5. **Failure Log** — dead-letter entries with structured failure reasons

If the team wants something more production-grade, set up a Grafana instance pointed at CloudWatch as the data source. But LiveDashboard is the right call for the MVP — it's already in the app, requires no extra ops, and updates in real time via WebSocket.

**CloudWatch Alarms (set these up during Phase 0, not at the end):**

- Dead-letter queue depth > 0 → SNS → alert
- P99 latency > 500ms for 5 consecutive minutes → alert
- Active worker count drops to 0 → alert (cluster down)
- SQS queue depth > 1000 for 10 minutes → alert (autoscaler not responding)

---

### Phase 6 — Stretch Goal: Event-Driven Trigger System (6.2)

Once the core is solid, wire up webhook triggers:

1. Each registered function gets a unique endpoint: `POST /v1/webhooks/:function_id/:token`
2. The Phoenix API (or a Lambda, as per the PRD) validates the HMAC signature against the stored token
3. The validated payload is extracted and written as a job envelope to SQS — identical to a normal invocation
4. Returns 202 with a `job_id`

The scheduler never needs to know a job came from a webhook. The SQS envelope is identical. This is why the clean job envelope schema matters — it makes this extension trivial.

---

## Handoff Contracts

### What you deliver to Person 1 (Execution Engine):

- `infinity-node-artifacts` S3 bucket name and ARN — for VM snapshot storage
- `infinity-node-logs` S3 bucket name — for stdout/stderr object writes
- The S3 key convention for logs: `logs/{job_id}/stdout` and `logs/{job_id}/stderr`
- IAM task role ARN with S3 write permissions

### What you deliver to Person 2 (Scheduler):

- SQS queue URL and DynamoDB table names — as a shared config file or Terraform output
- The job envelope schema (Phase 1 above) — agree on this together before they write code
- IAM task role ARN with SQS, DynamoDB, and Auto Scaling permissions

### What you need from Person 1 (Execution Engine):

- The `:telemetry` event name and envelope schema they'll emit — you attach the handler
- Confirmation that `WorkerProcess` emits `execution_wall_ms` and `peak_memory_bytes` in the telemetry event

### What you need from Person 2 (Scheduler):

- The dead-letter table name and SNS topic ARN — to wire up the CloudWatch alarm
- Confirmation of the job state fields your result retrieval endpoint reads

---

## Risk Register

| Risk                                                                           | What to do                                                                                                                             |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Infrastructure provisioned incorrectly blocks both other engineers             | Provision Phase 0 on day one. Share outputs immediately. Don't wait until your code is ready.                                          |
| SQS message visibility timeout too short — jobs re-enqueue while still running | Set visibility timeout to max job timeout × 2. Default to 600s. Configurable.                                                          |
| CloudWatch API costs spike under high telemetry volume                         | Use buffered export (batch of 100 or 2-second flush). Monitor CloudWatch PutLogEvents API call count.                                  |
| Phoenix sync invocation blocks a request handler while polling                 | Use a Task with a timeout. If the job doesn't complete within the request timeout, return 202 with the job ID and let the client poll. |
| LiveDashboard exposes internal metrics publicly                                | Gate it behind the same static API key Plug used on the main API.                                                                      |

---

## Key Files You'll Own

```
apps/api/
    lib/
        controllers/
            function_controller.ex   ← function registration + upload URL
            invocation_controller.ex ← sync + async invoke
            job_controller.ex        ← result retrieval
        plugs/
            auth_plug.ex             ← static API key check
            rate_limit_plug.ex       ← per-IP token bucket
        router.ex
        endpoint.ex

    lib/observability/
        telemetry_handler.ex         ← attaches :telemetry handlers
        otel_exporter.ex             ← OpenTelemetry → CloudWatch
        metrics_reporter.ex          ← :telemetry → CloudWatch Metrics

infra/
    main.tf (or lib/infra_stack.ex)  ← Terraform or CDK
    outputs.tf                       ← ARNs, URLs, table names shared with team

config/
    runtime.exs                      ← SQS URL, DynamoDB table names, S3 bucket names
```

---

_Person 3 doc — Infinity Node v1.0_
