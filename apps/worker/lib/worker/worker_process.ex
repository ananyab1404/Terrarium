defmodule Worker.WorkerProcess do
  use GenServer

  require Logger

  @default_timeout_ms 30_000

  # Public API

  def start_link(opts) do
    slot_index = Keyword.fetch!(opts, :slot_index)
    GenServer.start_link(__MODULE__, opts, name: via(slot_index))
  end

  def execute(slot_index, job_envelope) do
    timeout_ms = timeout_ms(job_envelope)
    GenServer.call(via(slot_index), {:execute, job_envelope}, timeout_ms + 5_000)
  end

  def available_slots do
    Registry.select(Worker.Registry, [{{:"$1", :_, :available}, [], [:"$1"]}])
    |> length()
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    slot_index = Keyword.fetch!(opts, :slot_index)

    state = %{
      slot_index: slot_index,
      status: :idle,
      vm_pid: nil,
      socket_path: socket_path(slot_index),
      vsock_path: vsock_path(slot_index)
    }

    Registry.register(Worker.Registry, slot_index, :available)

    Logger.info("WorkerProcess slot #{slot_index} initialized and available")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, job_envelope}, _from, %{status: :idle} = state) do
    Registry.unregister(Worker.Registry, state.slot_index)

    exec_state = %{state | status: :executing}
    result = run_execution(job_envelope, exec_state)
    final_state = restore_and_mark_available(%{state | status: :restoring})

    {:reply, result, final_state}
  end

  def handle_call({:execute, _job}, _from, state) do
    {:reply, {:error, :worker_busy}, state}
  end

  # Execution internals

  defp run_execution(job, state) do
    start_time = System.monotonic_time(:millisecond)
    limits = Map.get(job, :resource_limits, %{})
    timeout = timeout_ms(job)

    with {:ok, _vm_ref} <- vm_driver().boot(state.slot_index, state.socket_path, state.vsock_path, limits) do
      result =
        with :ok <- vsock_module().inject(state.vsock_path, job),
             {:ok, vm_result} <- vsock_module().collect(state.vsock_path, timeout + 500) do
          {:ok, vm_result}
        end

      _ = vm_driver().kill(state.socket_path)

      case result do
        {:ok, vm_result} ->
          wall_time = System.monotonic_time(:millisecond) - start_time
          build_success_result(job, state.slot_index, vm_result, wall_time)

        {:error, :timeout} ->
          {:error, :timeout}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_success_result(job, slot_index, vm_result, wall_time) do
    stdout_key = "logs/#{job_id(job)}/stdout"
    stderr_key = "logs/#{job_id(job)}/stderr"

    :ok = log_store().put(stdout_key, vm_result.stdout)
    :ok = log_store().put(stderr_key, vm_result.stderr)

    :telemetry.execute(
      [:worker, :execution, :complete],
      %{wall_time_ms: wall_time, peak_memory_bytes: vm_result.peak_memory_bytes},
      %{job_id: job_id(job), slot_index: slot_index, exit_code: vm_result.exit_code}
    )

    {:ok,
     %{
       job_id: job_id(job),
       exit_code: vm_result.exit_code,
       stdout_s3_key: stdout_key,
       stderr_s3_key: stderr_key,
       wall_time_ms: wall_time,
       peak_memory_bytes: vm_result.peak_memory_bytes
     }}
  end

  defp restore_and_mark_available(state) do
    case snapshot_module().restore_slot(state.slot_index) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Snapshot restore failed for slot #{state.slot_index}: #{inspect(reason)}")
    end

    Registry.register(Worker.Registry, state.slot_index, :available)
    %{state | status: :idle, vm_pid: nil}
  end

  defp vm_driver, do: Application.get_env(:worker, :vm_driver, Worker.FirecrackerVM)
  defp snapshot_module, do: Application.get_env(:worker, :snapshot_module, Worker.SnapshotManager)
  defp vsock_module, do: Application.get_env(:worker, :vsock_module, Worker.VsockChannel)
  defp log_store, do: Application.get_env(:worker, :log_store_module, Worker.LogStore)

  defp timeout_ms(%{resource_limits: %{timeout_ms: val}}) when is_integer(val) and val > 0, do: val
  defp timeout_ms(%{"resource_limits" => %{"timeout_ms" => val}}) when is_integer(val) and val > 0, do: val
  defp timeout_ms(_), do: @default_timeout_ms

  defp job_id(%{job_id: id}) when is_binary(id), do: id
  defp job_id(%{"job_id" => id}) when is_binary(id), do: id
  defp job_id(_), do: "job-unknown"

  defp socket_path(slot_index), do: "/tmp/fc-slot-#{slot_index}.socket"
  defp vsock_path(slot_index), do: "/tmp/fc-vsock-#{slot_index}.socket"
  defp via(slot_index), do: {:via, Registry, {Worker.Registry, slot_index}}
end
