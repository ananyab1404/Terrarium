@207236550930675

# Person 2 — Distributed Scheduler

### Elixir / OTP · Job State Machine · SQS · Distribution · Autoscaler

---

## Your Role in the System

You own the **brain of the platform** — the Elixir OTP cluster that decides what runs where, tracks every job from submission to terminal state, handles failures without losing work, and scales the cluster in response to load.

You sit between ingestion (Person 3's API) and execution (Person 1's WorkerProcess). Your job is to ensure that every job that enters the system reaches a terminal state — either successfully executed, or explicitly routed to dead-letter with a structured failure reason. Nothing is silently lost on your watch.

---

## Your Part of the Architecture

```
SQS Job Queue  ←── job envelopes arrive here (from Person 3's API)
    │
    ▼
[SQS Consumer Loop]  ←── you own this
    │
    ▼
[DynamoDB Job State Machine]  ←── PENDING → SCHEDULED → DISPATCHED → RUNNING → TERMINAL
    │         (atomic conditional writes — you own this)
    ▼
[DispatchCoordinator GenServer]
    │   consistent-hash ring
    │   gossip-propagated load vector
    ▼
[WorkerPoolSupervisor × N nodes]
    └── WorkerProcess × M slots  ←── Person 1 owns these, you route to them
            │
            ▼
        Firecracker execution  ←── Person 1 owns this

[AutoscalerDaemon]
    └── AWS Auto Scaling API  ←── scale-out / scale-in with hysteresis

[libcluster]
    └── ECS service DNS peer discovery
```

---

## Stack You're Working In

- **Elixir / OTP** — GenServers, Supervisors, Registry, `:pg` process groups, `:telemetry`
- **libcluster** — automatic peer discovery over ECS service DNS
- **AWS SDK (ExAws)** — SQS consumer, DynamoDB conditional writes, Auto Scaling API
- **DynamoDB** — job state machine, idempotency key table, lease tracking

---

## Phase-by-Phase Breakdown

### Phase 0 — Schema and Data Model First

**Before writing a single GenServer**, design the DynamoDB schema. The state machine correctness depends entirely on getting this right. Changing it later is painful.

**Jobs table:**

| Attribute          | Type         | Notes                                                       |
| ------------------ | ------------ | ----------------------------------------------------------- |
| `job_id`           | String (PK)  | UUID, content-addressed                                     |
| `state`            | String       | `PENDING \| SCHEDULED \| DISPATCHED \| RUNNING \| TERMINAL` |
| `idempotency_key`  | String (GSI) | Client-provided, deduplication                              |
| `artifact_s3_key`  | String       | Points to function artifact in S3                           |
| `input_payload`    | String       | JSON-encoded input                                          |
| `resource_limits`  | Map          | `{cpu_shares, memory_mb, timeout_ms}`                       |
| `assigned_node`    | String       | Node ID that claimed this job (for lease tracking)          |
| `lease_expires_at` | Number       | Unix timestamp; scheduler reclaims after expiry             |
| `retry_count`      | Number       | Incremented on each re-enqueue                              |
| `result_s3_key`    | String       | Set on TERMINAL                                             |
| `failure_reason`   | String       | Set on TERMINAL if failed                                   |
| `created_at`       | Number       | Unix timestamp                                              |
| `updated_at`       | Number       | Unix timestamp                                              |

**Idempotency table** (separate table):

| Attribute         | Type        | Notes                       |
| ----------------- | ----------- | --------------------------- |
| `idempotency_key` | String (PK) |                             |
| `job_id`          | String      | Maps key → canonical job ID |
| `ttl`             | Number      | Auto-expire after 24h       |

**GSI on `state`** — you'll need to scan for jobs in `RUNNING` state with expired leases. Add a GSI on `(state, lease_expires_at)`.

Write the access patterns down before touching code:

1. Create a job (conditional: key must not exist)
2. Transition state (conditional: current state must equal expected)
3. Claim a job for a node (conditional: state == SCHEDULED, set assigned_node + lease)
4. Scan for expired leases (GSI query: state == RUNNING, lease_expires_at < now)
5. Route dead-letter (conditional: retry_count >= max)

---

### Phase 1 — Job State Machine

**Goal:** Every state transition is an atomic conditional write. No two nodes can claim the same job.

