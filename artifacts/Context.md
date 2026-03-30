[4:28 pm, 30/03/2026] Krishang Acm: ### Complete Project Layout v1.0

---

## Root


infinity_node/
│
├── mix.exs                          # Umbrella root — shared deps (ExAws, Jason, Telemetry)
├── mix.lock
├── .tool-versions                   # asdf: erlang 26.2.1, elixir 1.16.1-otp-26
├── .env.example                     # ARTIFACTS_BUCKET, LOGS_BUCKET, AWS_REGION, etc.
├── .gitignore
├── README.md
│
├── config/
│   ├── config.exs                   # Shared app config (env-agnostic)
│   ├── dev.exs                      # Dev overrides (single-node, no ECS)
│   ├── prod.exs                     # Prod overrides (ECS cluster, CloudWatch)
│   └── runtime.exs                  # Runtime config — reads env vars at boot
│                                    #   SQS…
[4:29 pm, 30/03/2026] Krishang Acm: context.md

# Infinity Node — Project Context
### Complete Record of Decisions, Architecture, Team Structure, and Generated Artifacts
#### Session context as of v1.0

---

## 1. What Infinity Node Is

Infinity Node is a *ground-up serverless compute platform* built from the hypervisor layer upward. It is not a wrapper around AWS Lambda, GCP Cloud Run, or any existing serverless offering. The governing thesis is: *compute should behave like object storage* — a developer submits a function artifact and the platform transparently handles execution at any scale, with hardware-enforced isolation per execution, no provisioning, no autoscaling configuration, and no instrumentation required.

It was originally defined in a PRD (v1.0) and expanded through a full design, team breakdown, frontend PRD, and setup tooling in this session.

*The three non-negotiable architectural bets:*

| Bet | Technology | Why |
|---|---|---|
| Sub-millisecond cold starts | AWS Firecracker microVMs + VM memory snapshotting | Eliminates the core failure mode of existing serverless — cold start latency |
| Elastic, fault-tolerant scheduling | Elixir / OTP distributed process cluster | Actor model + supervision trees = scheduler correct by construction |
| Zero-instrumentation observability | OpenTelemetry + Elixir :telemetry baked into execution fabric | Observability is part of the execution model, not bolted on afterward |

---

## 2. Core Technology Stack

Every component was chosen to solve a specific systems problem at the layer it operates in.

| Component | Role | Notes |
|---|---|---|
| *Elixir / OTP* | Distributed scheduler runtime, actor-model concurrency, supervision trees | Excellent fit — maps directly to the problem. Final decision. |
| *AWS Firecracker* | KVM-backed microVM hypervisor, hardware-enforced workload isolation, jailer for seccomp-BPF | Requires bare-metal EC2 (i3.metal or c5.metal). Cannot run on virtualized instances. |
| *VM Snapshotting* | Pre-boot VMs once, restore clean memory snapshot per job | Cold boot ~125ms. Snapshot restore ~5ms. Required for sub-50ms dispatch target. |
| *Rust* | Custom seccomp-BPF syscall filter, cgroups v2 config, jailer layer | Static musl binary. Compiled with x86_64-unknown-linux-musl target. |
| *Virtio-vsock* | Bidirectional channel between host WorkerProcess and guest VM | Used for artifact injection (host→guest) and stdout/stderr streaming (guest→host). Replaces network interface. |
| *Amazon S3* | Function artifact registry, VM snapshot storage, execution log durability | Two buckets: infinity-node-artifacts, infinity-node-logs |
| *Amazon SQS* | Durable job ingestion queue, dead-letter queue | Standard queue (not FIFO). At-least-once delivery. Idempotency layer handles deduplication. Visibility timeout = max job timeout × 2. |
| *Amazon DynamoDB* | Job state machine persistence, idempotency key tracking | Always use strongly consistent reads or conditional writes for state machine transitions. Never eventually consistent reads. PITR enabled. |
| *Amazon ECS* | Container orchestration for API service and worker nodes | Worker nodes use EC2 launch type with metal capacity provider. API uses Fargate. |
| *libcluster* | Automatic Elixir peer discovery over ECS service DNS | Strategy: Cluster.Strategy.DNSPoll, 5s interval |
| *Amazon CloudWatch / OpenTelemetry* | Structured log aggregation, distributed trace collection, real-time metrics | Buffered OTel export (flush every 2s or 100 records). CloudWatch Metrics via :telemetry. |
| *Phoenix* | HTTP API layer | Stateless, horizontally scalable, sits behind AWS ALB. |
| *React 18* | Frontend dashboard | Framer Motion, Recharts, D3, @tanstack/react-virtual, Shiki |

