defmodule Worker.FirecrackerVM do
  @moduledoc false

  require Logger

  @firecracker_bin Application.compile_env(:worker, :firecracker_bin, "/usr/local/bin/firecracker")
  @infinity_jailer_bin Application.compile_env(:worker, :infinity_jailer_bin, "/usr/local/bin/infinity-jailer")
  @assets_dir Application.compile_env(:worker, :assets_dir, "/opt/infinity_node/firecracker/assets")

  def boot(slot_index, socket_path, vsock_path, limits) do
    File.rm(socket_path)
    File.rm(vsock_path)

    if snapshot_boot_enabled?() do
      case boot_from_snapshot(socket_path) do
        {:ok, port} ->
          {:ok, port}

        {:error, reason} ->
          Logger.warning("snapshot restore boot failed, falling back to cold boot: #{inspect(reason)}")
          cold_boot(slot_index, socket_path, vsock_path, limits)
      end
    else
      cold_boot(slot_index, socket_path, vsock_path, limits)
    end
  end

  def kill(socket_path) do
    _ =
      System.cmd("curl", [
        "--silent",
        "--show-error",
        "--unix-socket",
        socket_path,
        "-X",
        "PUT",
        "http://localhost/actions",
        "-H",
        "Content-Type: application/json",
        "-d",
        ~s({"action_type":"SendCtrlAltDel"})
      ])

    File.rm(socket_path)
    :ok
  end

  defp snapshot_boot_enabled? do
    Application.get_env(:worker, :snapshot_boot_enabled, true)
  end

  defp use_jailer? do
    Application.get_env(:worker, :use_jailer, false)
  end

  defp run_uid do
    Application.get_env(:worker, :jailer_uid, 1000)
  end

  defp run_gid do
    Application.get_env(:worker, :jailer_gid, 1000)
  end

  defp boot_from_snapshot(socket_path) do
    paths = Worker.SnapshotManager.snapshot_paths()

    with :ok <- ensure_exists(paths.snapshot),
         :ok <- ensure_exists(paths.memory),
         {:ok, port} <- start_firecracker(socket_path, nil),
         :ok <- wait_for_socket(socket_path, 20),
         :ok <-
           api_put(socket_path, "snapshot/load", %{
             "snapshot_path" => paths.snapshot,
             "mem_backend" => %{
               "backend_type" => "File",
               "backend_path" => paths.memory
             },
             "enable_diff_snapshots" => false,
             "resume_vm" => true
           }) do
      {:ok, port}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp cold_boot(slot_index, socket_path, vsock_path, limits) do
    config_path = Path.join(System.tmp_dir!(), "fc-config-#{slot_index}.json")

    config = %{
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
        "vcpu_count" => cpu_count(limits),
        "mem_size_mib" => memory_mb(limits)
      },
      "vsock" => %{
        "guest_cid" => 3 + slot_index,
        "uds_path" => vsock_path
      }
    }

    File.write!(config_path, Jason.encode!(config))

    with {:ok, port} <- start_cold_vm(slot_index, socket_path, config_path, limits),
         :ok <- wait_for_socket(socket_path, 20) do
      {:ok, port}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_cold_vm(slot_index, socket_path, config_path, limits) do
    if use_jailer?() and File.exists?(@infinity_jailer_bin) do
      port =
        Port.open({:spawn_executable, @infinity_jailer_bin}, [
          :binary,
          :exit_status,
          args: [
            "--firecracker",
            @firecracker_bin,
            "--api-sock",
            socket_path,
            "--config-file",
            config_path,
            "--cgroup-name",
            "slot-#{slot_index}",
            "--memory-limit-bytes",
            Integer.to_string(memory_limit_bytes(limits)),
            "--cpu-shares",
            Integer.to_string(cpu_shares(limits)),
            "--uid",
            Integer.to_string(run_uid()),
            "--gid",
            Integer.to_string(run_gid())
          ]
        ])

      {:ok, port}
    else
      start_firecracker(socket_path, config_path)
    end
  end

  defp start_firecracker(socket_path, nil) do
    port =
      Port.open({:spawn_executable, @firecracker_bin}, [
        :binary,
        :exit_status,
        args: ["--api-sock", socket_path]
      ])

    {:ok, port}
  end

  defp start_firecracker(socket_path, config_path) do
    port =
      Port.open({:spawn_executable, @firecracker_bin}, [
        :binary,
        :exit_status,
        args: ["--api-sock", socket_path, "--config-file", config_path]
      ])

    {:ok, port}
  end

  defp api_put(socket_path, endpoint, payload) do
    {_, status} =
      System.cmd("curl", [
        "--silent",
        "--show-error",
        "--fail",
        "--unix-socket",
        socket_path,
        "-X",
        "PUT",
        "http://localhost/#{endpoint}",
        "-H",
        "Accept: application/json",
        "-H",
        "Content-Type: application/json",
        "-d",
        Jason.encode!(payload)
      ])

    if status == 0, do: :ok, else: {:error, {:firecracker_api_failed, endpoint, status}}
  end

  defp wait_for_socket(_path, 0), do: {:error, :vm_boot_failed}

  defp wait_for_socket(path, retries) do
    if File.exists?(path) do
      :ok
    else
      Process.sleep(100)
      wait_for_socket(path, retries - 1)
    end
  end

  defp ensure_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, {:missing_file, path}}
  end

  defp cpu_count(%{cpu_shares: shares}) when is_integer(shares) and shares >= 2048, do: 2
  defp cpu_count(%{"cpu_shares" => shares}) when is_integer(shares) and shares >= 2048, do: 2
  defp cpu_count(_), do: 1

  defp cpu_shares(%{cpu_shares: shares}) when is_integer(shares) and shares > 0, do: shares
  defp cpu_shares(%{"cpu_shares" => shares}) when is_integer(shares) and shares > 0, do: shares
  defp cpu_shares(_), do: 1024

  defp memory_mb(%{memory_mb: value}) when is_integer(value) and value > 0, do: value
  defp memory_mb(%{"memory_mb" => value}) when is_integer(value) and value > 0, do: value
  defp memory_mb(_), do: 128

  defp memory_limit_bytes(limits), do: memory_mb(limits) * 1_048_576
end
