defmodule Api.LiveDashboard.FailureLogPage do
  @moduledoc """
  LiveDashboard custom page: Failure Log.

  Displays terminal jobs with failure reasons, sorted by most recent first.
  Also shows dead-letter queue entries.
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Failure Log"}
  end

  @impl true
  def render_page(_assigns) do
    table(
      columns: [
        %{field: :job_id, header: "Job ID"},
        %{field: :failure_reason, header: "Failure Reason"},
        %{field: :failure_category, header: "Category"},
        %{field: :retry_count, header: "Retries"},
        %{field: :failed_at, header: "Failed At", sortable: :desc}
      ],
      id: :failure_log,
      row_attrs: &row_attrs/1,
      row_fetcher: &fetch_failures/2,
      title: "Failure Log"
    )
  end

  defp row_attrs(_row), do: []

  defp fetch_failures(_params, _node) do
    failures =
      try do
        adapter = Scheduler.JobStore.InMemoryAdapter

        adapter.list_jobs([])
        |> Enum.filter(fn job ->
          Map.get(job, :state) == "TERMINAL" and Map.get(job, :failure) != nil
        end)
        |> Enum.sort_by(fn job -> Map.get(job, :updated_at, 0) end, :desc)
        |> Enum.take(50)
        |> Enum.map(&format_failure_row/1)
      rescue
        _ -> []
      end

    {failures, length(failures)}
  end

  defp format_failure_row(job) do
    failure = Map.get(job, :failure, %{})

    %{
      job_id: truncate(Map.get(job, :job_id, "—"), 20),
      failure_reason: truncate(extract_reason(failure), 60),
      failure_category: Map.get(failure, :category, Map.get(failure, "category", "UNKNOWN")),
      retry_count: Map.get(job, :retry_count, 0),
      failed_at: format_timestamp(Map.get(job, :updated_at))
    }
  end

  defp extract_reason(failure) when is_map(failure) do
    Map.get(failure, :reason, Map.get(failure, "reason", inspect(failure)))
    |> to_string()
  end

  defp extract_reason(other), do: inspect(other)

  defp format_timestamp(nil), do: "—"
  defp format_timestamp(ms) when is_integer(ms) do
    ms
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_iso8601()
    |> String.slice(0, 19)
  end
  defp format_timestamp(_), do: "—"

  defp truncate(str, max) when is_binary(str) and byte_size(str) > max do
    String.slice(str, 0, max) <> "…"
  end
  defp truncate(str, _max), do: str
end
