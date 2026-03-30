# Infinity Node — Design & Growth Document

### Understanding the PRD + Where to Start Building

---

## What This PRD Is

Infinity Node is a **from-scratch serverless compute platform** — not a wrapper over AWS Lambda or GCP Cloud Run, but a fundamentally new execution substrate built from the hypervisor layer upward.

The core thesis: _compute should work like object storage_. You hand it a function, it runs at any scale, with zero provisioning on your part. The platform handles isolation, scheduling, retries, autoscaling, and observability automatically.

It's built on three hard technical bets:

| Bet                                | Technology                                               | Why It Matters                                                   |
| ---------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------- |
| Sub-millisecond cold starts        | AWS Firecracker microVMs + VM snapshotting               | Eliminates the core failure mode of existing serverless          |
| Elastic, fault-tolerant scheduling | Elixir / OTP distributed process cluster                 | Scheduler that's correct by construction, not convention         |
| Zero-instrumentation observability | OpenTelemetry + `:telemetry` baked into execution fabric | Observability isn't bolted on — it's part of the execution model |

The PRD is ambitious but structurally sound. Every component exists for a reason, and the dependency graph between them is explicit. This is a strong foundation to build from.

---

## The Full System — How It Fits Together

```
Developer
    │
    ▼
[Phoenix HTTP API]  ──────────────────────────────────────────────┐
    │  (artifact upload, invoke, result retrieval)                 │
    ▼                                                              │
[S3 Artifact Store]  ◄─── function tarballs                       │
    │                                                              │
    ▼                                                              │
[SQS Job Queue]  ◄─── structured job envelope                     │
    │              (artifact ref, resource limits, idempotency key)│
    ▼                                                              │
[DynamoDB]  ◄─── job state machine (PENDING → TERMINAL)           │
    │                                                              ▼
[Elixir OTP Cluster]                                      [DynamoDB Dead-Letter]
    ├── DispatchCoordinator (consistent-hash routing)
    ├── WorkerPoolSupervisor × N nodes
    │       └── WorkerProcess × M slots per node
    │               │
    │               ▼
    │       [Firecracker microVM]
    │           ├── jailer (seccomp-BPF, cgroups v2, private netns)
    │           ├── read-only base FS + ephemeral tmpfs
    │           ├── virtio-vsock (artifact injection + log streaming)
    │           └── VM snapshot restore on job completion
    │
    └── AutoscalerDaemon
            └── AWS Auto Scaling API (scale-out / scale-in with hysteresis)

[Observability]
    ├── Structured telemetry envelope per execution
    ├── OpenTelemetry → CloudWatch Logs
    ├── Elixir :telemetry → real-time metrics (P50/P95/P99, queue depth, etc.)
    └── Monitoring dashboard (live cluster state)
```

---

## Where the Real Complexity Lives

Understanding where the hard problems are helps you sequence work correctly.

### 1. Firecracker VM Lifecycle (Highest Complexity)

This is the most technically demanding piece. Firecracker requires KVM hardware support, which means bare-metal or metal AWS instances (e.g., `i3.metal`, `c5.metal`). The snapshotting approach — pre-booting VMs and restoring clean memory snapshots per job — is what makes sub-50ms dispatch possible. Getting this right requires:

- Firecracker binary configuration + the jailer process
- A proper seccomp-BPF filter (authored in Rust)
- cgroups v2 resource enforcement
- The virtio-vsock channel for payload injection and log streaming
- Snapshot creation, storage, and reliable restoration under load

### 2. OTP Supervision Tree Design (High Complexity, High Leverage)

The Elixir scheduler is the heart of the platform's reliability story. The supervision tree design determines how failures propagate and what survives a crash. Getting the process hierarchy right — which supervisor owns what, what the restart strategies are, how the `DispatchCoordinator` and `WorkerProcess` actors communicate — is work that has permanent downstream effects on correctness.

### 3. Exactly-Once Scheduling Semantics (High Complexity)

The idempotency key + DynamoDB conditional write approach for the job state machine is the correctness guarantee for the entire platform. A race between two nodes both attempting to claim the same job must be impossible. This requires careful implementation and adversarial testing.

### 4. Autoscaler Hysteresis (Medium Complexity)

