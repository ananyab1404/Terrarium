defmodule Scheduler.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    enabled = Application.get_env(:scheduler, :enable_runtime_processes, true)

    children =
      if enabled do
        [
          {Scheduler.NodeRegistry, []},
          {Scheduler.DispatchCoordinator, []},
          {Scheduler.SQSConsumer, []},
          {Scheduler.LeaseReaper, []},
          {Scheduler.AutoscalerDaemon, []}
        ]
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
