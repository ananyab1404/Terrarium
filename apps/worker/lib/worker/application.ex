defmodule Worker.Application do
  use Application

  @impl true
  def start(_type, _args) do
    configured = Application.get_env(:worker, :pool_size, System.schedulers_online() - 1)
    pool_size = max(configured, 1)

    maybe_prefetch_snapshot()

    children = [
      {Registry, keys: :unique, name: Worker.Registry},
      {Worker.WorkerPoolSupervisor, pool_size: pool_size}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Worker.Supervisor)
  end

  defp maybe_prefetch_snapshot do
    if Application.get_env(:worker, :prefetch_snapshot_on_boot, true) do
      Task.start(fn ->
        _ = Worker.SnapshotManager.ensure_snapshot_assets()
      end)
    end
  end
end
