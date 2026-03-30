# Person 3 — Complete Task Checklist
### Infinity Node — API, Observability & Infrastructure

---

## Phase 0 — Infrastructure Provisioning (Day 1 — BLOCKING)

> **Priority: CRITICAL.** Person 1 and Person 2 cannot start real work until these are done.

### 0.1 — Terraform/CDK Project Setup
- [ ] Choose IaC tool: Terraform or AWS CDK (Terraform recommended for this project)
- [ ] Create `infra/` directory structure with `main.tf`, `variables.tf`, `outputs.tf`
- [ ] Define Terraform provider block (AWS, region from variable)
- [ ] Define shared variables: `aws_region`, `project_name` (default: `infinity-node`), `environment`
- [ ] Create `.env.example` at project root with all required environment variables

### 0.2 — S3 Buckets
- [ ] Create `infinity-node-artifacts` S3 bucket
  - [ ] Enable versioning
  - [ ] Set bucket policy: private, no public access
  - [ ] Add server-side encryption (AES-256 or KMS)
- [ ] Create `infinity-node-logs` S3 bucket
  - [ ] Add lifecycle rule: expire objects after 30 days
  - [ ] Set bucket policy: private, no public access
  - [ ] Add server-side encryption (AES-256 or KMS)
- [ ] Export both bucket names and ARNs in `outputs.tf`

### 0.3 — DynamoDB Tables
- [ ] Create `infinity-node-jobs` table
  - [ ] Partition key: `job_id` (String)
  - [ ] Create GSI: partition key `state` (String), sort key `lease_expires_at` (Number)
  - [ ] Enable Point-in-Time Recovery (PITR)
  - [ ] Set billing mode: PAY_PER_REQUEST (on-demand) for dev; consider provisioned for prod
- [ ] Create `infinity-node-idempotency` table
  - [ ] Partition key: `idempotency_key` (String)
  - [ ] Enable TTL on `ttl` attribute
- [ ] Export both table names and ARNs in `outputs.tf`

### 0.4 — SQS Queues
- [ ] Create `infinity-node-jobs-dlq` dead-letter queue (must exist before main queue)
- [ ] Create `infinity-node-jobs` main queue
  - [ ] Type: Standard (NOT FIFO)
  - [ ] VisibilityTimeout: 600 seconds
  - [ ] MessageRetentionPeriod: 345600 (4 days)
  - [ ] ReceiveMessageWaitTimeSeconds: 20 (long polling)
  - [ ] Configure redrive policy: `maxReceiveCount: 3` pointing to DLQ
- [ ] Export both queue URLs and ARNs in `outputs.tf`

### 0.5 — IAM Roles
- [ ] Create ECS Task Execution Role
  - [ ] Attach `AmazonECSTaskExecutionRolePolicy` managed policy
  - [ ] Add CloudWatch Logs `CreateLogStream` and `PutLogEvents` permissions
- [ ] Create ECS Task Role (Application)
  - [ ] SQS permissions: `ReceiveMessage`, `DeleteMessage`, `SendMessage`, `GetQueueAttributes` on job queue and DLQ
  - [ ] DynamoDB permissions: `GetItem`, `PutItem`, `UpdateItem`, `DeleteItem`, `Query`, `Scan` on both tables and their GSIs
  - [ ] S3 permissions: `GetObject`, `PutObject`, `ListBucket` on both buckets
  - [ ] Auto Scaling: `SetDesiredCapacity`, `DescribeAutoScalingGroups`
  - [ ] SNS: `Publish` on alert topic
- [ ] Export both role ARNs in `outputs.tf`

### 0.6 — SNS Topic for Alerts
- [ ] Create `infinity-node-alerts` SNS topic
- [ ] Create email subscription (configurable via variable)
- [ ] Export topic ARN in `outputs.tf`

### 0.7 — ECS Cluster Skeleton
- [ ] Create ECS cluster `infinity-node`
- [ ] Define API task definition (Fargate launch type)
  - [ ] Container definition with placeholder image
  - [ ] Log configuration → CloudWatch `/infinity-node/api` log group
  - [ ] Assign task execution role and task role
- [ ] Define Worker task definition (EC2 launch type)
  - [ ] Container definition with placeholder image
  - [ ] Log configuration → CloudWatch `/infinity-node/worker` log group
  - [ ] Assign task execution role and task role
  - [ ] Require `i3.metal` instance type via capacity provider strategy
