defmodule Api.Controllers.FunctionController do
  @moduledoc """
  Handles function registration and presigned upload URL generation.
  """

  use Phoenix.Controller, formats: [:json]

  import Api.Helpers.Response

  require Logger

  @doc "POST /v1/functions — Register a new function"
  def create(conn, params) do
    with {:ok, name} <- require_string(params, "name"),
         {:ok, runtime} <- require_string(params, "runtime") do
      function_id = generate_uuid()
      description = Map.get(params, "description", "")
      now = System.system_time(:millisecond)

      table = Application.get_env(:api, :dynamodb_jobs_table, "infinity-node-jobs-v1")

      # Generate webhook token (stored as hash, returned as plaintext once)
      {webhook_token, token_hash} = Api.Controllers.WebhookController.generate_webhook_token()

      # Store function record — uses job table with a `type: "function"` marker
      # This avoids needing a separate functions table for MVP
      record = %{
        "job_id" => "func-#{function_id}",
        "function_id" => function_id,
        "type" => "function",
        "name" => name,
        "runtime" => runtime,
        "description" => description,
        "state" => "REGISTERED",
        "webhook_token_hash" => token_hash,
        "created_at" => now,
        "updated_at" => now,
        "tenant_id" => "public",
        "schema_version" => 1
      }

      case put_item(table, record) do
        :ok ->
          Logger.info("Function registered: #{function_id} (#{name})")
          success(conn, 201, %{
            function_id: function_id,
            name: name,
            runtime: runtime,
            webhook_token: webhook_token,
            webhook_url: "/v1/webhooks/#{function_id}/<token>",
            message: "Save the webhook_token — it cannot be retrieved again."
          })

        {:error, reason} ->
          Logger.error("Failed to register function: #{inspect(reason)}")
          error(conn, 503, "Failed to register function")
      end
    else
      {:error, msg} ->
        error(conn, 400, msg)
    end
  end

  @doc "POST /v1/functions/:function_id/upload-url — Get presigned S3 PUT URL"
  def upload_url(conn, %{"function_id" => function_id}) do
    bucket = Application.get_env(:api, :artifacts_bucket, "infinity-node-artifacts-dev")
    timestamp = System.system_time(:second)
    s3_key = "functions/#{function_id}/#{timestamp}"

    # Generate presigned PUT URL (expires in 1 hour)
    {:ok, upload_url} =
      ExAws.S3.presigned_url(
        ExAws.Config.new(:s3),
        :put,
        bucket,
        s3_key,
        expires_in: 3600
      )

    success(conn, 200, %{
      upload_url: upload_url,
      artifact_s3_key: s3_key,
      expires_in_seconds: 3600
    })
  end

  # --- Private ---

  defp require_string(params, key) do
    case Map.get(params, key) do
      val when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing required field: #{key}"}
    end
  end

  defp put_item(table, item) do
    # For MVP, uses ExAws.Dynamo directly
    # In production, this would go through a proper adapter
    request = %ExAws.Operation.JSON{
      http_method: :post,
      service: :dynamodb,
      headers: [
        {"x-amz-target", "DynamoDB_20120810.PutItem"},
        {"content-type", "application/x-amz-json-1.0"}
      ],
      data: %{
        "TableName" => table,
        "Item" => encode_dynamo_item(item)
      }
    }

    case ExAws.request(request) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp encode_dynamo_item(map) do
    Map.new(map, fn
      {k, v} when is_binary(v) -> {k, %{"S" => v}}
      {k, v} when is_integer(v) -> {k, %{"N" => to_string(v)}}
      {k, v} when is_float(v) -> {k, %{"N" => to_string(v)}}
      {k, v} when is_map(v) -> {k, %{"M" => encode_dynamo_item(v)}}
      {k, true} -> {k, %{"BOOL" => true}}
      {k, false} -> {k, %{"BOOL" => false}}
      {k, nil} -> {k, %{"NULL" => true}}
    end)
  end

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    :io_lib.format(
      "~8.16.0b-~4.16.0b-4~3.16.0b-~4.16.0b-~12.16.0b",
      [a, b, c &&& 0x0FFF, d ||| 0x8000 &&& 0xBFFF, e]
    )
    |> to_string()
  end
end