*Technology decision that was explicitly rejected:* CockroachDB was considered as an alternative to DynamoDB for the job state machine. Decision: stick with DynamoDB. Reasons: (1) the state machine is not relational — it's a keyed conditional write pattern that DynamoDB is purpose-built for; (2) CockroachDB adds a stateful distributed cluster to manage on top of an already complex distributed system; (3) higher write latency than DynamoDB at equivalent throughput. Revisit only if the Cost Attribution Engine evolves into complex multi-tenant billing with relational reporting queries.

---

## 3. System Architecture

### Data Flow


Developer
    │
    ▼
[Phoenix HTTP API]  (POST /v1/functions/:id/invoke)
    │
    ├─── Validates input
    ├─── Writes job to DynamoDB (state: PENDING)
    ├─── Enqueues job envelope to SQS
    │
    ▼
[SQS Job Queue]
    │
    ▼
[Elixir SQSConsumer GenServer]  (Person 2)
    │   Long-polls SQS (WaitTimeSeconds: 20)
    │   Backpressure: pauses when worker pool is full
    │
    ▼
[DispatchCoordinator GenServer]  (Person 2)
    │   Consistent-hash ring over cluster nodes
    │   Routes to least-loaded node via gossip load vector
    │   Deletes SQS message on DISPATCHED transition
    │
    ▼
[WorkerProcess GenServer]  (Person 1)  ← one per Firecracker VM slot
    │   Receives {:execute, job_envelope}
    │   Injects artifact + payload via virtio-vsock
    │   Enforces wall-clock timeout
    │   Streams stdout/stderr back from guest
    │
    ▼
[Firecracker microVM]  (Person 1)
    │   Jailer: seccomp-BPF + cgroups v2 + private netns
    │   Read-only base FS + ephemeral tmpfs per execution
    │   Guest kernel: vmlinux 5.10.x (AWS-maintained)
    │
    ▼
[WorkerProcess — post-execution]
    │   Uploads stdout/stderr to S3 (logs bucket)
    │   Emits :telemetry event (telemetry envelope)
    │   Restores VM snapshot
    │   Re-registers as available in Registry
    │   Returns {:ok, result_envelope} to DispatchCoordinator
    │
    ▼
[DynamoDB — job state: TERMINAL]
    │
    ▼
[Phoenix API — result returned]  (sync path: polls DynamoDB)
                                  (async path: client polls GET /v1/jobs/:id)


### Job State Machine


PENDING → SCHEDULED → DISPATCHED → RUNNING → TERMINAL
                                              ↗
                         (retry)  ← SCHEDULED
                                              ↘
                                         DEAD-LETTER  (retry_count >= 3)


All state transitions are *atomic DynamoDB conditional writes* (ConditionExpression: state = expected_current_state). If the condition fails, another node claimed the job. No two nodes can claim the same job simultaneously.

### OTP Supervision Tree


InfinityNode.Application
└── Scheduler.Supervisor  (strategy: :one_for_one)
    ├── Scheduler.ClusterSupervisor  (strategy: :one_for_all)
    │   ├── Cluster.Supervisor (libcluster)
    │   └── Scheduler.NodeRegistry
    ├── Scheduler.DispatchCoordinator
    ├── Scheduler.SQSConsumer
    ├── Scheduler.LeaseReaper          (30s timer — reclaims expired leases)
    ├── Scheduler.AutoscalerDaemon     (15s poll — scale-out/in with hysteresis)
    └── Worker.WorkerPoolSupervisor  (strategy: :one_for_one)
        └── Worker.WorkerProcess × N


