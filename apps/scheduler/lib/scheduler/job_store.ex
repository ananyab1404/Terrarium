defmodule Scheduler.JobStore do
  @moduledoc """
  Phase 1 implementation of the scheduler job state machine.

  This module guarantees atomic state transitions through the adapter's
  `mutate_job/2` callback (mapped to DynamoDB conditional writes in production).

  Canonical condition semantics:

    * claim (`SCHEDULED -> DISPATCHED`):
      `state = :scheduled AND (attribute_not_exists(lease_expires_at) OR lease_expires_at < :now)`

    * start (`DISPATCHED -> RUNNING`):
      `state = :dispatched AND assigned_node = :node_id`

    * complete (`RUNNING -> TERMINAL`):
      `state = :running AND assigned_node = :node_id`

    * requeue (`RUNNING -> SCHEDULED` on lease expiry):
      `state = :running AND lease_expires_at < :now`

  TODO(phase-2 integration): wire adapter to ExAws DynamoDB.
  TODO(person-1 integration): align result envelope with WorkerProcess contract.
  TODO(person-3 integration): align create-job payload with API envelope schema.
  """

  @type adapter :: module()
  @type job_id :: String.t()
  @type node_id :: String.t()

  @terminal "TERMINAL"

  @spec put_new_job(map(), keyword()) :: {:ok, map()} | {:error, :already_exists | term()}
  def put_new_job(job, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    normalized =
      job
      |> Map.put_new(:state, "PENDING")
      |> Map.put_new(:retry_count, 0)
      |> Map.put_new(:max_retries, 3)
      |> Map.put_new(:created_at, now)
      |> Map.put_new(:updated_at, now)
      |> Map.put_new(:schema_version, 1)

    adapter.put_job_if_absent(normalized, opts)
  end

  @spec put_idempotency(String.t(), String.t(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, :duplicate | term()}
  def put_idempotency(tenant_id, idempotency_key, job_id, expires_at, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)

    record = %{
      tenant_id: tenant_id,
      idempotency_key: idempotency_key,
      job_id: job_id,
      created_at: now_ms(),
      expires_at: expires_at,
      schema_version: 1
    }

    adapter.put_idempotency_if_absent(tenant_id, idempotency_key, record, opts)
  end

  @spec get_idempotency(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :not_found | term()}
  def get_idempotency(tenant_id, idempotency_key, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    adapter.get_idempotency(tenant_id, idempotency_key, opts)
  end

  @spec get(job_id(), keyword()) :: {:ok, map()} | {:error, :not_found | term()}
  def get(job_id, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    adapter.get_job(job_id, opts)
  end

  @spec claim_for_dispatch(job_id(), node_id(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, :already_claimed | :invalid_state | :not_found | term()}
  def claim_for_dispatch(job_id, node_id, lease_ms, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.mutate_job(job_id, fn job ->
      lease = Map.get(job, :lease_expires_at)

      cond do
        job.state != "SCHEDULED" ->
          {:error, :invalid_state}

        is_integer(lease) and lease >= now ->
          {:error, :already_claimed}

        true ->
          {:ok,
           job
           |> Map.put(:state, "DISPATCHED")
           |> Map.put(:assigned_node, node_id)
           |> Map.put(:lease_expires_at, now + lease_ms)
           |> Map.put(:updated_at, now)}
      end
    end, opts)
  end

  @spec mark_running(job_id(), node_id(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, :invalid_state | :not_found | term()}
  def mark_running(job_id, node_id, lease_ms, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.mutate_job(job_id, fn job ->
      cond do
        job.state != "DISPATCHED" ->
          {:error, :invalid_state}

        Map.get(job, :assigned_node) != node_id ->
          {:error, :invalid_state}

        true ->
          {:ok,
           job
           |> Map.put(:state, "RUNNING")
           |> Map.put(:lease_expires_at, now + lease_ms)
           |> Map.put(:updated_at, now)}
      end
    end, opts)
  end

  @spec mark_terminal_success(job_id(), node_id(), map(), keyword()) ::
          {:ok, map()} | {:error, :invalid_state | :not_found | term()}
  def mark_terminal_success(job_id, node_id, result_ref, opts \\ []) do
    transition_to_terminal(job_id, node_id, %{result_ref: result_ref}, opts)
  end

  @spec mark_terminal_failure(job_id(), node_id(), map(), keyword()) ::
          {:ok, map()} | {:error, :invalid_state | :not_found | term()}
  def mark_terminal_failure(job_id, node_id, failure, opts \\ []) do
    transition_to_terminal(job_id, node_id, %{failure: failure}, opts)
  end

  @spec requeue_expired_lease(job_id(), node_id(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, :stale_lease | :invalid_state | :not_found | term()}
  def requeue_expired_lease(job_id, _node_id, next_delay_ms, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.mutate_job(job_id, fn job ->
      cond do
        job.state != "RUNNING" ->
          {:error, :invalid_state}

        not is_integer(Map.get(job, :lease_expires_at)) ->
          {:error, :stale_lease}

        Map.get(job, :lease_expires_at) >= now ->
          {:error, :stale_lease}

        true ->
          {:ok,
           job
           |> Map.put(:state, "SCHEDULED")
           |> Map.update(:retry_count, 1, &(&1 + 1))
           |> Map.put(:next_attempt_at, now + next_delay_ms)
           |> Map.delete(:assigned_node)
           |> Map.put(:updated_at, now)}
      end
    end, opts)
  end

  @spec list_expired_running_jobs(keyword()) :: [map()]
  def list_expired_running_jobs(opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.list_jobs(opts)
    |> Enum.filter(fn job ->
      job.state == "RUNNING" and is_integer(Map.get(job, :lease_expires_at)) and job.lease_expires_at < now
    end)
  end

  @spec force_terminal_deadletter(job_id(), map(), keyword()) ::
          {:ok, map()} | {:error, :invalid_state | :not_found | term()}
  def force_terminal_deadletter(job_id, failure, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.mutate_job(job_id, fn job ->
      case job.state do
        "TERMINAL" ->
          {:ok, job}

        _ ->
          {:ok,
           job
           |> Map.put(:state, @terminal)
           |> Map.put(:failure, failure)
           |> Map.put(:updated_at, now)}
      end
    end, opts)
  end

  defp transition_to_terminal(job_id, node_id, attrs, opts) do
    adapter = Keyword.get(opts, :adapter, Scheduler.JobStore.InMemoryAdapter)
    now = now_ms()

    adapter.mutate_job(job_id, fn job ->
      cond do
        job.state != "RUNNING" ->
          {:error, :invalid_state}

        Map.get(job, :assigned_node) != node_id ->
          {:error, :invalid_state}

        true ->
          {:ok,
           job
           |> Map.merge(attrs)
           |> Map.put(:state, @terminal)
           |> Map.put(:updated_at, now)}
      end
    end, opts)
  end

  defp now_ms do
    System.system_time(:millisecond)
  end
end
