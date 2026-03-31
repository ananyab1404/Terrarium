defmodule Api.Controllers.WebhookController do
  @moduledoc """
  Handles webhook-triggered invocations.

  Webhook endpoints bypass the standard AuthPlug and instead use
  per-function HMAC-SHA256 token validation.

  Flow:
    POST /v1/webhooks/:function_id/:token
    1. Look up function record, retrieve stored token hash
    2. Compute HMAC-SHA256(stored_token_hash, request_body)
    3. Compare against X-Webhook-Signature header (constant-time)
    4. Build job envelope, enqueue to SQS
    5. Return 202 Accepted + {job_id}
  """

  use Phoenix.Controller, formats: [:json]

  import Api.Helpers.Response

  require Logger

  @doc "POST /v1/webhooks/:function_id/:token — Webhook invocation"
  def invoke(conn, %{"function_id" => function_id, "token" => token} = _params) do
    body = read_raw_body(conn)

    with {:ok, stored_hash} <- lookup_webhook_token(function_id),
         :ok <- verify_token(token, stored_hash),
         :ok <- verify_signature(conn, body, stored_hash) do
      # Build and enqueue job
      input_payload = parse_body(body)

      case enqueue_webhook_job(function_id, input_payload) do
        {:ok, job_id} ->
          Logger.info("Webhook job #{job_id} enqueued for function #{function_id}")
          success(conn, 202, %{job_id: job_id, status: "accepted", source: "webhook"})

        {:error, reason} ->
          Logger.error("Webhook enqueue failed: #{inspect(reason)}")
          error(conn, 503, "Failed to enqueue webhook job")
      end
    else
      {:error, :function_not_found} ->
        error(conn, 404, "Function not found")

      {:error, :invalid_token} ->
        error(conn, 401, "Invalid webhook token")

      {:error, :invalid_signature} ->
        error(conn, 401, "Invalid webhook signature")
    end
  end

  @doc "POST /v1/functions/:function_id/rotate-webhook-token — Rotate webhook token"
  def rotate_token(conn, %{"function_id" => function_id}) do
    {token, token_hash} = generate_webhook_token()

    table = Application.get_env(:api, :dynamodb_jobs_table, "infinity-node-jobs-v1")

    # Update the function record with new token hash
    case update_webhook_token(table, function_id, token_hash) do
      :ok ->
        Logger.info("Webhook token rotated for function #{function_id}")
        success(conn, 200, %{
          webhook_token: token,
          message: "Token rotated. Save this token — it cannot be retrieved again."
        })

      {:error, reason} ->
        Logger.error("Token rotation failed: #{inspect(reason)}")
        error(conn, 500, "Failed to rotate webhook token")
    end
  end

  # --- Token Generation ---

  @doc "Generates a new webhook token and its SHA-256 hash."
  def generate_webhook_token do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    hash = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
    {token, hash}
  end

  # --- Private ---

  defp lookup_webhook_token(function_id) do
    # Look up the function record to get stored token hash
    case Scheduler.JobStore.get("func-#{function_id}") do
      {:ok, func} ->
        case Map.get(func, :webhook_token_hash) || Map.get(func, "webhook_token_hash") do
          nil -> {:error, :function_not_found}
          hash -> {:ok, hash}
        end

      {:error, :not_found} ->
        {:error, :function_not_found}
    end
  end

  defp verify_token(provided_token, stored_hash) do
    computed_hash = :crypto.hash(:sha256, provided_token) |> Base.encode16(case: :lower)

    if secure_compare(computed_hash, stored_hash) do
      :ok
    else
      {:error, :invalid_token}
    end
  end

  defp verify_signature(conn, body, stored_hash) do
    case Plug.Conn.get_req_header(conn, "x-webhook-signature") do
      [signature | _] ->
        expected = :crypto.mac(:hmac, :sha256, stored_hash, body) |> Base.encode16(case: :lower)

        if secure_compare(signature, expected) do
          :ok
        else
          {:error, :invalid_signature}
        end

      [] ->
        # No signature header — just token auth is sufficient
        :ok
    end
  end

  defp enqueue_webhook_job(function_id, input_payload) do
    {:ok, envelope} =
      InfinityNode.JobEnvelope.new(%{
        function_id: function_id,
        artifact_s3_key: "functions/#{function_id}/latest",
        input_payload: input_payload,
        tenant_id: "public"
      })

    job_id = envelope.job_id

    job = %{
      job_id: job_id,
      tenant_id: "public",
      state: "PENDING",
      artifact_ref: %{s3_key: envelope.artifact_s3_key},
      input_ref: %{payload: input_payload},
      resource_limits: envelope.resource_limits,
      priority: 100,
      preferred_region: "global",
      source: "webhook"
    }

    case Scheduler.JobStore.put_new_job(job) do
      {:ok, _} ->
        # Enqueue to SQS
        queue_url = Application.get_env(:api, :sqs_queue_url, "")

        if queue_url != "" do
          {:ok, body} = InfinityNode.JobEnvelope.to_json(envelope)

          case ExAws.SQS.send_message(queue_url, body) |> ExAws.request() do
            {:ok, _} -> {:ok, job_id}
            {:error, reason} -> {:error, reason}
          end
        else
          Logger.warning("SQS_QUEUE_URL not configured — webhook job NOT enqueued (dev mode)")
          {:ok, job_id}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_webhook_token(table, function_id, token_hash) do
    request = %ExAws.Operation.JSON{
      http_method: :post,
      service: :dynamodb,
      headers: [
        {"x-amz-target", "DynamoDB_20120810.UpdateItem"},
        {"content-type", "application/x-amz-json-1.0"}
      ],
      data: %{
        "TableName" => table,
        "Key" => %{"job_id" => %{"S" => "func-#{function_id}"}},
        "UpdateExpression" => "SET webhook_token_hash = :hash, updated_at = :now",
        "ExpressionAttributeValues" => %{
          ":hash" => %{"S" => token_hash},
          ":now" => %{"N" => to_string(System.system_time(:millisecond))}
        }
      }
    }

    case ExAws.request(request) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp read_raw_body(conn) do
    case Map.get(conn.private, :raw_body) do
      nil ->
        # If not cached, try to read (may already be consumed by JSON parser)
        case conn.body_params do
          %{} = params -> Jason.encode!(params)
          _ -> ""
        end

      body ->
        body
    end
  end

  defp parse_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> map
      _ -> %{"raw" => body}
    end
  end

  defp parse_body(_), do: %{}

  # Constant-time string comparison to prevent timing attacks
  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end

  defp secure_compare(_, _), do: false
end
