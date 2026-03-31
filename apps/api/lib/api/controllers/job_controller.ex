defmodule Api.Controllers.JobController do
  @moduledoc """
  Handles job result retrieval.
  """

  use Phoenix.Controller, formats: [:json]

  import Api.Helpers.Response

  @doc "GET /v1/jobs/:job_id — Result retrieval"
  def show(conn, %{"job_id" => job_id}) do
    case Scheduler.JobStore.get(job_id) do
      {:ok, job} ->
        success(conn, 200, format_job_response(job))

      {:error, :not_found} ->
        error(conn, 404, "Job not found")

      {:error, reason} ->
        error(conn, 500, "Failed to retrieve job: #{inspect(reason)}")
    end
  end

  # --- Private ---

  defp format_job_response(%{state: "TERMINAL"} = job) do
    case Map.get(job, :failure) do
      nil ->
        result = Map.get(job, :result_ref, %{})

        %{
          job_id: job.job_id,
          state: "COMPLETED",
          exit_code: get_field(result, :exit_code),
          stdout_s3_key: get_field(result, :stdout_s3_key),
          stderr_s3_key: get_field(result, :stderr_s3_key),
          wall_time_ms: get_field(result, :wall_time_ms),
          peak_memory_bytes: get_field(result, :peak_memory_bytes),
          created_at: Map.get(job, :created_at),
          completed_at: Map.get(job, :updated_at)
        }

      failure ->
        %{
          job_id: job.job_id,
          state: "FAILED",
          failure_reason: get_field(failure, :reason) || inspect(failure),
          failure_category: get_field(failure, :category),
          retry_count: Map.get(job, :retry_count, 0),
          created_at: Map.get(job, :created_at),
          failed_at: Map.get(job, :updated_at)
        }
    end
  end

  defp format_job_response(job) do
    %{
      job_id: job.job_id,
      state: job.state,
      retry_count: Map.get(job, :retry_count, 0),
      assigned_node: Map.get(job, :assigned_node),
      created_at: Map.get(job, :created_at)
    }
  end

  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp get_field(_, _), do: nil
end
