defmodule Worker.WorkerProcess do
  use GenServer

  require Logger

  @firecracker_bin "/usr/local/bin/firecracker"
  @jailer_bin "/usr/local/bin/jailer"
  @assets_dir Application.compile_env(:worker, :assets_dir, "/opt/infinity_node/firecracker/assets")

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

    result = run_execution(job_envelope, %{state | status: :executing})

    case Worker.SnapshotManager.restore_slot(state.slot_index) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Snapshot restore failed for slot #{state.slot_index}: #{inspect(reason)}")
    end

    Registry.register(Worker.Registry, state.slot_index, :available)

    final_state = %{state | status: :idle, vm_pid: nil}
    {:reply, result, final_state}
  end

  def handle_call({:execute, _job}, _from, state) do
    {:reply, {:error, :worker_busy}, state}
  end

  # Execution internals

  defp run_execution(job, state) do
    start_time = System.monotonic_time(:millisecond)
    limits = Map.get(job, :resource_limits, %{})

    with {:ok, _vm_port} <- boot_vm(state.slot_index, state.socket_path, state.vsock_path, limits),
         :ok <- Worker.VsockChannel.inject(state.vsock_path, job),
         {:ok, result} <- Worker.VsockChannel.collect(state.vsock_path, timeout_ms(job)) do
      wall_time = System.monotonic_time(:millisecond) - start_time

      stdout_key = "logs/#{job_id(job)}/stdout"
      stderr_key = "logs/#{job_id(job)}/stderr"

      :ok = upload_log(stdout_key, result.stdout)
      :ok = upload_log(stderr_key, result.stderr)

      :telemetry.execute(
        [:worker, :execution, :complete],
        %{wall_time_ms: wall_time, peak_memory_bytes: result.peak_memory_bytes},
        %{job_id: job_id(job), slot_index: state.slot_index, exit_code: result.exit_code}
      )

      {:ok,
       %{
         job_id: job_id(job),
         exit_code: result.exit_code,
         stdout_s3_key: stdout_key,
         stderr_s3_key: stderr_key,
         wall_time_ms: wall_time,
         peak_memory_bytes: result.peak_memory_bytes
       }}
    else
      {:error, :timeout} ->
        kill_vm(state.socket_path)
        {:error, :timeout}

      {:error, reason} ->
        kill_vm(state.socket_path)
        {:error, reason}
    end
  end

  defp boot_vm(slot_index, socket, vsock, resource_limits) do
    File.rm(socket)

    config_path = Path.join(System.tmp_dir!(), "fc-config-#{slot_index}.json")
    config = build_vm_config(slot_index, vsock, resource_limits)
    File.write!(config_path, Jason.encode!(config))

    _ = @jailer_bin

    port =
      Port.open({:spawn_executable, @firecracker_bin}, [
        :binary,
        :exit_status,
        args: ["--api-sock", socket, "--config-file", config_path]
      ])

    case wait_for_socket(socket, 20) do
      :ok -> {:ok, port}
      :error -> {:error, :vm_boot_failed}
    end
  end

  defp wait_for_socket(_path, 0), do: :error

  defp wait_for_socket(path, retries) do
    if File.exists?(path) do
      :ok
    else
      Process.sleep(100)
      wait_for_socket(path, retries - 1)
    end
  end

  defp build_vm_config(slot_index, vsock, limits) do
    %{
      "boot-source" => %{
        "kernel_image_path" => Path.join(@assets_dir, "vmlinux"),
        "boot_args" => "console=ttyS0 reboot=k panic=1 pci=off"
      },
      "drives" => [
        %{
          "drive_id" => "rootfs",
          "path_on_host" => Path.join(@assets_dir, "rootfs-slot-#{slot_index}.ext4"),
          "is_root_device" => true,
          "is_read_only" => false
        }
      ],
      "machine-config" => %{
        "vcpu_count" => 1,
        "mem_size_mib" => memory_mb(limits)
      },
      "vsock" => %{
        "guest_cid" => 3 + slot_index,
        "uds_path" => vsock
      }
    }
  end

  defp kill_vm(socket) do
    _ =
      System.cmd("curl", [
        "--silent",
        "--show-error",
        "--unix-socket",
        socket,
        "-X",
        "PUT",
        "http://localhost/actions",
        "-H",
        "Content-Type: application/json",
        "-d",
        ~s({"action_type":"SendCtrlAltDel"})
      ])

    File.rm(socket)
  end

  defp upload_log(s3_key, content) do
    bucket = Application.get_env(:worker, :logs_bucket, System.get_env("LOGS_BUCKET", "infinity-node-logs"))

    case ExAws.S3.put_object(bucket, s3_key, content) |> ExAws.request() do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("log upload failed for #{s3_key}: #{inspect(reason)}")
        :ok
    end
  end

  defp memory_mb(%{memory_mb: val}) when is_integer(val) and val > 0, do: val
  defp memory_mb(_), do: 128

  defp timeout_ms(%{resource_limits: %{timeout_ms: val}}) when is_integer(val) and val > 0, do: val
  defp timeout_ms(_), do: 30_000

  defp job_id(%{job_id: id}) when is_binary(id), do: id
  defp job_id(_), do: "job-unknown"

  defp socket_path(slot_index), do: "/tmp/fc-slot-#{slot_index}.socket"
  defp vsock_path(slot_index), do: "/tmp/fc-vsock-#{slot_index}.socket"
  defp via(slot_index), do: {:via, Registry, {Worker.Registry, slot_index}}
end
