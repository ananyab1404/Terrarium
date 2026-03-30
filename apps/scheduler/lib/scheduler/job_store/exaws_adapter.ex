defmodule Scheduler.JobStore.ExAwsAdapter do
  @moduledoc """
  Placeholder adapter for DynamoDB-backed JobStore persistence.

  This module is intentionally left as integration scaffolding.
  Replace each function with real ExAws calls from the project that owns
  AWS credentials/config bootstrap.

  TODO(other project integration):
    - configure ExAws region and credentials provider
    - map maps to DynamoDB attribute values
    - return normalized error atoms for condition-check failures
  """

  @behaviour Scheduler.JobStore.Adapter

  @impl true
  def put_job_if_absent(_job, _opts \\ []), do: {:error, :not_implemented}

  @impl true
  def get_job(_job_id, _opts \\ []), do: {:error, :not_implemented}

  @impl true
  def list_jobs(_opts \\ []), do: []

  @impl true
  def mutate_job(_job_id, _mutator, _opts \\ []), do: {:error, :not_implemented}

  @impl true
  def put_idempotency_if_absent(_tenant_id, _idempotency_key, _value, _opts \\ []),
    do: {:error, :not_implemented}

  @impl true
  def get_idempotency(_tenant_id, _idempotency_key, _opts \\ []), do: {:error, :not_implemented}

  # Example condition expressions to implement with UpdateItem:
  # claim:      "#state = :scheduled AND (attribute_not_exists(lease_expires_at) OR lease_expires_at < :now)"
  # start:      "#state = :dispatched AND assigned_node = :node"
  # complete:   "#state = :running AND assigned_node = :node"
  # requeue:    "#state = :running AND lease_expires_at < :now"
end
