# Person 1 — Execution Engine

### Firecracker · Rust Jailer · VM Lifecycle · WorkerProcess

---

## Your Role in the System

You own everything that happens **inside and around a Firecracker microVM**. This is the most hardware-close, lowest-level work on the project. When a job gets dispatched to a worker node, your code is what actually runs it. Every other part of the system depends on your layer doing three things correctly:

- Accepting a job payload
- Running it in hardware-enforced isolation
- Returning stdout/stderr and an exit code, then wiping the VM

Person 2 (Scheduler) hands you a job message. You run it. You hand back the result. That's the contract.

---

## Your Part of the Architecture

```
WorkerProcess (GenServer)  ←── receives job message from DispatchCoordinator
    │
    ▼
Firecracker microVM
    ├── jailer binary (seccomp-BPF, cgroups v2, private network namespace)
    ├── read-only base filesystem (stripped Linux guest)
    ├── ephemeral tmpfs layer (per-execution writes, wiped after)
    ├── virtio-vsock channel
    │       ├── INBOUND: function artifact + input payload injection
    │       └── OUTBOUND: stdout/stderr streaming back to host
    └── VM snapshot
            ├── created once, stored in S3
            └── restored after every execution (eliminates cold start)
```

---

## Stack You're Working In

- **Rust** — jailer configuration, seccomp-BPF filter authoring, low-level memory limit enforcement
- **Elixir** — `WorkerProcess` GenServer, `WorkerPoolSupervisor`, vsock channel handling
- **Firecracker** — microVM hypervisor binary (AWS-maintained, you configure it)
- **Linux** — cgroups v2, network namespaces, KVM

---

## Phase-by-Phase Breakdown

### Phase 0 — Hardware Validation (Do This First, Before Anything Else)

**Goal:** Prove that Firecracker boots and executes on your target hardware.

This is not optional scaffolding — it is the proof-of-concept that unblocks the entire project. Nothing else you build matters until this works.

Steps:

1. Provision an `i3.metal` or `c5.metal` EC2 instance. Firecracker requires KVM. It will not run on virtualized instances.
2. Download the Firecracker binary from the official GitHub releases.
3. Follow the official getting-started guide to boot a minimal Alpine Linux guest manually.
4. Write a shell script inside the guest that echoes `hello world` to stdout.
5. Stream that stdout back to the host process.
6. Confirm the VM terminates cleanly.

If you hit issues here, surface them immediately — this is the highest-risk item on the project and the team needs to know early.

**Deliverable:** A Slack message (or equivalent) with a screenshot or log showing a function executing inside Firecracker and returning output. That's the green light.

---

### Phase 1 — VM Snapshot Pipeline

**Goal:** Eliminate cold start by pre-booting VMs and restoring snapshots per job.

Cold-booting a Firecracker VM takes ~125ms. Restoring from a memory snapshot takes ~5ms. The PRD's sub-50ms dispatch target is only achievable via snapshotting. This is how you build it:

1. **Build the base guest image** — a stripped read-only Linux root filesystem. Start with Alpine. Remove everything that isn't needed for function execution. The smaller the image, the faster the snapshot restore.

2. **Create the snapshot** — boot a clean VM, let the guest reach a stable idle state (init complete, runtime ready), then call the Firecracker snapshot API to dump memory + disk state to files.

3. **Store the snapshot in S3** — the snapshot is loaded by worker nodes at startup. Each node pulls it once and caches locally.

4. **Write the restore path** — on job completion (or VM force-termination), the `WorkerProcess` restores the clean snapshot into the slot. The slot is now ready for the next job.

5. **Test snapshot fidelity** — run 100 consecutive jobs through a single VM slot. Verify that each execution sees a clean guest state (no artifacts from previous jobs). This is a correctness requirement.

**Key risk:** Some guest kernel configurations don't support Firecracker's snapshot/restore cycle reliably. Test this before building anything on top of it. If it's unstable, fall back to cold-boot VMs and flag it — the latency target becomes aspirational, not guaranteed.

---

### Phase 2 — Jailer + Security Enforcement

**Goal:** Hardware-enforced isolation. The host has zero trust in guest code.

You're writing the Rust component that configures the jailer. The jailer is the security boundary between the guest and the host OS.

**seccomp-BPF filter:**

- Start permissive — allow all syscalls, run a real function workload, audit what gets called
- Iteratively remove syscalls that are never needed
- The final filter should be an explicit allowlist, not a denylist
- Test the filter by attempting blocked syscalls from guest code — they must return `EPERM` or `SIGSYS`, not succeed

**cgroups v2 constraints:**

- CPU shares: enforce the per-job CPU ceiling declared in the job envelope
- Memory limit: enforce the per-job memory ceiling; configure the OOM killer to terminate the guest (not the host) on breach
- Test memory enforcement by allocating past the ceiling inside the guest — the guest must be killed, the host must be unaffected

**Network namespace:**

- Private network namespace per VM — no outbound connectivity by default
- Test by attempting `curl` or a raw socket connect from guest code — it must fail
- Do not expose the host network stack to guest code under any circumstances

**Deliverable:** A test suite (can be a shell script) that verifies all three constraints hold under adversarial guest behavior.

---

