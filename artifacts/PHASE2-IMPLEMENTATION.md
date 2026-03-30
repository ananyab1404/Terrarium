# Phase 2+ Scheduler Responsibilities — Implementation Status

This document records implementation of Person 2 responsibilities that were pending after Phase 1.

## Completed Responsibilities

1. **SQS consumer with backpressure**
   - Implemented in `apps/scheduler/lib/scheduler/sqs_consumer.ex`
   - Poll loop pauses when `available_slots == 0`
   - Deletes queue message only after successful dispatch result

2. **Dispatch to workers with guarded state transitions**
   - Implemented in `apps/scheduler/lib/scheduler/dispatch_coordinator.ex`
   - Transition flow: `SCHEDULED -> DISPATCHED -> RUNNING -> TERMINAL`
   - Uses `Scheduler.JobStore` methods for atomic semantics

3. **Lease reaper for expired in-flight jobs**
   - Implemented in `apps/scheduler/lib/scheduler/lease_reaper.ex`
   - Scans for expired RUNNING leases
   - Requeues under retry budget

4. **Dead-letter routing on exhausted retries**
   - Implemented in `apps/scheduler/lib/scheduler/lease_reaper.ex`
   - Uses `JobStore.force_terminal_deadletter/3`
   - Persists dead-letter record through `Scheduler.DeadLetterStore`

5. **Autoscaler hysteresis daemon**
   - Implemented in `apps/scheduler/lib/scheduler/autoscaler_daemon.ex`
   - Scale-out: 2 consecutive high-pressure polls
   - Scale-in: 5 consecutive low-pressure polls

6. **Node load registry**
   - Implemented in `apps/scheduler/lib/scheduler/node_registry.ex`
   - Tracks load vectors and ignores stale nodes

7. **Runtime supervision tree wiring**
   - Implemented in `apps/scheduler/lib/scheduler/supervisor.ex`
   - Started by `apps/scheduler/lib/scheduler/application.ex`

## Integration Boundaries (explicit placeholders)

- Queue boundary: `Scheduler.QueueClient` (`Noop` implementation included)
- Worker boundary: `Scheduler.WorkerGateway` (`Default` delegates to `Worker.WorkerProcess`)
- Autoscaler boundary: `Scheduler.AutoscalerClient` (`Noop` implementation included)
- Dead-letter boundary: `Scheduler.DeadLetterStore` (`Noop` implementation included)

These boundaries are intentionally decoupled so other project owners can plug AWS/infra specifics without changing scheduler core logic.

## New/Updated Tests

- `apps/scheduler/test/scheduler/dispatch_coordinator_test.exs`
- `apps/scheduler/test/scheduler/sqs_consumer_test.exs`
- `apps/scheduler/test/scheduler/lease_reaper_test.exs`
- `apps/scheduler/test/scheduler/autoscaler_daemon_test.exs`
- Existing phase-1 tests retained: `apps/scheduler/test/scheduler/job_store_phase_1_test.exs`

## Notes

- Production ExAws-backed implementations remain in integration placeholder modules.
- Core scheduler logic is now test-covered with deterministic in-memory adapters.