Implement a `JobStore` module that wraps all DynamoDB access. It must never use eventually consistent reads for state machine operations — always use `ConsistentRead: true` or conditional writes.

```elixir
# State transition — must be atomic
JobStore.transition(job_id, from: :scheduled, to: :dispatched, node_id: node_id)
# Internally: DynamoDB UpdateItem with ConditionExpression: state = :scheduled
# If condition fails: another node claimed it — return {:error, :already_claimed}
```

**Test this with adversarial concurrency before trusting it.** Spawn 10 Elixir processes all trying to claim the same job simultaneously. Exactly one must succeed. The other nine must receive `{:error, :already_claimed}`. Run this test 1000 times.

**Idempotency enforcement:**

- On job submission, write to the idempotency table with a conditional: key must not exist
- If the key already exists, return the existing `job_id` — do not create a duplicate job
- The TTL on idempotency records is 24 hours

---

### Phase 2 — SQS Consumer Loop

**Goal:** Reliably pull jobs from SQS and hand them to the local worker pool.

The SQS consumer is a GenServer that runs a polling loop. Key design decisions:

- **Long polling** — use `WaitTimeSeconds: 20` on ReceiveMessage. This reduces API calls and latency.
- **Visibility timeout** — set to 2× the maximum job wall-clock timeout. A job that's in-flight must not become visible to other consumers while it's running.
- **Delete on claim, not on completion** — delete the SQS message as soon as the job transitions to `DISPATCHED` in DynamoDB. The DynamoDB state machine is the source of truth for job lifecycle, not SQS. SQS is just the ingestion queue.
- **Backpressure** — if the local worker pool is at capacity (no available `WorkerProcess` slots), pause polling. Do not pull jobs you can't immediately dispatch. SQS will make them visible to other nodes.

```elixir
defmodule Scheduler.SQSConsumer do
  use GenServer

  def handle_info(:poll, state) do
    case WorkerRegistry.available_slots() do
      0 ->
        # Pool full — back off and retry
        Process.send_after(self(), :poll, 500)
      _ ->
        messages = SQS.receive_messages(queue_url, max: 10)
        Enum.each(messages, &dispatch_job/1)
        Process.send_after(self(), :poll, 100)
    end
    {:noreply, state}
  end
end
```

---

### Phase 3 — OTP Supervision Tree

**Goal:** Define the supervision hierarchy so that failures are contained and processes recover automatically.

Sketch this on paper before writing code. Here is the intended tree — do not deviate from this without a documented reason:

```
InfinityNode.Application
└── Scheduler.Supervisor  (strategy: :one_for_one)
    ├── Scheduler.ClusterSupervisor  (strategy: :one_for_all)
    │   ├── Cluster.Supervisor (libcluster)
    │   └── Scheduler.NodeRegistry
    ├── Scheduler.DispatchCoordinator  (GenServer)
    ├── Scheduler.SQSConsumer  (GenServer)
    ├── Scheduler.LeaseReaper  (GenServer — scans expired leases on a timer)
    ├── Scheduler.AutoscalerDaemon  (GenServer)
    └── Worker.WorkerPoolSupervisor  (Person 1's supervisor, you supervise it)
        └── Worker.WorkerProcess × N  (Person 1's actors)
```

**Restart strategy rationale:**

- `ClusterSupervisor` is `:one_for_all` — if peer discovery breaks, restart both libcluster and the node registry together
- Everything else is `:one_for_one` — a crashing `SQSConsumer` should not restart the `DispatchCoordinator`
- `WorkerPoolSupervisor` is `:one_for_one` — a crashing `WorkerProcess` does not affect siblings

---

### Phase 4 — Distribution Layer

**Goal:** Multiple nodes, jobs route to the right one. Nodes join and leave without losing work.

**libcluster configuration:**

```elixir
config :libcluster,
  topologies: [
    infinity_node: [
      strategy: Cluster.Strategy.DNSPoll,
      config: [
        query: "infinity-node-worker.internal",  # ECS service DNS
        poll_interval: 5_000
      ]
    ]
  ]
```

**DispatchCoordinator:**

- Maintains a consistent-hash ring over known cluster nodes
- Receives `{:dispatch, job_envelope}` messages from the SQS consumer
- Routes to the least-loaded node using the gossip load vector
- Falls back to any available node if the preferred node is at capacity
- If no nodes are available, re-enqueues the job to SQS (do not drop it)

