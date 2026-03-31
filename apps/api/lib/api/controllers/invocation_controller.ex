defmodule Api.Controllers.InvocationController do
  @moduledoc """
  Handles synchronous and asynchronous function invocation.

  Sync: enqueues job, polls DynamoDB every 500ms until TERMINAL or timeout.
  Async: enqueues job, returns 202 immediately.
  """

  use Phoenix.Controller, formats: [:json]

  import Api.Helpers.Response

  require Logger

  @poll_interval_ms 500
  @default_sync_timeout_ms 30_000

  @doc "POST /v1/functions/:function_id/invoke — Synchronous invocation"
  def invoke_sync(conn, %{"function_id" => function_id} = params) do
    with :ok <- validate_payload(params),
         {:ok, job_id} <- check_idempotency_and_enqueue(function_id, params) do
      # Poll for completion
      timeout = Map.get(params, "timeout_ms", @default_sync_timeout_ms)
      deadline = System.monotonic_time(:millisecond) + timeout

      case poll_for_result(job_id, deadline) do
        {:ok, result} ->
          success(conn, 200, result)

        :timeout ->
          success(conn, 202, %{job_id: job_id, status: "processing", message: "Job is still running. Poll GET /v1/jobs/#{job_id}"})
      end
    else
      {:error, :idempotency_conflict, existing_job_id} ->
        error(conn, 409, "Idempotency key already used", %{existing_job_id: existing_job_id})

      {:error, :sqs_failure, reason} ->
        Logger.error("SQS enqueue failed: #{inspect(reason)}")
        error(conn, 503, "Failed to enqueue job — try again")

      {:error, msg} ->
        error(conn, 400, msg)
    end
  end

  @doc "POST /v1/functions/:function_id/invoke/async — Async invocation"
  def invoke_async(conn, %{"function_id" => function_id} = params) do
    with :ok <- validate_payload(params),
         {:ok, job_id} <- check_idempotency_and_enqueue(function_id, params) do
      success(conn, 202, %{job_id: job_id, status: "accepted"})
    else
      {:error, :idempotency_conflict, existing_job_id} ->
        error(conn, 409, "Idempotency key already used", %{existing_job_id: existing_job_id})

      {:error, :sqs_failure, reason} ->
        Logger.error("SQS enqueue failed: #{inspect(reason)}")
        error(conn, 503, "Failed to enqueue job — try again")

      {:error, msg} ->
        error(conn, 400, msg)
    end
  end

  # --- Private ---

  defp validate_payload(params) do
    case Map.get(params, "input_payload") do
      nil -> {:error, "Missing required field: input_payload"}
      val when is_map(val) -> :ok
      _ -> {:error, "input_payload must be a JSON object"}
    end
  end

  defp check_idempotency_and_enqueue(function_id, params) do
    idempotency_key = Map.get(params, "idempotency_key", generate_uuid())
    tenant_id = "public"

    # Check idempotency
    case Scheduler.JobStore.get_idempotency(tenant_id, idempotency_key) do
      {:ok, existing} ->
        {:error, :idempotency_conflict, existing.job_id}

      {:error, :not_found} ->
        do_enqueue(function_id, idempotency_key, tenant_id, params)
    end
  end

  defp do_enqueue(function_id, idempotency_key, tenant_id, params) do
    # Build job via InfinityNode.JobEnvelope
    {:ok, envelope} =
      InfinityNode.JobEnvelope.new(%{
        function_id: function_id,
        artifact_s3_key: "functions/#{function_id}/latest",
        input_payload: Map.get(params, "input_payload", %{}),
        resource_limits: parse_resource_limits(Map.get(params, "resource_limits", %{})),
        idempotency_key: idempotency_key,
        tenant_id: tenant_id
      })

    job_id = envelope.job_id

    # Write job to DynamoDB via Scheduler.JobStore
    job = %{
      job_id: job_id,
      tenant_id: tenant_id,
      state: "PENDING",
      idempotency_key: idempotency_key,
      artifact_ref: %{s3_key: envelope.artifact_s3_key},
      input_ref: %{payload: envelope.input_payload},
      resource_limits: envelope.resource_limits,
      priority: 100,
      preferred_region: "global"
    }

    case Scheduler.JobStore.put_new_job(job) do
      {:ok, _} ->
        # Write idempotency record
        expires_at = System.system_time(:millisecond) + 86_400_000
        Scheduler.JobStore.put_idempotency(tenant_id, idempotency_key, job_id, expires_at)

        # Enqueue to SQS
        case enqueue_to_sqs(envelope) do
          :ok ->
            Logger.info("Job #{job_id} enqueued for function #{function_id}")
            {:ok, job_id}

          {:error, reason} ->
            {:error, :sqs_failure, reason}
        end

      {:error, :already_exists} ->
        {:error, :idempotency_conflict, job_id}

      {:error, reason} ->
        {:error, "Failed to create job: #{inspect(reason)}"}
    end
  end

  defp enqueue_to_sqs(envelope) do
    queue_url = Application.get_env(:api, :sqs_queue_url, "")

    if queue_url == "" do
      Logger.warning("SQS_QUEUE_URL not configured — job NOT enqueued (dev mode)")
      :ok
    else
      {:ok, body} = InfinityNode.JobEnvelope.to_json(envelope)

      case ExAws.SQS.send_message(queue_url, body) |> ExAws.request() do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp poll_for_result(job_id, deadline) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      :timeout
    else
      case Scheduler.JobStore.get(job_id) do
        {:ok, %{state: "TERMINAL"} = job} ->
          {:ok, build_result_response(job)}

        {:ok, _} ->
          Process.sleep(@poll_interval_ms)
          poll_for_result(job_id, deadline)

        {:error, _} ->
          Process.sleep(@poll_interval_ms)
          poll_for_result(job_id, deadline)
      end
    end
  end

  defp build_result_response(job) do
    base = %{
      job_id: job.job_id,
      state: job.state
    }

    case Map.get(job, :failure) do
      nil ->
        result = Map.get(job, :result_ref, %{})
        Map.merge(base, %{
          exit_code: Map.get(result, :exit_code, Map.get(result, "exit_code")),
          stdout_s3_key: Map.get(result, :stdout_s3_key, Map.get(result, "stdout_s3_key")),
          stderr_s3_key: Map.get(result, :stderr_s3_key, Map.get(result, "stderr_s3_key")),
          wall_time_ms: Map.get(result, :wall_time_ms, Map.get(result, "wall_time_ms")),
          peak_memory_bytes: Map.get(result, :peak_memory_bytes, Map.get(result, "peak_memory_bytes"))
        })

      failure ->
        Map.merge(base, %{
          state: "FAILED",
          failure_reason: Map.get(failure, :reason, Map.get(failure, "reason", inspect(failure)))
        })
    end
  end

  defp parse_resource_limits(limits) when is_map(limits) do
    %{
      cpu_shares: Map.get(limits, "cpu_shares", 1024),
      memory_mb: Map.get(limits, "memory_mb", 256),
      timeout_ms: Map.get(limits, "timeout_ms", 30_000)
    }
  end

  defp parse_resource_limits(_), do: %{}

  defp generate_uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    :io_lib.format("~8.16.0b-~4.16.0b-4~3.16.0b-~4.16.0b-~12.16.0b",
      [a, b, c &&& 0x0FFF, d ||| 0x8000 &&& 0xBFFF, e]) |> to_string()
  end
end
