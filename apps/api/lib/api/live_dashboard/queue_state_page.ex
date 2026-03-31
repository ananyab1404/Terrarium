defmodule Api.LiveDashboard.QueueStatePage do
  @moduledoc """
  LiveDashboard custom page: Queue State.

  Displays:
    - SQS main queue depth (polled)
    - Dead-letter queue depth
    - Estimated drain time
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Queue State"}
  end

  @impl true
  def render_page(_assigns) do
    queue_depth = get_queue_depth()
    dlq_depth = get_dlq_depth()
    jobs_per_sec = get_jobs_per_second()
    drain_time = if jobs_per_sec > 0, do: Float.round(queue_depth / jobs_per_sec, 1), else: 0.0

    table(
      columns: [
        %{field: :metric, header: "Queue Metric", sortable: :asc},
        %{field: :value, header: "Value"}
      ],
      id: :queue_state,
      row_attrs: &row_attrs/1,
      row_fetcher: fn _params, _node ->
        rows = [
          %{metric: "Main Queue Depth", value: queue_depth},
          %{metric: "Dead-Letter Queue Depth", value: dlq_depth},
          %{metric: "Processing Rate", value: "#{Float.round(jobs_per_sec, 2)} jobs/s"},
          %{metric: "Estimated Drain Time", value: format_drain_time(drain_time)},
          %{metric: "Queue URL", value: truncate(Application.get_env(:api, :sqs_queue_url, "not configured"), 60)}
        ]

        {rows, length(rows)}
      end,
      title: "Queue State"
    )
  end

  defp row_attrs(_row), do: []

  defp get_queue_depth do
    queue_url = Application.get_env(:api, :sqs_queue_url, "")
    get_sqs_depth(queue_url)
  end

  defp get_dlq_depth do
    dlq_url = Application.get_env(:api, :sqs_dlq_url, "")
    get_sqs_depth(dlq_url)
  end

  defp get_sqs_depth(""), do: 0

  defp get_sqs_depth(url) do
    case ExAws.SQS.get_queue_attributes(url, [:approximate_number_of_messages])
         |> ExAws.request() do
      {:ok, %{"Attributes" => %{"ApproximateNumberOfMessages" => count}}} ->
        String.to_integer(count)

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  defp get_jobs_per_second do
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

  defp format_drain_time(seconds) when seconds <= 0, do: "N/A"
  defp format_drain_time(seconds) when seconds < 60, do: "#{Float.round(seconds, 0)}s"
  defp format_drain_time(seconds) when seconds < 3600, do: "#{Float.round(seconds / 60, 1)}m"
  defp format_drain_time(seconds), do: "#{Float.round(seconds / 3600, 1)}h"

  defp truncate(str, max) when byte_size(str) > max, do: String.slice(str, 0, max) <> "..."
  defp truncate(str, _max), do: str
end
