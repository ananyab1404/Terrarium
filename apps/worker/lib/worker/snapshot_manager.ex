defmodule Worker.SnapshotManager do
  @moduledoc false

  @assets_dir Application.compile_env(:worker, :assets_dir, "/opt/infinity_node/firecracker/assets")

  def restore_slot(slot_index) do
    base = Path.join(@assets_dir, "rootfs-base.ext4")
    slot = Path.join(@assets_dir, "rootfs-slot-#{slot_index}.ext4")

    with :ok <- ensure_exists(base),
         :ok <- File.copy(base, slot) do
      :ok
    end
  end

  defp ensure_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, {:missing_file, path}}
  end
end
