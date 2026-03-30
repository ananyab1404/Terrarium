Mix.Task.run("app.start")

iterations =
  System.get_env("ITERATIONS", "100")
  |> String.to_integer()

slot_index =
  System.get_env("SLOT_INDEX", "0")
  |> String.to_integer()

IO.puts("Running snapshot fidelity validation: #{iterations} iterations on slot #{slot_index}")

results =
  Enum.map(1..iterations, fn idx ->
    job = %{
      job_id: "snapshot-fidelity-#{idx}",
      artifact_bytes: "echo hello",
      input_payload: %{"iteration" => idx},
      resource_limits: %{cpu_shares: 1024, memory_mb: 128, timeout_ms: 5_000}
    }

    started = System.monotonic_time(:millisecond)
    result = Worker.WorkerProcess.execute(slot_index, job)
    duration = System.monotonic_time(:millisecond) - started

    {idx, result, duration}
  end)

failures =
  Enum.filter(results, fn {_idx, result, _duration} ->
    not match?({:ok, _}, result)
  end)

latencies = Enum.map(results, fn {_idx, _result, duration} -> duration end)
avg = Enum.sum(latencies) / max(length(latencies), 1)
max_latency = Enum.max(latencies, fn -> 0 end)

IO.puts("Average wall time: #{Float.round(avg, 2)} ms")
IO.puts("Max wall time: #{max_latency} ms")

if failures == [] do
  IO.puts("Snapshot fidelity validation passed")
  System.halt(0)
else
  IO.puts("Snapshot fidelity validation failed")
  Enum.each(failures, fn {idx, result, duration} ->
    IO.puts("  iteration #{idx} failed after #{duration}ms: #{inspect(result)}")
  end)

  System.halt(1)
end
