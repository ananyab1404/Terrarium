# Worker App Contract

This app owns one Firecracker-backed execution slot per WorkerProcess.

## Execute Interface

Call:

```elixir
Worker.WorkerProcess.execute(slot_index, job_envelope)
```

Expected job envelope fields:

- `job_id` (string)
- `artifact_s3_key` or `artifact_bytes` or `artifact_path`
- `input_payload` (map or JSON string)
- `resource_limits.cpu_shares` (integer)
- `resource_limits.memory_mb` (integer)
- `resource_limits.timeout_ms` (integer)

## Result Envelope

Success:

```elixir
{:ok,
 %{
   job_id: binary(),
   exit_code: non_neg_integer(),
   stdout_s3_key: binary(),
   stderr_s3_key: binary(),
   wall_time_ms: non_neg_integer(),
   peak_memory_bytes: non_neg_integer()
 }}
```

Failure:

```elixir
{:error, reason}
```

Common reasons:

- `:worker_busy`
- `:timeout`
- `:vm_boot_failed`
- `{:connect_failed, term()}`
- `{:artifact_download_failed, term()}`

## Worker Availability Registry

Available slots are registered in `Worker.Registry` with key = slot index and value = `:available`.

Scheduler side can query available capacity by calling:

```elixir
Worker.WorkerProcess.available_slots()
```