**Gossip load vector:**

- Each node periodically broadcasts its current load: `{node_id, available_slots, queue_depth}`
- Use `:pg` process groups or Phoenix.PubSub for broadcast (do not use a shared database for this)
- The `DispatchCoordinator` maintains an in-memory map of `node_id → load_vector` and uses it for routing decisions
- Entries older than 10 seconds are considered stale — treat stale nodes as unavailable

**Lease reaper:**

- Runs on a 30-second timer
- Queries DynamoDB GSI: `state == RUNNING AND lease_expires_at < now()`
- For each expired lease: transition job back to `SCHEDULED`, increment `retry_count`, re-enqueue to SQS
- If `retry_count >= max_retries (default: 3)`: route to dead-letter table, emit SNS alert

---

### Phase 5 — Autoscaler Daemon

**Goal:** React to queue depth changes without thrashing.

The `AutoscalerDaemon` watches two signals:

1. SQS `ApproximateNumberOfMessages` (polled every 15 seconds)
2. Cluster-wide available slot count (from the gossip load vector)

**Scale-out trigger:**

- If `queue_depth > available_slots * 2` for two consecutive polls → emit scale-out signal
- Call the AWS Auto Scaling API to increase desired count by `ceil(queue_depth / slots_per_node)`
- Cap scale-out at a configured maximum node count

**Scale-in trigger:**

- If `available_slots > queue_depth * 3` for five consecutive polls → initiate scale-in
- The hysteresis window (5 polls × 15 seconds = 75 seconds of sustained idleness) prevents thrashing
- Pick the least-loaded node as the scale-in target
- Send it a `:drain` message: it stops accepting new jobs, waits for in-flight jobs to complete, deregisters from the cluster, then terminates

**Do not scale in below 1 node.** The minimum cluster size is 1.

---

## Handoff Contracts

### What you need from Person 1 (Execution Engine):

- `WorkerProcess` module name and the `{:execute, job_envelope}` message interface
- The result envelope schema so the LeaseReaper and DispatchCoordinator can parse results
- `Registry` key format for worker slot availability — you need this for backpressure logic in the SQS consumer

### What you need from Person 3 (API + Infra):

- SQS queue URL and DynamoDB table names (from Terraform/CDK outputs)
- IAM role with permissions: SQS ReceiveMessage/DeleteMessage, DynamoDB read/write, Auto Scaling SetDesiredCapacity
- The job envelope schema that Person 3's API writes to SQS — you must agree on this before either of you writes code

### What you deliver to Person 3 (API + Infra):

- Job state query interface: `JobStore.get(job_id)` — Person 3's result retrieval endpoint calls this
- The dead-letter table name and SNS topic ARN — Person 3 wires up the CloudWatch alert

---

## Risk Register

| Risk                                                     | What to do                                                                                                                                               |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Conditional write races under high concurrency           | Write the adversarial concurrency test (10 claimants, 1 winner) before trusting the state machine. Run it 1000 times.                                    |
| libcluster fails to discover peers on ECS                | Test peer discovery in a two-node ECS setup before building the full dispatch logic on top of it.                                                        |
| Gossip load vector becomes stale under network partition | Treat entries older than 10s as stale. Never route to a node whose load vector you can't trust.                                                          |
| AutoscalerDaemon thrashes under oscillating load         | Implement the hysteresis window from day one. The 5-poll window is the minimum — tune upward if needed.                                                  |
| Lease reaper re-enqueues a job that's still running      | Set visibility timeout on SQS messages to 2× the max job timeout. A running job must remain invisible long enough for the lease reaper to not interfere. |

---

## Key Files You'll Own

```
apps/scheduler/
    lib/
        dispatch_coordinator.ex     ← Consistent-hash routing GenServer
        sqs_consumer.ex             ← SQS polling loop with backpressure
        job_store.ex                ← DynamoDB state machine wrapper
        lease_reaper.ex             ← Expired lease reclamation
        autoscaler_daemon.ex        ← Scale-out / scale-in logic
        node_registry.ex            ← Gossip load vector maintenance
        supervisor.ex               ← OTP supervision tree root

config/
    runtime.exs                     ← libcluster topology, SQS URLs, DynamoDB table names
```

---

_Person 2 doc — Infinity Node v1.0_
