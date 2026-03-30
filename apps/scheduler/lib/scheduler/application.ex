defmodule Scheduler.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Scheduler.Supervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Scheduler.ApplicationSupervisor)
  end
end