- [ ] **Do NOT launch tasks yet** — just define them
- [ ] Export cluster ARN and task definition ARNs in `outputs.tf`

### 0.8 — Application Load Balancer
- [ ] Create ALB in public subnets
- [ ] Create target group for API service (port 4000, health check on `/health`)
- [ ] Create HTTP listener (port 80 → target group)
- [ ] Create HTTPS listener if certificate is available (port 443)
- [ ] Export ALB DNS name and target group ARN in `outputs.tf`

### 0.9 — CloudWatch Log Groups
- [ ] Create `/infinity-node/api` log group (retention: 14 days)
- [ ] Create `/infinity-node/worker` log group (retention: 14 days)
- [ ] Create `/infinity-node/scheduler` log group (retention: 14 days)

### 0.10 — CloudWatch Alarms
- [ ] Alarm: DLQ `ApproximateNumberOfMessagesVisible > 0` → SNS alert
- [ ] Alarm: P99 execution latency > 500ms for 5 consecutive minutes → SNS alert
- [ ] Alarm: Active worker count drops to 0 → SNS alert (cluster down)
- [ ] Alarm: Main queue `ApproximateNumberOfMessagesVisible > 1000` for 10 minutes → SNS alert

### 0.11 — Publish Infrastructure Outputs
- [ ] Run `terraform apply` (or `cdk deploy`) to provision all resources
- [ ] Generate outputs document with all ARNs, URLs, table names
- [ ] Share outputs with Person 1 and Person 2
- [ ] Verify Person 1 can access S3 buckets
- [ ] Verify Person 2 can access SQS queues and DynamoDB tables

---

## Phase 1 — Job Envelope Schema

### 1.1 — Create Shared Schema Module
- [ ] Create shared module location (e.g., `apps/api/lib/infinity_node/job_envelope.ex` or a shared app)
- [ ] Define `InfinityNode.JobEnvelope` module with `@type t`
- [ ] Define `InfinityNode.ResultEnvelope` module with `@type t`
- [ ] Define `InfinityNode.TelemetryEnvelope` module with `@type t`
- [ ] Add validation functions: `validate_job_envelope/1` (checks required fields, validates types)
- [ ] Add builder function: `new_job_envelope/1` (generates UUID, sets defaults for resource_limits, sets enqueued_at)
- [ ] Add JSON serialization/deserialization functions for SQS transport
- [ ] Define resource_limits defaults: `cpu_shares: 1024`, `memory_mb: 256`, `timeout_ms: 30_000`
- [ ] Define resource_limits max values: `timeout_ms: 300_000`

### 1.2 — Share and Agree on Schema
- [ ] Share module with Person 2 for review — agree on all fields before writing consumer code
- [ ] Confirm with Person 1 that result envelope and telemetry envelope match their WorkerProcess output
- [ ] Document the finalized schema in a shared location accessible to all team members

---

## Phase 2 — Phoenix API

### 2.1 — Phoenix Setup
- [ ] Add Phoenix dependencies to `apps/api/mix.exs`:
  - `phoenix` (~> 1.7)
  - `phoenix_live_dashboard`
  - `plug_cowboy`
  - `jason`
  - `ex_aws_dynamo`
  - `ex_aws_s3`
  - `ex_aws_sqs`
- [ ] Add shared umbrella deps if not already in root `mix.exs`: `ex_aws_dynamo`
- [ ] Run `mix deps.get` from umbrella root
- [ ] Create `Api.Endpoint` module (`apps/api/lib/api/endpoint.ex`)
  - [ ] Configure JSON parser (Jason)
  - [ ] Configure Plug.Logger
  - [ ] Mount LiveDashboard (gated)
  - [ ] Configure port from env var (default 4000)
- [ ] Create `Api.Router` module (`apps/api/lib/api/router.ex`)
  - [ ] Define `/v1` pipeline with JSON content-type
  - [ ] Add AuthPlug to pipeline
  - [ ] Add RateLimitPlug to pipeline
  - [ ] Define all route paths (Phase 2 endpoints below)
  - [ ] Add `/health` GET endpoint (returns 200 OK, used by ALB health check)
- [ ] Update `Api.Application` to start Endpoint in supervision tree
- [ ] Verify Phoenix boots: `mix phx.server` from umbrella root

