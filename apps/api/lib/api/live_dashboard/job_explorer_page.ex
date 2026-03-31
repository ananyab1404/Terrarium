defmodule Api.LiveDashboard.JobExplorerPage do
  @moduledoc """
  LiveDashboard custom page: Job Explorer.

  Displays a searchable table of recent jobs from the in-memory JobStore adapter.
  In production, this would query DynamoDB's by_tenant_state_created GSI.
  """

  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Job Explorer"}
  end

  @impl true
  def render_page(_assigns) do
    table(
      columns: [
        %{field: :job_id, header: "Job ID"},
        %{field: :state, header: "State", sortable: :asc},
        %{field: :function_id, header: "Function"},
        %{field: :assigned_node, header: "Node"},
        %{field: :retry_count, header: "Retries"},
        %{field: :created_at, header: "Created At", sortable: :desc}
      ],
      id: :job_explorer,
      row_attrs: &row_attrs/1,
      row_fetcher: &fetch_jobs/2,
      title: "Job Explorer — Last 100 Jobs"
    )
  end

  defp row_attrs(_row), do: []

  defp fetch_jobs(_params, _node) do
    jobs =
      try do
        # Use InMemoryAdapter's list_jobs if available (dev/test)
        # In production, would use DynamoDB GSI query
        adapter = Scheduler.JobStore.InMemoryAdapter

        adapter.list_jobs([])
        |> Enum.reject(fn job -> Map.get(job, :type) == "function" end)
        |> Enum.sort_by(fn job -> Map.get(job, :created_at, 0) end, :desc)
        |> Enum.take(100)
        |> Enum.map(&format_job_row/1)
      rescue
        _ -> []
      end

    {jobs, length(jobs)}
  end

  defp format_job_row(job) do
    %{
      job_id: truncate(Map.get(job, :job_id, "—"), 20),
      state: Map.get(job, :state, "UNKNOWN"),
      function_id: truncate(to_string(Map.get(job, :function_id, Map.get(job, "function_id", "—"))), 20),
      assigned_node: Map.get(job, :assigned_node, "—") || "—",
      retry_count: Map.get(job, :retry_count, 0),
      created_at: format_timestamp(Map.get(job, :created_at))
    }
  end

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