Scale-out is straightforward. Scale-in without thrashing under oscillating load requires getting the hysteresis window tuned correctly. Too aggressive: nodes terminate mid-job. Too conservative: you pay for idle capacity. This is a real operations problem and needs load testing to validate.

---

## Recommended Build Order

The PRD's 48-hour timeline is a hackathon sprint. For a real build, here's a more deliberate sequence that lets you validate each layer before building the next.

### Phase 0 — Foundation (Before Writing Code)

1. Provision a metal EC2 instance (you cannot test Firecracker without KVM)
2. Confirm Firecracker boots a minimal guest — get a single `hello world` execution working by hand
3. Create the Elixir umbrella project skeleton: `apps/api`, `apps/scheduler`, `apps/worker`
4. Stand up SQS, DynamoDB (with the job state machine table and idempotency table), and S3 bucket
5. Write the DynamoDB schema with explicit access patterns before any code touches it

### Phase 1 — Single-Node Execution Engine

Goal: one job in → stdout out → VM wiped. No distribution yet.

- `WorkerProcess` GenServer that manages one Firecracker slot
- VM snapshot creation script (build once, store in S3)
- Virtio-vsock channel: inject artifact + input, stream stdout/stderr back
- Force-terminate at wall-clock timeout
- VM slot restore from snapshot after execution
- `WorkerPoolSupervisor` owning N `WorkerProcess` actors with `:one_for_one` restart

This is the core value proposition. Get this right before touching distribution.

### Phase 2 — Job State Machine + Queue Integration

Goal: reliable job lifecycle from submission to terminal state.

- DynamoDB state machine: `PENDING → SCHEDULED → DISPATCHED → RUNNING → TERMINAL`
- Atomic conditional writes for each transition (test this with concurrent writes)
- SQS consumer loop feeding jobs to the local worker pool
- Idempotency key enforcement across retries
- Dead-letter routing for jobs that exhaust retry budget
- SNS alert on dead-letter insertion

### Phase 3 — Distribution

Goal: multiple nodes, jobs route to the right one.

- `libcluster` peer discovery over ECS service DNS
- Gossip-propagated load vector per node
- `DispatchCoordinator` with consistent-hash ring
- Lease expiry and job reclamation for partitioned nodes
- `AutoscalerDaemon` emitting scale signals based on queue depth high-water mark

### Phase 4 — API Surface + Observability

Goal: developer-facing interface + operational visibility.

- Phoenix API: artifact upload (presigned S3 URL), function registration, sync invoke, async invoke, result retrieval
- Structured telemetry envelope emission per execution
- OpenTelemetry exporter to CloudWatch
- Real-time metrics via `:telemetry`: P50/P95/P99 latency, queue depth, worker count, failure rate
- Monitoring dashboard

### Phase 5 — Hardening

Goal: the system is correct under adversarial conditions, not just happy path.

- Load test: 500 concurrent job submissions
- Validate autoscaler response: new nodes join within 60 seconds, queue drains without job loss
- Deliberately crash worker nodes mid-execution: verify job reclamation and re-dispatch
- Deliberately inject failures to push jobs to dead-letter: verify alert fires
- Verify telemetry lag is under 5 seconds

---

## Stretch Goals — How to Approach Them

### Cost Attribution Engine (6.1)

This is additive and low-risk. The execution telemetry envelope already contains wall time and peak memory. Add CPU-milliseconds to what the WorkerProcess tracks, apply the pricing function at the end of execution, and attach the cost receipt to the result object. Build this after Phase 4 — it's one extra field on the telemetry envelope and one aggregation query.

### Event-Driven Trigger System (6.2)

The Lambda webhook layer is actually cleanly separated from the core scheduler — Lambda validates the inbound request and drops a structured envelope into SQS. The scheduler never needs to know the job came from a webhook vs. the API. Build this once the SQS consumer loop is solid (Phase 2 complete).

### Multi-Region Execution (6.3)

This is a routing label on worker nodes, not actual multi-region infrastructure. Implement it as a `preferred_region` tag on ECS tasks that gets propagated into the gossip load vector. The dispatch coordinator does label-matching before hash-ring assignment. This is a Phase 3 extension — a few dozen lines once the scheduler is running.

---

## Risks and How to Mitigate Them

