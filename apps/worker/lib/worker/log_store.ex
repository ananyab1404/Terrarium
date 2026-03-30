defmodule Worker.LogStore do
  @moduledoc false

  require Logger

  def put(s3_key, content) do
    bucket = Application.get_env(:worker, :logs_bucket, System.get_env("LOGS_BUCKET", "infinity-node-logs"))

    case ExAws.S3.put_object(bucket, s3_key, content) |> ExAws.request() do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("log upload failed for #{s3_key}: #{inspect(reason)}")
        :ok
    end
  end
end
