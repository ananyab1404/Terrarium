defmodule Worker.SnapshotManager do
  @moduledoc false

  require Logger

  @assets_dir Application.compile_env(:worker, :assets_dir, "/opt/infinity_node/firecracker/assets")

  def ensure_snapshot_assets do
    paths = snapshot_paths()

    if File.exists?(paths.snapshot) and File.exists?(paths.memory) do
      :ok
    else
      download_snapshot(paths)
    end
  end

  def restore_slot(slot_index) do
    base = Path.join(@assets_dir, "rootfs-base.ext4")
    slot = Path.join(@assets_dir, "rootfs-slot-#{slot_index}.ext4")

    with :ok <- ensure_exists(base),
         :ok <- File.copy(base, slot) do
      :ok
    end
  end

  def snapshot_paths do
    snapshot_dir = Path.join(@assets_dir, "snapshots")

    %{
      dir: snapshot_dir,
      snapshot: Path.join(snapshot_dir, "vm.snap"),
      memory: Path.join(snapshot_dir, "vm.mem")
    }
  end

  defp download_snapshot(paths) do
    prefix = Application.get_env(:worker, :snapshot_s3_prefix, "snapshots/default")
    bucket = Application.get_env(:worker, :artifacts_bucket, System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts"))

    File.mkdir_p!(paths.dir)

    with {:ok, snapshot_data} <- fetch_object(bucket, "#{prefix}/vm.snap"),
         {:ok, memory_data} <- fetch_object(bucket, "#{prefix}/vm.mem"),
         :ok <- File.write(paths.snapshot, snapshot_data),
         :ok <- File.write(paths.memory, memory_data) do
      Logger.info("snapshot assets cached from s3://#{bucket}/#{prefix}")
      :ok
    else
      {:error, reason} ->
        Logger.warning("snapshot prefetch skipped: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_object(bucket, key) do
    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{body: body}} -> {:ok, IO.iodata_to_binary(body)}
      {:error, reason} -> {:error, {:s3_get_failed, key, reason}}
    end
  end

  defp ensure_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, {:missing_file, path}}
  end
end
