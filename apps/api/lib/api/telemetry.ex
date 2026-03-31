defmodule Api.Telemetry do
  @moduledoc """
  Telemetry metrics definitions for LiveDashboard and CloudWatch.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Metrics exposed to LiveDashboard."
  def metrics do
    [
      # Phoenix request metrics
      summary("api.request.stop.duration", unit: {:native, :millisecond}),
      counter("api.request.stop.duration"),

      # Worker execution metrics
      summary("worker.execution.complete.wall_time_ms"),
      summary("worker.execution.complete.peak_memory_bytes"),

      # Custom Infinity Node metrics
      last_value("infinity_node.cluster.active_workers"),
      last_value("infinity_node.cluster.available_slots"),
      last_value("infinity_node.queue.depth")
    ]
  end

  defp periodic_measurements do
    []
  end
end
