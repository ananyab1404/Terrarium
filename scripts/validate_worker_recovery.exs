Mix.Task.run("app.start")

slot = System.get_env("SLOT_INDEX", "0") |> String.to_integer()

[{pid, _}] = Registry.lookup(Worker.Registry, slot)
IO.puts("Current pid for slot #{slot}: #{inspect(pid)}")

Process.exit(pid, :kill)
Process.sleep(300)

case Registry.lookup(Worker.Registry, slot) do
  [{new_pid, _}] when new_pid != pid ->
    IO.puts("Recovery passed. New pid: #{inspect(new_pid)}")
    System.halt(0)

  [{same_pid, _}] ->
    IO.puts("Recovery failed. PID did not change: #{inspect(same_pid)}")
    System.halt(1)

  [] ->
    IO.puts("Recovery failed. Slot not registered after crash.")
    System.halt(1)
end