### 2.2 — Auth Plug
- [ ] Create `Api.Plugs.AuthPlug` (`apps/api/lib/api/plugs/auth_plug.ex`)
- [ ] Read expected API key from config/env var (`INFINITY_NODE_API_KEY`)
- [ ] Check `x-api-key` request header against expected key
- [ ] Return 401 Unauthorized with JSON error body if mismatch
- [ ] Skip auth for `/health` endpoint
- [ ] Add TODO comment: "Replace with proper authentication for production"

### 2.3 — Rate Limit Plug
- [ ] Create `Api.Plugs.RateLimitPlug` (`apps/api/lib/api/plugs/rate_limit_plug.ex`)
- [ ] Implement per-IP token bucket using ETS table
  - [ ] Configure max tokens (default: 100)
  - [ ] Configure refill rate (default: 10 tokens/second)
- [ ] Extract client IP from `conn.remote_ip` (handle `X-Forwarded-For` behind ALB)
- [ ] Return 429 Too Many Requests with JSON error body + `Retry-After` header
- [ ] Add ETS table creation to `Api.Application` startup

### 2.4 — Function Controller
- [ ] Create `Api.Controllers.FunctionController` (`apps/api/lib/api/controllers/function_controller.ex`)
- [ ] **POST /v1/functions** — Register a function
  - [ ] Validate body: `name` (required string), `runtime` (required string), `description` (optional string)
  - [ ] Generate `function_id` (UUID v4)
  - [ ] Write function record to DynamoDB (new table or use jobs table with type prefix — decide)
  - [ ] Return `201 Created` with `{function_id}`
  - [ ] Return `400` on validation failure
- [ ] **POST /v1/functions/:function_id/upload-url** — Get presigned S3 URL
  - [ ] Verify function_id exists in DynamoDB
  - [ ] Generate presigned S3 PUT URL for `infinity-node-artifacts` bucket
  - [ ] S3 key format: `functions/{function_id}/{sha256_hash}` or `functions/{function_id}/{timestamp}`
  - [ ] Set URL expiry: 3600 seconds (1 hour)
  - [ ] Return `200 OK` with `{upload_url, artifact_s3_key, expires_in_seconds}`
  - [ ] Return `400` if function_id not found

### 2.5 — Invocation Controller
- [ ] Create `Api.Controllers.InvocationController` (`apps/api/lib/api/controllers/invocation_controller.ex`)
- [ ] **POST /v1/functions/:function_id/invoke** — Synchronous invocation
  - [ ] Validate body: `input_payload` (required map), `resource_limits` (optional map), `idempotency_key` (optional string)
  - [ ] Verify function_id exists, verify artifact has been uploaded
  - [ ] Check idempotency: query `infinity-node-idempotency` table
    - [ ] If key exists → return `409 Conflict` with existing `job_id`
    - [ ] If key doesn't exist → proceed
  - [ ] Generate `job_id` (UUID v4)
  - [ ] Build job envelope using `InfinityNode.JobEnvelope.new_job_envelope/1`
  - [ ] Write job to DynamoDB `infinity-node-jobs` table (state: `PENDING`)
  - [ ] Write idempotency record to `infinity-node-idempotency` table (with 24h TTL)
  - [ ] Enqueue serialized job envelope to SQS `infinity-node-jobs` queue
    - [ ] On SQS failure → return `503 Service Unavailable` (do NOT silently drop)
  - [ ] **Poll DynamoDB every 500ms** for job state change
    - [ ] Use `Task.async` with timeout (default: 30s, configurable)
    - [ ] If state reaches `TERMINAL` → return full result envelope (200 OK)
    - [ ] If timeout → return `202 Accepted` with `{job_id, status: "processing"}`
  - [ ] Handle dead-lettered jobs: return `200` with failure reason
- [ ] **POST /v1/functions/:function_id/invoke/async** — Async invocation
  - [ ] Same validation and enqueue logic as sync
  - [ ] Return `202 Accepted` + `{job_id}` immediately (no polling)

### 2.6 — Job Controller
- [ ] Create `Api.Controllers.JobController` (`apps/api/lib/api/controllers/job_controller.ex`)
- [ ] **GET /v1/jobs/:job_id** — Result retrieval
  - [ ] Read job from DynamoDB with `ConsistentRead: true`
  - [ ] If job not found → return `404 Not Found`
  - [ ] If state == `TERMINAL` and no failure_reason → return full result envelope:
    - `{job_id, state, exit_code, stdout_url, stderr_url, wall_time_ms, peak_memory_bytes}`
    - Generate presigned GET URLs for stdout/stderr S3 objects
  - [ ] If state == `TERMINAL` and failure_reason set → return failure envelope:
    - `{job_id, state: "FAILED", failure_reason}`
  - [ ] If state is intermediate → return progress envelope:
    - `{job_id, state, created_at, estimated_wait_ms?}`

