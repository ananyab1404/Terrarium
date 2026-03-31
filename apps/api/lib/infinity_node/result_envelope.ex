defmodule InfinityNode.ResultEnvelope do
  @moduledoc """
  Result envelope returned by Person 1's WorkerProcess after execution.

  Schema mirrors the map returned by `Worker.WorkerProcess.build_success_result/4`.
  Person 3's API reads this to build the response for GET /v1/jobs/:job_id.
  """

  @type t :: %{
          job_id: String.t(),
          exit_code: integer(),
          stdout_s3_key: String.t(),
          stderr_s3_key: String.t(),
          wall_time_ms: non_neg_integer(),
          peak_memory_bytes: non_neg_integer()
        }

  @doc "Validates that a result map has the expected shape."
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(result) when is_map(result) do
    required = [:job_id, :exit_code, :stdout_s3_key, :stderr_s3_key, :wall_time_ms]

    missing =
      required
      |> Enum.reject(fn key ->
        Map.has_key?(result, key) or Map.has_key?(result, to_string(key))
      end)

    case missing do
      [] -> :ok
      keys -> {:error, "Missing result fields: #{inspect(keys)}"}
    end
  end
end
