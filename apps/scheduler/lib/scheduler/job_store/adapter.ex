defmodule Scheduler.JobStore.Adapter do
  @moduledoc """
  Adapter boundary for Phase 1 job state machine persistence.

  A real implementation should map these operations to DynamoDB calls
  with conditional writes.
  """

  @type job :: map()
  @type tenant_id :: String.t()
  @type idempotency_key :: String.t()
  @type reason :: atom() | term()

  @callback put_job_if_absent(job()) :: {:ok, job()} | {:error, :already_exists | reason()}
  @callback get_job(String.t()) :: {:ok, job()} | {:error, :not_found | reason()}
  @callback list_jobs(keyword()) :: [job()]
  @callback mutate_job(String.t(), (job() -> {:ok, job()} | {:error, reason()})) ::
              {:ok, job()} | {:error, :not_found | reason()}

  @callback put_idempotency_if_absent(tenant_id(), idempotency_key(), map()) ::
              {:ok, map()} | {:error, :duplicate | reason()}
  @callback get_idempotency(tenant_id(), idempotency_key()) ::
              {:ok, map()} | {:error, :not_found | reason()}
end