### 2.7 — Error Handling & JSON Response Helpers
- [ ] Create `Api.ErrorView` or `Api.FallbackController` for consistent JSON error responses
- [ ] Create helper module for standard response shapes:
  - `success(conn, status, data)`
  - `error(conn, status, message, details \\ nil)`
- [ ] Add global error handler (Plug.ErrorHandler or Phoenix FallbackController)
  - [ ] 500 errors → structured JSON response + log error details

### 2.8 — Health Check Endpoint
- [ ] Add `GET /health` route (excluded from auth)
- [ ] Return `200 OK` with `{status: "ok", version: "0.1.0"}`
- [ ] Optionally check DynamoDB and SQS connectivity for deep health check

---

## Phase 3 — Telemetry Pipeline + OpenTelemetry Export

### 3.1 — Add Telemetry Dependencies
- [ ] Add to `apps/api/mix.exs` or root `mix.exs`:
  - `opentelemetry` (~> 1.3)
  - `opentelemetry_api` (~> 1.2)
  - `opentelemetry_exporter` (~> 1.6)
  - `ex_aws_cloudwatch_logs` (or custom CloudWatch log writer)
- [ ] Run `mix deps.get`

### 3.2 — Telemetry Handler
- [ ] Create `Api.Observability.TelemetryHandler` (`apps/api/lib/observability/telemetry_handler.ex`)
- [ ] Attach handler to event: `[:infinity_node, :execution, :complete]`
- [ ] On event:
  - [ ] Extract telemetry envelope from event metadata
  - [ ] Validate envelope has required fields
  - [ ] Serialize envelope to JSON
  - [ ] Send to buffer (see 3.3)
- [ ] Attach handler on application startup (in `Api.Application.start/2`)
- [ ] Handle handler crash gracefully — log error, do not crash the application

### 3.3 — Buffered Exporter (CloudWatch Logs)
- [ ] Create `Api.Observability.OtelExporter` (`apps/api/lib/observability/otel_exporter.ex`)
- [ ] Implement as GenServer with internal buffer (list of serialized records)
- [ ] **Flush conditions** (whichever comes first):
  - [ ] Buffer reaches 100 records → flush
  - [ ] 2-second timer fires → flush
- [ ] Flush implementation:
  - [ ] Batch records into CloudWatch PutLogEvents API call
  - [ ] Target log group: `/infinity-node/worker`
  - [ ] Include sequence token management for CloudWatch log streams
  - [ ] On API failure → log error, retain records for retry (max 3 retries, then drop with warning)
- [ ] Add GenServer to `Api.Application` supervision tree
- [ ] Implement `handle_cast({:record, envelope})` for receiving records from TelemetryHandler
- [ ] Implement `handle_info(:flush, state)` for timer-based flush

### 3.4 — OpenTelemetry Configuration
- [ ] Configure OpenTelemetry in `config/runtime.exs`:
  - [ ] Set OTLP endpoint (CloudWatch or OTel collector URL)
  - [ ] Set export interval
  - [ ] Set resource attributes (service.name, service.version)
- [ ] Initialize OpenTelemetry in `Api.Application.start/2`

---

## Phase 4 — Real-Time Metrics Pipeline

### 4.1 — Metrics Reporter
- [ ] Create `Api.Observability.MetricsReporter` (`apps/api/lib/observability/metrics_reporter.ex`)
- [ ] Implement as GenServer that runs on a 10-second timer
- [ ] Define metrics list using `Telemetry.Metrics`:
  - [ ] `Telemetry.Metrics.last_value("infinity_node.cluster.active_workers")`
  - [ ] `Telemetry.Metrics.last_value("infinity_node.cluster.available_slots")`
  - [ ] `Telemetry.Metrics.counter("infinity_node.throughput.jobs_total")`
  - [ ] `Telemetry.Metrics.last_value("infinity_node.queue.depth")`
  - [ ] `Telemetry.Metrics.distribution("infinity_node.latency.execution_ms")` (for p50/p95/p99)
  - [ ] `Telemetry.Metrics.counter("infinity_node.reliability.failures_total")`
  - [ ] `Telemetry.Metrics.last_value("infinity_node.reliability.dead_letter_count")`