### Phase 3 — WorkerProcess GenServer

**Goal:** The Elixir actor that owns one Firecracker VM slot end-to-end.

This is the Elixir side of your work. The `WorkerProcess` is a GenServer that:

1. Registers itself as available in `Registry` on startup
2. Receives a job message: `{:execute, job_envelope}`
3. Injects the function artifact and input payload into the guest via virtio-vsock
4. Streams stdout/stderr from guest back to host in real time (buffer to memory, flush to S3 on completion)
5. Enforces wall-clock timeout — if the job exceeds its declared timeout, force-terminate the VM
6. Returns a result envelope: `{:ok, result}` or `{:error, reason}` back to the caller
7. Restores the VM snapshot
8. Re-registers as available in `Registry`

**WorkerProcess state machine:**

```
:idle → :executing → :restoring → :idle
         ↓
       :timed_out (force-terminate VM, restore, back to :idle)
```

**WorkerPoolSupervisor:**

- Owns N `WorkerProcess` children with `:one_for_one` restart strategy
- A crashing `WorkerProcess` restarts without affecting siblings
- N is configurable via application config (default: match available CPU cores minus 1)

---

### Phase 4 — Vsock Channel Protocol

**Goal:** Reliable bidirectional communication between host and guest.

The virtio-vsock channel is how you get data into and out of the VM without a network interface. You need to define and implement a simple framing protocol:

**Host → Guest (injection):**

```
[4 bytes: artifact_size][artifact_bytes][4 bytes: payload_size][payload_bytes]
```

**Guest → Host (streaming):**

```
[1 byte: stream_type (0=stdout, 1=stderr)][4 bytes: chunk_size][chunk_bytes]
[1 byte: 0xFF (terminator)][4 bytes: exit_code]
```

Keep this simple. The protocol does not need to be clever — it needs to be correct and detectable-corrupt (if framing breaks, the WorkerProcess should detect it and force-terminate the VM rather than hanging).

**Test cases you must write:**

- Normal execution: artifact injected, stdout returned, exit 0
- Execution that writes to stderr: both streams captured separately
- Execution that exits non-zero: exit code propagated correctly
- Execution that hangs: wall-clock timeout fires, VM terminated, slot restored
- Execution that tries to write past memory limit: OOM kill, slot restored, error result returned

---

### Phase 5 — Load Validation

**Goal:** Your layer holds up under the load test conditions in the PRD.

Run this yourself before handing off to the integration test:

- Spin up a single worker node with a pool of 10 `WorkerProcess` slots
- Fire 100 concurrent jobs at it
- Measure: dispatch-to-execution-start latency (target: under 50ms), execution throughput (jobs/second), VM slot restore time
- Deliberately crash one `WorkerProcess` mid-execution — verify the supervisor restarts it and the other slots continue unaffected
- Deliberately inject a job that blows past the memory ceiling — verify the VM is killed and the slot recovers cleanly

---

## Handoff Contracts

### What you need from Person 2 (Scheduler):

- The job envelope schema — specifically the fields: artifact S3 reference, input payload, resource limits (CPU shares, memory ceiling, wall-clock timeout), and job ID
- Confirmation of the `Registry` key format for worker registration so the DispatchCoordinator can find available workers

### What you deliver to Person 2 (Scheduler):

- `WorkerProcess` module with its `{:execute, job_envelope}` message interface documented
- The result envelope schema: `{job_id, exit_code, stdout_s3_key, stderr_s3_key, wall_time_ms, peak_memory_bytes}`
- `WorkerPoolSupervisor` that Person 2's `WorkerPoolSupervisor` wraps

### What you deliver to Person 3 (API + Infra):

- S3 key convention for stdout/stderr log objects (Person 3 needs to know where to point the result retrieval API)
- The VM snapshot S3 key (Person 3 provisions the bucket, you define the object layout)

---

## Risk Register

| Risk                                                        | What to do                                                                                                                             |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Snapshot restore is unstable under repeated cycles          | Test 1000 restorations in a loop before building on top. If it fails, cold-boot VMs as fallback and flag the latency impact.           |
| seccomp filter blocks a syscall your function runtime needs | Start permissive, audit, tighten. Never start with a tight filter and debug from there.                                                |
| vsock channel hangs on malformed guest output               | Implement a read timeout on the host side. Any read that stalls for more than 500ms beyond the job timeout triggers a force-terminate. |
| Metal instance spot interruption during dev                 | Snapshot your dev environment to an AMI daily.                                                                                         |

---

## Key Files You'll Own

```
apps/worker/
    lib/
        worker_process.ex          ← GenServer for one VM slot
        worker_pool_supervisor.ex  ← Supervisor owning N slots
        vsock_channel.ex           ← Virtio-vsock framing protocol
        snapshot_manager.ex        ← Snapshot restore logic

rust/jailer/
    src/
        main.rs                    ← Jailer configuration entry point
        seccomp.rs                 ← BPF filter authoring
        cgroups.rs                 ← cgroups v2 resource enforcement

scripts/
    create_snapshot.sh             ← One-time snapshot creation script
    validate_isolation.sh          ← Test suite for security constraints
```

---

_Person 1 doc — Infinity Node v1.0_
