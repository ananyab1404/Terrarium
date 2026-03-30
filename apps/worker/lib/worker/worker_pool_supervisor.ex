defmodule Worker.WorkerPoolSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    pool_size = max(Keyword.get(opts, :pool_size, 4), 1)

    children =
      for slot_index <- 0..(pool_size - 1) do
        Supervisor.child_spec(
          {Worker.WorkerProcess, slot_index: slot_index},
          id: {Worker.WorkerProcess, slot_index}
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