### 4.2 — CloudWatch Metrics Push
- [ ] On each 10-second tick:
  - [ ] Query WorkerPoolSupervisor for child count → `active_worker_count`
  - [ ] Query Registry for available slots → `available_worker_slots`
  - [ ] Read accumulated `:telemetry` counters → `jobs_per_second`
  - [ ] Query SQS `GetQueueAttributes` for `ApproximateNumberOfMessages` → `queue_depth`
  - [ ] Compute percentiles from `:telemetry` distribution → `p50`, `p95`, `p99`
  - [ ] Compute failure rate from success/failure counters → `failure_rate`
- [ ] Every 5 minutes (separate timer):
  - [ ] Scan DynamoDB for dead-letter state count → `dead_letter_count`
- [ ] Push all metrics to CloudWatch using `PutMetricData` API
  - [ ] Namespace: `InfinityNode/Cluster`, `InfinityNode/Throughput`, `InfinityNode/Queue`, `InfinityNode/Latency`, `InfinityNode/Reliability`
  - [ ] Include `node_id` as dimension for per-node breakdown
- [ ] Add GenServer to `Api.Application` supervision tree

### 4.3 — Telemetry Event Definitions
- [ ] Define all `:telemetry` events the API app emits:
  - [ ] `[:api, :request, :start]` — HTTP request received
  - [ ] `[:api, :request, :stop]` — HTTP request completed (with duration)
  - [ ] `[:api, :request, :error]` — HTTP request failed
  - [ ] `[:api, :sqs, :enqueue]` — job enqueued to SQS
  - [ ] `[:api, :dynamo, :write]` — DynamoDB write operation
  - [ ] `[:api, :dynamo, :read]` — DynamoDB read operation
- [ ] Instrument all controllers with telemetry events

---

## Phase 5 — Monitoring Dashboard

### 5.1 — LiveDashboard Setup
- [ ] Add `phoenix_live_dashboard` to `apps/api/mix.exs` deps (if not already)
- [ ] Add `phoenix_live_view` dependency (required by LiveDashboard)
- [ ] Configure LiveDashboard route in `Api.Router`:
  ```elixir
  live_dashboard "/dashboard",
    metrics: Api.Telemetry,
    additional_pages: [...]
  ```
- [ ] Gate LiveDashboard behind `AuthPlug` (same API key as main API)
- [ ] Verify LiveDashboard loads at `http://localhost:4000/dashboard`

### 5.2 — Custom Page: Cluster Overview
- [ ] Create `Api.LiveDashboard.ClusterOverviewPage`
- [ ] Display: active node count (from `:pg` or libcluster)
- [ ] Display: total available worker slots
- [ ] Display: jobs/second (rolling 60-second average)
- [ ] Auto-refresh via LiveDashboard periodic callback

### 5.3 — Custom Page: Queue State
- [ ] Create `Api.LiveDashboard.QueueStatePage`
- [ ] Display: SQS queue depth (live, polled every 5s)
- [ ] Display: dead-letter queue depth
- [ ] Display: estimated drain time = `queue_depth / jobs_per_second`
- [ ] Auto-refresh

### 5.4 — Custom Page: Latency
- [ ] Create `Api.LiveDashboard.LatencyPage`
- [ ] Display: P50, P95, P99 execution latency
- [ ] Rolling 5-minute window
- [ ] Chart rendering (use LiveDashboard built-in chart support or custom LiveView component)
- [ ] Auto-refresh

### 5.5 — Custom Page: Job Explorer
- [ ] Create `Api.LiveDashboard.JobExplorerPage`
- [ ] Display: searchable table of last 100 jobs from DynamoDB
- [ ] Columns: `job_id`, `function_id`, `state`, `wall_time_ms`, `assigned_node`, `exit_code`, `created_at`
- [ ] Filter by state (dropdown): ALL, PENDING, SCHEDULED, DISPATCHED, RUNNING, TERMINAL
- [ ] Search by `job_id` (text input)
- [ ] Clickable row → shows job detail (modal or inline expansion)

### 5.6 — Custom Page: Failure Log
- [ ] Create `Api.LiveDashboard.FailureLogPage`
- [ ] Query DynamoDB for jobs where `state == TERMINAL` AND `failure_reason IS NOT NULL`
- [ ] Display: table with `job_id`, `function_id`, `failure_reason`, `retry_count`, `updated_at`
- [ ] Also show dead-letter queue entries
- [ ] Sort by `updated_at` descending (most recent first)