| Risk                                                             | Likelihood | Mitigation                                                                                                                     |
| ---------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Firecracker snapshotting complexity takes longer than expected   | High       | Timebox Phase 0 validation hard. If snapshot restoration is unstable, fall back to cold-boot VMs initially and optimize later. |
| Metal instances are expensive to keep running during development | High       | Use spot instances. Use a single metal instance for local dev; only move to ECS cluster for distribution testing.              |
| DynamoDB conditional write races under high concurrency          | Medium     | Write explicit concurrency tests with multiple goroutines before trusting correctness.                                         |
| Autoscaler thrashing under bursty load                           | Medium     | Implement hysteresis window from day one — don't iterate on it later.                                                          |
| OTP supervision tree design mistakes are expensive to refactor   | Medium     | Sketch the full supervision tree on paper before writing any GenServer code.                                                   |
| seccomp-BPF filter blocks legitimate syscalls in guest           | Medium     | Start with a permissive filter, audit syscall usage, tighten iteratively.                                                      |

---

## Technology Decisions Worth Revisiting

The PRD makes strong technology choices. Most are correct. A few are worth stress-testing:

**Elixir + OTP for the scheduler** — excellent fit. The actor model and supervision trees map directly to the problem. This is the right call.

**Firecracker + snapshotting** — correct for the cold-start thesis. However, snapshotting requires careful guest OS configuration. Test early that your guest kernel supports the snapshot/restore cycle reliably.

**DynamoDB for the job state machine** — correct for durability and conditional writes. Be aware that DynamoDB's eventually consistent reads must never be used for state machine transitions — always use strongly consistent reads or conditional writes.

**AWS Lambda for webhook routing (6.2)** — fine for a stretch goal, but note this introduces a managed Lambda dependency that somewhat contradicts the "not a wrapper over existing serverless" positioning. A long-term clean version routes webhooks through the Phoenix API directly. Keep Lambda for the demo, revisit for production.

**SQS as the job queue** — correct. Standard queue gives at-least-once delivery; the idempotency layer handles deduplication. FIFO queue is not needed and limits throughput.

---

## Success Criteria — Operationalized

The PRD's success criteria are correct but need operational definitions to be testable:

| Criterion                                         | How to Test It                                                                                                                                                                        |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Function executes in Firecracker with isolation   | Run `uname -a` in guest, verify different kernel namespace. Run `cat /proc/self/cgroup` and verify cgroup constraints. Attempt outbound network connection from guest — it must fail. |
| 500 concurrent jobs trigger autoscaler within 60s | Load script fires 500 jobs in a 5-second burst. CloudWatch metric for active ECS task count must increase. All 500 jobs must reach TERMINAL state.                                    |
| No job silently lost                              | After 500-job load test, query DynamoDB: count(TERMINAL) + count(dead-letter) must equal 500. Zero gap.                                                                               |
| Dashboard lag under 5 seconds                     | Trigger a job and measure time from execution start to metric appearing in dashboard.                                                                                                 |
| Single node crash does not cause job loss         | Kill an ECS task while it has in-flight jobs. After lease expiry, verify those jobs re-enter SCHEDULED state and complete.                                                            |

---

## What to Build First — Actionable Starting Point

If you're starting today, this is the exact sequence:

1. **Provision an i3.metal EC2 instance** and manually boot a Firecracker microVM using the official getting-started guide. Get one function — a shell script that echoes "hello" — to execute and return output. This is your proof-of-concept. Nothing else matters until this works.

2. **Create the Elixir umbrella project** with `mix new infinity_node --umbrella` and stub out the three apps: `api`, `scheduler`, `worker`.

3. **Write the DynamoDB table schema** before writing any Elixir code that touches it. Define the access patterns: lookup by job ID, scan by state for lease expiry, conditional write for state transition. Get this right once.

4. **Implement WorkerProcess** as a GenServer that wraps a single Firecracker slot. Wire it to receive a job message, execute the function, return the result, and restore the VM slot. Unit test this in isolation on your metal instance.

5. **Implement the SQS consumer** that feeds jobs to WorkerProcess. This gives you a working end-to-end path: API → SQS → WorkerProcess → Firecracker → result persisted to S3.

Everything after that is distribution, scale, and polish.

---

_document version 1.0 — based on Infinity Node PRD v1.0_
