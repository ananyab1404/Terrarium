defmodule Api.LiveDashboard.LatencyPage do
  @moduledoc """
  LiveDashboard custom page: Latency.

  Displays P50, P95, P99 execution latency from the MetricsReporter's
  in-memory latency buffer (rolling window).
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Latency"}
  end

  @impl true
  def render_page(_assigns) do
    {p50, p95, p99} = get_latency_percentiles()
    sample_count = get_sample_count()

    table(
      columns: [
        %{field: :percentile, header: "Percentile", sortable: :asc},
        %{field: :latency_ms, header: "Latency (ms)"},
        %{field: :status, header: "Status"}
      ],
      id: :latency_stats,
      row_attrs: &row_attrs/1,
      row_fetcher: fn _params, _node ->
        rows = [
          %{percentile: "P50 (Median)", latency_ms: p50, status: latency_status(p50, 100)},
          %{percentile: "P95", latency_ms: p95, status: latency_status(p95, 300)},
          %{percentile: "P99", latency_ms: p99, status: latency_status(p99, 500)},
          %{percentile: "Samples", latency_ms: sample_count, status: "—"}
        ]

        {rows, length(rows)}
      end,
      title: "Execution Latency"
    )
  end

  defp row_attrs(_row), do: []

  defp get_latency_percentiles do
    try do
      case :sys.get_state(Api.Observability.MetricsReporter) do
        %{latencies: latencies} when is_list(latencies) and length(latencies) > 0 ->
          sorted = Enum.sort(latencies)
          len = length(sorted)
          p50 = Enum.at(sorted, floor(len * 0.50))
          p95 = Enum.at(sorted, min(floor(len * 0.95), len - 1))
          p99 = Enum.at(sorted, min(floor(len * 0.99), len - 1))
          {p50, p95, p99}

        _ ->
          {0, 0, 0}
      end
    rescue
      _ -> {0, 0, 0}
    end
  end

  defp get_sample_count do
    try do
      case :sys.get_state(Api.Observability.MetricsReporter) do
        %{latencies: latencies} -> length(latencies)
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp latency_status(ms, threshold) when ms <= threshold, do: "✅ OK"
  defp latency_status(ms, threshold) when ms <= threshold * 2, do: "⚠️ Warning"
  defp latency_status(_ms, _threshold), do: "🔴 High"
end