---

## Phase 6 (Stretch) — Event-Driven Trigger System

### 6.1 — Webhook Token Management
- [ ] Add `webhook_token` field to function records in DynamoDB
- [ ] Generate cryptographically secure token on function registration (`:crypto.strong_rand_bytes/1`)
- [ ] Store token hash (not plaintext) in DynamoDB
- [ ] Return token to developer on registration (show once, cannot be retrieved again)
- [ ] Add endpoint to rotate token: `POST /v1/functions/:id/rotate-webhook-token`

### 6.2 — Webhook Endpoint
- [ ] Add route: `POST /v1/webhooks/:function_id/:token`
- [ ] Create `Api.Controllers.WebhookController`
- [ ] Validate HMAC signature:
  - [ ] Compute `HMAC-SHA256(stored_token, request_body)`
  - [ ] Compare against `X-Webhook-Signature` header
  - [ ] Return `401 Unauthorized` on mismatch
- [ ] Extract payload from body
- [ ] Build job envelope (identical to normal invocation)
- [ ] Enqueue to SQS
- [ ] Return `202 Accepted` + `{job_id}`
- [ ] Webhook endpoint should bypass `AuthPlug` (uses token-based auth instead)

---

## Configuration & Wiring

### Config Files
- [ ] Create `config/runtime.exs` with environment variable reads:
  - [ ] `SQS_QUEUE_URL` → SQS main queue URL
  - [ ] `SQS_DLQ_URL` → SQS dead-letter queue URL
  - [ ] `DYNAMODB_JOBS_TABLE` → DynamoDB jobs table name
  - [ ] `DYNAMODB_IDEMPOTENCY_TABLE` → DynamoDB idempotency table name
  - [ ] `ARTIFACTS_BUCKET` → S3 artifacts bucket name
  - [ ] `LOGS_BUCKET` → S3 logs bucket name
  - [ ] `AWS_REGION` → AWS region
  - [ ] `INFINITY_NODE_API_KEY` → static API key for auth
  - [ ] `API_PORT` → Phoenix port (default 4000)
  - [ ] `OTEL_ENDPOINT` → OpenTelemetry collector endpoint
- [ ] Create `config/dev.exs` with dev-specific overrides (local DynamoDB, localstack, etc.)
- [ ] Create `config/prod.exs` with prod-specific overrides (real AWS endpoints)

### Application Supervision Tree
- [ ] Update `Api.Application.start/2` to start:
  1. `Api.Plugs.RateLimitPlug` ETS table initialization
  2. `Api.Observability.TelemetryHandler` attachment
  3. `Api.Observability.OtelExporter` GenServer
  4. `Api.Observability.MetricsReporter` GenServer
  5. `Api.Endpoint` (Phoenix)

---

## Testing

### Unit Tests
- [ ] Test `InfinityNode.JobEnvelope` — validation, defaults, serialization
- [ ] Test `AuthPlug` — valid key, invalid key, missing key
- [ ] Test `RateLimitPlug` — under limit, over limit, different IPs
- [ ] Test `FunctionController` — registration, validation errors
- [ ] Test `InvocationController` — sync flow (mock DynamoDB/SQS), async flow, idempotency conflict
- [ ] Test `JobController` — TERMINAL result, intermediate state, not found, dead-lettered
- [ ] Test `OtelExporter` — buffer accumulation, time-based flush, size-based flush, error handling
- [ ] Test `MetricsReporter` — metric collection, CloudWatch push format

### Integration Tests
- [ ] End-to-end: register function → upload URL → invoke → get result
- [ ] Idempotency: same key twice → 409 on second
- [ ] Rate limiting: burst requests → 429
- [ ] SQS failure simulation: mock SQS error → 503 response (not silent drop)

### Infrastructure Tests
- [ ] `terraform plan` shows expected resources
- [ ] `terraform apply` succeeds without errors
- [ ] Verify all outputs are populated
- [ ] Verify IAM permissions by running test AWS CLI commands with assumed task role

---

## Documentation
- [ ] Update root `README.md` with API endpoint documentation
- [ ] Document environment variables in `.env.example`
- [ ] Document Terraform usage (how to init, plan, apply, destroy)
- [ ] Document how to run the API locally (`mix phx.server`)
- [ ] Document LiveDashboard access URL and auth requirements

---

*Task checklist — Person 3 — Infinity Node v1.0*
