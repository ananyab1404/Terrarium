defmodule Api.LiveDashboard.ClusterOverviewPage do
  @moduledoc """
  LiveDashboard custom page: Cluster Overview.

  Displays:
    - Active node count
    - Total available worker slots
    - Jobs/second (rolling 60-second average)
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Cluster Overview"}
  end

  @impl true
  def render_page(_assigns) do
    active_workers = get_active_workers()
    available_slots = get_available_slots()
    jobs_per_sec = get_jobs_per_second()

    table(
      columns: [
        %{field: :metric, header: "Metric", sortable: :asc},
        %{field: :value, header: "Value"}
      ],
      id: :cluster_overview,
      row_attrs: &row_attrs/1,
      row_fetcher: fn _params, _node ->
        rows = [
          %{metric: "Active Worker Nodes", value: active_workers},
          %{metric: "Available Worker Slots", value: available_slots},
          %{metric: "Jobs/second (60s avg)", value: Float.round(jobs_per_sec, 2)},
          %{metric: "Node", value: node() |> to_string()},
          %{metric: "Uptime", value: uptime_string()}
        ]

        {rows, length(rows)}
      end,
      title: "Cluster Overview"
    )
  end

  defp row_attrs(_row), do: []

  defp get_active_workers do
    try do
      Supervisor.which_children(Worker.WorkerPoolSupervisor) |> length()
    rescue
      _ -> 0
    end
  end

  defp get_available_slots do
    try do
      Worker.WorkerProcess.available_slots()
    rescue
      _ -> 0
    end
  end

  defp get_jobs_per_second do
    # Read from MetricsReporter if available
    try do
      case :sys.get_state(Api.Observability.MetricsReporter) do
        %{job_count: count, last_push: last} ->
          elapsed = max(System.monotonic_time(:second) - last, 1)
          count / elapsed

        _ ->
          0.0
      end
    rescue
      _ -> 0.0
    end
  end

  defp uptime_string do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    seconds = div(uptime_ms, 1000)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)

    cond do
      days > 0 -> "#{days}d #{rem(hours, 24)}h #{rem(minutes, 60)}m"
      hours > 0 -> "#{hours}h #{rem(minutes, 60)}m"
      true -> "#{minutes}m #{rem(seconds, 60)}s"
    end
  end
end