---

## 4. DynamoDB Schema

### Jobs Table (infinity-node-jobs)

| Attribute | Type | Purpose |
|---|---|---|
| job_id | String (PK) | UUID |
| state | String | PENDING / SCHEDULED / DISPATCHED / RUNNING / TERMINAL |
| idempotency_key | String (GSI) | Client-provided deduplication |
| artifact_s3_key | String | S3 reference to function tarball |
| input_payload | String | JSON-encoded input |
| resource_limits | Map | {cpu_shares, memory_mb, timeout_ms} |
| assigned_node | String | Node ID holding the lease |
| lease_expires_at | Number | Unix timestamp — reaper reclaims after expiry |
| retry_count | Number | Max 3, then dead-letter |
| result_s3_key | String | Set on TERMINAL |
| failure_reason | String | Set on TERMINAL if failed |
| created_at | Number | Unix timestamp |
| updated_at | Number | Unix timestamp |

*GSI:* (state, lease_expires_at) — used by LeaseReaper to scan state==RUNNING AND lease_expires_at < now().

### Idempotency Table (infinity-node-idempotency)

| Attribute | Type | Purpose |
|---|---|---|
| idempotency_key | String (PK) | Client-provided key |
| job_id | String | Maps to canonical job |
| ttl | Number | Auto-expire after 24h |

---

## 5. Job Envelope Schema

Shared across all three apps. Defined in apps/scheduler/lib/scheduler/job_envelope.ex.

