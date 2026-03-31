# Integration & Architecture Revision
### Final Leftover Tasks & Mapping Gaps (Backend)

After reviewing `Context.md`, `person-1.md`, `person-2.md`, and `person-3.md`, the core architecture is highly robust. The boundaries between the Phoenix API (P3), Scheduler/State Machine (P2), and Execution Engine (P1) are well-defined.

However, cross-checking the exact handoff points reveals **6 architectural gaps and integration missing links** that must be resolved to completely connect the system.

---

## 1. The Auto-Scaling Loop Gap
**The Gap:** Person 2's `AutoscalerDaemon` is supposed to scale out the ECS cluster by calling the AWS Auto Scaling API (`SetDesiredCapacity`). However, Person 3's infrastructure deliverables do not explicitly export the **Auto Scaling Group (ASG) Name**. Furthermore, during scale-in, Person 2 sends a `:drain` message to a node, but the node just terminating its Elixir process will cause ECS to simply restart the container.
**Leftover Tasks:**
- **Person 3:** Export the Worker ASG Name in Terraform `outputs.tf` and map it to `config/runtime.exs`.
- **Person 2:** Update `AutoscalerDaemon` to read the ASG name from config.
- **Person 2:** On scale-in (drain), instead of just shutting down the Elixir app, the node must hit the AWS Auto Scaling API `TerminateInstanceInAutoScalingGroup` with its own EC2 instance ID (fetched via ECS metadata endpoint) to permanently remove the hardware.

## 2. Artifact Download & Local Caching Pipeline
**The Gap:** Person 1 states they inject the function artifact via `virtio-vsock`. However, the artifact originates in S3 (uploaded by the user via Person 3's presigned URL). The `JobEnvelope` contains `artifact_s3_key`. The step where the worker node physically downloads this artifact from S3 to the host machine before injection is implicitly handled but not formally defined.
**Leftover Tasks:**
- **Person 1:** Implement an S3 download step in `WorkerProcess` prior to `vsock` injection.
- **Person 1:** Implement a local LRU cache (e.g., in `/tmp/artifacts/`) so if a function executes 5 times concurrently or sequentially on the same node, it is only downloaded from S3 once.
- **Person 3:** Ensure the Worker ECS Task Role explicitly grants `s3:GetObject` on `infinity-node-artifacts`.

## 3. Cross-Node RPC Handoff
**The Gap:** Person 2's `DispatchCoordinator` maintains a consistent-hash ring to route jobs to the least-loaded node. It receives an SQS job and selects a remote `node_id`. But the exact mechanism of passing the `JobEnvelope` from the Coordinator node to the Worker node's `WorkerPoolSupervisor` is undefined.
**Leftover Tasks:**
- **Person 2 & 1:** Define the exact Erlang RPC call. Example: The `DispatchCoordinator` uses `GenServer.call({Worker.Gateway, remote_node}, {:dispatch, envelope})`. Person 1 needs to expose a `Gateway` GenServer that catches remote traffic and routes it to an available local `WorkerProcess` slot.

## 4. Telemetry Metric Calculation
**The Gap:** Person 1 emits the `[:infinity_node, :worker, :execution, :complete]` telemetry event, which Person 3 expects to contain `queue_wait_ms`. Person 1's executing VM doesn't naturally know how long the job sat in SQS.
**Leftover Tasks:**
- **Person 1:** When calculating the telemetry map in `WorkerProcess`, ensure `queue_wait_ms` is explicitly calculated as: `System.system_time(:millisecond) - DateTime.to_unix(JobEnvelope.enqueued_at, :millisecond)`.

## 5. VM Snapshot Bootstrapping
**The Gap:** Person 1 states they create the Firecracker base VM snapshot once and store it in S3, and that each node "pulls it once and caches locally". But who pulls it?
**Leftover Tasks:**
- **Person 3:** Add an ECS `User Data` script (or a sidecar init-container) in Terraform that physically downloads the baseline snapshot from S3 into the EC2 instance's EBS volume/tmpfs *before* the Elixir Worker application boots. If the Elixir app boots before the snapshot is downloaded, the `WorkerProcess` will crash trying to restore a missing file.

## 6. SQS Job Deletion Edge Case (Idempotency)
**The Gap:** Person 2's `SQSConsumer` deletes the SQS message only when the job is successfully transitioned to `DISPATCHED` in DynamoDB. But what if the DynamoDB conditional write fails because of an idempotency conflict (e.g. the job is already `PENDING` but another worker picked it up)?
**Leftover Tasks:**
- **Person 2:** Ensure the `SQSConsumer` safely deletes the SQS message if `JobStore.transition/3` returns `{:error, :already_claimed}`. Otherwise, the message will hit visibility timeout and infinitely loop until it hits the DLQ.

---

### Final Integration Checklist

- [ ] (P3) Export ASG name from Terraform, add to `runtime.exs`.
- [ ] (P3) Add ECS Init-Container/User Data to download VM snapshot from S3 at boot.
- [ ] (P1) Implement S3 artifact downloader & cache inside `WorkerProcess`.
- [ ] (P1) Calculate `queue_wait_ms` using `enqueued_at` for the Telemetry envelope.
- [ ] (P2) Expose a clear inter-node RPC gateway so `DispatchCoordinator` can pass envelopes to assigned nodes.
- [ ] (P2) Update `AutoscalerDaemon` drain logic to trigger actual AWS auto-scaling group instance termination.
- [ ] (P2) Delete SQS messages instantly on `:already_claimed` DDB state transition failures.
