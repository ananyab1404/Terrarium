Mix.Task.run("app.start")

jobs = System.get_env("JOBS", "100") |> String.to_integer()
concurrency = System.get_env("CONCURRENCY", "10") |> String.to_integer()

pool_size = Application.get_env(:worker, :pool_size, 4)

IO.puts("Starting load validation with #{jobs} jobs, concurrency=#{concurrency}, pool_size=#{pool_size}")

started_all = System.monotonic_time(:millisecond)

results =
  1..jobs
  |> Task.async_stream(
    fn idx ->
      slot = rem(idx, max(pool_size, 1))

      job = %{
        job_id: "load-#{idx}",
        artifact_bytes: "echo load",
        input_payload: %{"idx" => idx},
        resource_limits: %{cpu_shares: 1024, memory_mb: 128, timeout_ms: 10_000}
      }

      started = System.monotonic_time(:millisecond)
      result = Worker.WorkerProcess.execute(slot, job)
      latency = System.monotonic_time(:millisecond) - started

      {result, latency}
    end,
    max_concurrency: concurrency,
    ordered: false,
    timeout: 20_000
  )
  |> Enum.to_list()

durations =
  Enum.map(results, fn
    {:ok, {_result, latency}} -> latency
    {:exit, _} -> 20_000
  end)

ok_count =
  Enum.count(results, fn
    {:ok, {{:ok, _}, _latency}} -> true
    _ -> false
  end)

error_count = jobs - ok_count

total_ms = System.monotonic_time(:millisecond) - started_all
throughput = if total_ms > 0, do: jobs * 1000 / total_ms, else: 0.0

sorted = Enum.sort(durations)
p50 = Enum.at(sorted, div(length(sorted) * 50, 100), 0)
p95 = Enum.at(sorted, div(length(sorted) * 95, 100), 0)
p99 = Enum.at(sorted, div(length(sorted) * 99, 100), 0)

summary = %{
  jobs: jobs,
  concurrency: concurrency,
  ok: ok_count,
  errors: error_count,
  total_ms: total_ms,
  throughput_jobs_per_sec: Float.round(throughput, 2),
  p50_ms: p50,
  p95_ms: p95,
  p99_ms: p99
}

IO.puts(Jason.encode!(summary, pretty: true))

if error_count == 0 do
  System.halt(0)
else
  System.halt(1)
end