elixir
%{
  job_id:           String.t(),           # UUID
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


### Result Envelope Schema

Returned by Worker.WorkerProcess.execute/2, consumed by DispatchCoordinator and API.

elixir
%{
  job_id:             String.t(),
  exit_code:          integer(),
  stdout_s3_key:      String.t(),         # logs/{job_id}/stdout
  stderr_s3_key:      String.t(),         # logs/{job_id}/stderr
  wall_time_ms:       non_neg_integer(),
  peak_memory_bytes:  non_neg_integer()
}


### Telemetry Envelope Schema

Emitted by WorkerProcess via :telemetry.execute/3 on execution completion. Consumed by Api.Observability.TelemetryHandler.

elixir
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


---

## 6. Vsock Channel Protocol

The virtio-vsock channel replaces a network interface for host↔guest communication. Custom framing protocol defined in apps/worker/lib/worker/vsock_channel.ex.

*Host → Guest (artifact injection):*

[4 bytes: artifact_size][artifact_bytes][4 bytes: payload_size][payload_bytes]


*Guest → Host (output streaming):*

[1 byte: stream_type (0=stdout, 1=stderr)][4 bytes: chunk_size][chunk_bytes]
... repeating ...
[1 byte: 0xFF (terminator)][4 bytes: exit_code]


If framing breaks (corrupt frame detected on host side), WorkerProcess must force-terminate the VM rather than hang. Read timeout: 500ms beyond the declared job wall-clock timeout.

---

## 7. Autoscaler Behavior

Managed by Scheduler.AutoscalerDaemon. Polls every 15 seconds.

*Scale-out trigger:* queue_depth > available_slots × 2 for 2 consecutive polls → scale out by ceil(queue_depth / slots_per_node) nodes, capped at configured maximum.

*Scale-in trigger:* available_slots > queue_depth × 3 for 5 consecutive polls (75 seconds of sustained idleness) → drain the least-loaded node: it stops accepting jobs, waits for in-flight jobs to complete, deregisters from cluster, terminates.

*Hard floor:* Never scale below 1 node.

*Why hysteresis matters:* Without the 5-poll window, oscillating load causes repeated scale-in/scale-out cycles that thrash ECS and incur startup latency costs. The window was set from day one — do not remove it.

---

## 8. Team Structure

The project is divided across 3 engineers with explicit ownership boundaries and handoff contracts.

### Person 1 — Execution Engine
*Owns:* apps/worker/, rust/jailer/, firecracker/

Responsible for everything that happens inside and around a Firecracker microVM. The most hardware-close work on the project. Requires a bare-metal EC2 instance with KVM.

*Phases:*
- Phase 0: Hardware validation — boot one Firecracker VM manually, get echo hello back
- Phase 1: VM snapshot pipeline — pre-boot + restore cycle, store in S3
- Phase 2: Jailer + security — seccomp-BPF filter (Rust), cgroups v2, private network namespace
- Phase 3: WorkerProcess GenServer — full state machine, Registry integration
- Phase 4: Vsock channel protocol — framing, inject/collect, timeout handling
- Phase 5: Load validation — 100 concurrent jobs, supervisor restart test

*Delivers to Person 2:* WorkerProcess module + {:execute, job_envelope} interface + result envelope schema
*Delivers to Person 3:* S3 key convention for log objects + VM snapshot S3 key

*Setup prerequisites:* KVM (/dev/kvm), cgroups v2, Rust toolchain + musl target, Elixir/OTP 26 via asdf, Firecracker v1.7.0 binary, guest kernel vmlinux 5.10.x, base rootfs (Alpine), per-slot rootfs copies

### Person 2 — Distributed Scheduler
*Owns:* apps/scheduler/

Responsible for the brain of the platform — job state machine, SQS consumer, peer discovery, dispatch routing, lease reaping, autoscaling.

*Phases:*
- Phase 0: DynamoDB schema design — access patterns on paper before any code
- Phase 1: Job state machine — atomic conditional writes, idempotency enforcement
- Phase 2: SQS consumer loop — long-poll, backpressure, visibility timeout
- Phase 3: OTP supervision tree — draw on paper before writing any GenServer
- Phase 4: Distribution layer — libcluster, gossip load vector, DispatchCoordinator
- Phase 5: Autoscaler daemon — hysteresis window from day one

*Needs from Person 1:* WorkerProcess interface, Registry key format
*Needs from Person 3:* SQS queue URLs, DynamoDB table names, IAM task role ARN, agreed job envelope schema
*Delivers to Person 3:* Job state query interface (JobStore.get/1), dead-letter table name, SNS topic ARN

### Person 3 — API + Observability + Infrastructure
*Owns:* apps/api/, infra/, frontend/

Responsible for everything the developer touches (HTTP API, upload flow) and everything the operator watches (telemetry pipeline, CloudWatch, dashboard). Also provisions all AWS infrastructure — which must happen on Day 1 so Persons 1 and 2 are not blocked.

*Phases:*
- Phase 0: Infrastructure provisioning — S3, SQS, DynamoDB, ECS skeleton, IAM, CloudWatch log groups. Publish all ARNs and URLs to team immediately.
- Phase 1: Job envelope schema — define and share before anyone writes code
- Phase 2: Phoenix API — function registration, presigned S3 URLs, sync/async invocation, result retrieval
- Phase 3: Telemetry pipeline — OTel handler, CloudWatch export, buffered flush
- Phase 4: Real-time metrics — :telemetry → CloudWatch Metrics, 10s reporting interval
- Phase 5: Monitoring dashboard — Phoenix LiveDashboard with custom pages (Overview, Queue State, Latency, Job Explorer, Failure Log)
- Phase 6 (stretch): Webhook trigger system

---

## 9. API Surface

All endpoints under /v1/. Static API key authentication via x-api-key header (MVP).

| Method | Path | Purpose |
|---|---|---|
| POST | /v1/functions | Register a function (name, runtime, description) |
| POST | /v1/functions/:id/upload-url | Get presigned S3 PUT URL for artifact upload |
| POST | /v1/functions/:id/invoke | Synchronous invocation (blocks until TERMINAL or timeout) |
| POST | /v1/functions/:id/invoke/async | Async invocation — returns 202 + job_id immediately |
| GET | /v1/jobs/:job_id | Result retrieval — full envelope if TERMINAL, state if not |

*HTTP status conventions:*
- 400: validation failure
- 409: idempotency key conflict (returns existing job_id)
- 429: rate limited
- 503: SQS enqueue failure (surfaced explicitly, never silently dropped)

---

## 10. Infrastructure Inventory

All provisioned by Person 3 via Terraform (or CDK). Published as shared outputs.

### S3 Buckets
- infinity-node-artifacts — function tarballs, VM snapshots. Versioning ON.
- infinity-node-logs — stdout/stderr per execution. Lifecycle: expire after 30 days.

### SQS Queues
- infinity-node-jobs — main job queue. Standard (not FIFO). Visibility timeout 600s.
- infinity-node-jobs-dlq — dead-letter. MaxReceiveCount: 3 on main queue redrive.

### DynamoDB Tables
- infinity-node-jobs — job state machine. GSI on (state, lease_expires_at). PITR ON.
- infinity-node-idempotency — deduplication. TTL attribute on ttl field.

### IAM Roles (two — kept separate)
- *Task execution role:* ECR pull, CloudWatch log write (AWS-managed plumbing)
- *Task role (application):* SQS read/delete, DynamoDB read/write, S3 read/write (scoped), Auto Scaling SetDesiredCapacity, SNS Publish

### ECS
- Cluster with two task definitions: API (Fargate) + Worker (EC2 metal capacity provider)
- Application Load Balancer in front of API service

### CloudWatch
- Log groups: /infinity-node/api, /infinity-node/worker, /infinity-node/scheduler
- Retention: 14 days
- Alarms: dead-letter > 0, P99 > 500ms for 5min, worker count = 0, queue depth > 1000 for 10min

---

## 11. Frontend Design System

### Aesthetic Direction
*"Dark Systems Glass"* — PostHog's data density + Vercel's layout discipline + terminal-meets-glass aesthetic. Always dark. No light mode in MVP. Fonts: Syne (display/headings) + DM Mono (all metrics, hashes, IDs, logs).

### Color Palette (key tokens)
- Background void: #080a0e
- Primary surface: #0d1117
- Accent primary (blue): #58a6ff
- Accent secondary (purple): #a371f7
- Status success: #3fb950
- Status error: #f85149
- Status running glow: rgba(121, 192, 255, 0.25)

### Dashboard Pages
1. *Overview* — hero metric bar (5 live KPIs with NumberTick animation), execution swimlane per worker node, recent jobs feed, cluster health donut chart, deployment card
2. *Jobs* — dense filterable table, Job Detail Drawer (slides from right, tabs: Summary / Logs / Input+Output / Timeline)
3. *Logs* — real-time virtual log viewer (50k line buffer), PostHog-style search dimming, per-level color coding, observability sidebar with sparklines and trace waterfall
4. *Functions* — animated drag-and-drop upload zone (terminal-style progress output on upload), function cards with sparklines, detail page with interactive Invoke sandbox
5. *Containers* — mirrors Functions page, adds Docker image URL input + manifest analysis
6. *Analytics* — invocation charts, latency percentile stack, node utilization heatmap (D3)

### Real-Time Data
Single WebSocket connection per session. Event types: job.created, job.updated, job.terminal, metrics.update, log.line, node.joined, node.left, scale.event. Virtual list for logs (@tanstack/react-virtual). All metric numbers animate with NumberTick on change.

---

## 12. Stretch Goals

All three are defined in the PRD and are additive — they do not require architectural changes to the core.

### 6.1 Cost Attribution Engine
Track CPU-milliseconds and memory-seconds per execution. Apply pricing function ($0.000002/CPU-ms + $0.0000004/MB-second). Attach cost_receipt to the telemetry envelope. Aggregate per function and per time window. *Build after Phase 4* — it's one extra field on the telemetry envelope.

### 6.2 Event-Driven Trigger System
Each registered function gets a cryptographically signed webhook endpoint backed by AWS Lambda. Lambda validates HMAC signature, drops a standard job envelope into SQS. The scheduler never knows it came from a webhook. *Build after Phase 2 (SQS consumer solid).* Long-term: route webhooks through Phoenix API directly instead of Lambda.

### 6.3 Multi-Region Execution Simulation
A preferred_region routing label on worker nodes. Dispatch coordinator does label-matching before hash-ring assignment, falls back to any available node on capacity exhaustion. Implemented as a tag on ECS tasks propagated into the gossip load vector. *A Phase 3 extension — a few dozen lines.*

---

## 13. Build Order (Recommended)

The PRD defines a 48-hour hackathon timeline. The recommended real-world sequence is:

| Phase | Goal | Owner |
|---|---|---|
| 0 | Hardware validation (KVM), infrastructure provisioning, schema design, job envelope agreed | P1 + P3 in parallel; P2 designs schema |
| 1 | Single-node execution: one job in → stdout out → VM wiped | P1 primary |
| 2 | Job state machine + SQS consumer | P2 primary; P1 integrates WorkerProcess |
| 3 | Distribution: libcluster, DispatchCoordinator, LeaseReaper, AutoscalerDaemon | P2 primary |
| 4 | API surface + observability pipeline | P3 primary; P1 confirms telemetry event shape |
| 5 | Hardening: 500-job load test, crash testing, telemetry lag verification | All |
| 6 | Stretch goals (Cost Attribution, Webhooks, Multi-region labels) | All |

---

## 14. Success Criteria (Operationalized)

| Criterion | How to Test |
|---|---|
| Firecracker hardware isolation | uname -a in guest → different kernel. cat /proc/self/cgroup → cgroup constraints visible. curl from guest → fails. |
| 500 concurrent jobs trigger autoscaler within 60s | Load script fires 500 jobs in 5s burst. CloudWatch ECS task count increases. All 500 reach TERMINAL. |
| No job silently lost | After load test: count(TERMINAL) + count(dead-letter) == 500. Zero gap. |
| Dashboard lag under 5 seconds | Trigger job, measure time from execution start to metric appearing in LiveDashboard. |
| Single node crash no job loss | Kill ECS task mid-execution. After lease expiry, verify jobs re-enter SCHEDULED and complete. |

---

## 15. Key Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Firecracker snapshotting unstable under repeated cycles | High | Test 1000 restorations in a loop before building on top. Fallback: cold-boot VMs, flag latency impact. |
| Metal instances expensive during dev | High | Spot instances. Single metal for dev, ECS cluster only for distribution testing. Snapshot AMI daily. |
| DynamoDB conditional write races under high concurrency | Medium | Adversarial test: 10 concurrent claimants for 1 job, 1000 iterations. Must have exactly 1 winner each time. |
| OTP supervision tree mistakes expensive to refactor | Medium | Draw the full supervision tree on paper before writing any GenServer code. |
| seccomp filter blocks needed syscalls | Medium | Start permissive, audit with strace, tighten iteratively. Never start tight. |
| Autoscaler thrashing under oscillating load | Medium | Implement hysteresis window from day one. Do not remove it to "simplify." |
| SQS visibility timeout too short | Medium | Set to max job timeout × 2. Default 600s. Configurable. |

---

## 16. Documents Generated in This Session

| File | Contents |
|---|---|
| docs/design.md | Architecture overview, build phases, tech decisions, risks, success criteria |
| docs/team/person1.md | Person 1 full scope, phase breakdown, handoff contracts, file ownership |
| docs/team/person2.md | Person 2 full scope, DynamoDB schema, OTP supervision tree, handoff contracts |
| docs/team/person3.md | Person 3 full scope, API endpoints, telemetry pipeline, infra checklist |
| docs/team/person1-setup-prompt.md | LLM-ready setup prompt: 7-phase setup for Person 1 from blank metal instance |
| docs/frontend-prd.md | Full frontend PRD: design system, color tokens, animations, all page specs, component library, WebSocket architecture |
| docs/folder.md | Complete annotated folder structure for the entire project |
| docs/context.md | This file — full project context |
