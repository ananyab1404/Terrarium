defmodule Scheduler.JobStore.InMemoryAdapter do
  @moduledoc """
  Deterministic in-memory adapter for Phase 1 tests.

  It provides atomic mutation semantics using a single Agent process,
  mimicking DynamoDB conditional update behavior at logical level.
  """

  @behaviour Scheduler.JobStore.Adapter

  use Agent

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    Agent.start_link(fn -> %{jobs: %{}, idempotency: %{}} end, name: name)
  end

  @impl true
  def put_job_if_absent(job, opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)
    job_id = job.job_id

    Agent.get_and_update(agent, fn state ->
      case Map.has_key?(state.jobs, job_id) do
        true ->
          {{:error, :already_exists}, state}

        false ->
          new_state = put_in(state, [:jobs, job_id], job)
          {{:ok, job}, new_state}
      end
    end)
  end

  @impl true
  def get_job(job_id, opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)

    Agent.get(agent, fn state ->
      case Map.fetch(state.jobs, job_id) do
        {:ok, job} -> {:ok, job}
        :error -> {:error, :not_found}
      end
    end)
  end

  @impl true
  def list_jobs(opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)

    Agent.get(agent, fn state ->
      Map.values(state.jobs)
    end)
  end

  @impl true
  def mutate_job(job_id, mutator, opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)

    Agent.get_and_update(agent, fn state ->
      case Map.fetch(state.jobs, job_id) do
        :error ->
          {{:error, :not_found}, state}

        {:ok, current_job} ->
          case mutator.(current_job) do
            {:ok, updated_job} ->
              new_state = put_in(state, [:jobs, job_id], updated_job)
              {{:ok, updated_job}, new_state}

            {:error, reason} ->
              {{:error, reason}, state}
          end
      end
    end)
  end

  @impl true
  def put_idempotency_if_absent(tenant_id, idempotency_key, value, opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)
    key = {tenant_id, idempotency_key}

    Agent.get_and_update(agent, fn state ->
      case Map.has_key?(state.idempotency, key) do
        true ->
          {{:error, :duplicate}, state}

        false ->
          new_state = put_in(state, [:idempotency, key], value)
          {{:ok, value}, new_state}
      end
    end)
  end

  @impl true
  def get_idempotency(tenant_id, idempotency_key, opts \\ []) do
    agent = Keyword.get(opts, :name, __MODULE__)
    key = {tenant_id, idempotency_key}

    Agent.get(agent, fn state ->
      case Map.fetch(state.idempotency, key) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, :not_found}
      end
    end)
  end
end
