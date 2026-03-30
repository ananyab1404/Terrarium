defmodule Scheduler.DispatchCoordinator do
  @moduledoc """
  Dispatches jobs from queue into worker execution with JobStore guarded transitions.

  Flow:
    1) claim (`SCHEDULED -> DISPATCHED`)
    2) mark running (`DISPATCHED -> RUNNING`)
    3) execute via worker gateway
    4) mark terminal success/failure
  """

  use GenServer

  alias Scheduler.JobStore

  @default_lease_ms 120_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def dispatch(job_envelope, opts \\ []) do
    GenServer.call(server(opts), {:dispatch, job_envelope})
  end

  @impl true
  def init(opts) do
    state = %{
      node_id: Keyword.get(opts, :node_id, Atom.to_string(Node.self())),
      lease_ms: Keyword.get(opts, :lease_ms, @default_lease_ms),
      job_store_opts: Keyword.get(opts, :job_store_opts, []),
      worker_gateway: Keyword.get(opts, :worker_gateway, Scheduler.WorkerGateway),
      node_registry: Keyword.get(opts, :node_registry, Scheduler.NodeRegistry)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:dispatch, %{job_id: job_id} = job}, _from, state) do
    with {:ok, _claimed} <- JobStore.claim_for_dispatch(job_id, state.node_id, state.lease_ms, state.job_store_opts),
         {:ok, _running} <- JobStore.mark_running(job_id, state.node_id, state.lease_ms, state.job_store_opts),
         {:ok, result} <- state.worker_gateway.execute(job),
         {:ok, _terminal} <- JobStore.mark_terminal_success(job_id, state.node_id, normalize_result_ref(result), state.job_store_opts) do
      {:reply, {:ok, result}, state}
    else
      {:error, reason} = error ->
        _ =
          JobStore.mark_terminal_failure(
            job_id,
            state.node_id,
            %{category: "execution_error", reason: inspect(reason), retriable: true},
            state.job_store_opts
          )

        {:reply, error, state}
    end
  end

  def handle_call({:dispatch, _bad_job}, _from, state) do
    {:reply, {:error, :invalid_job_envelope}, state}
  end

  defp normalize_result_ref(result) do
    %{
      stdout_s3_key: Map.get(result, :stdout_s3_key),
      stderr_s3_key: Map.get(result, :stderr_s3_key),
      exit_code: Map.get(result, :exit_code),
      wall_time_ms: Map.get(result, :wall_time_ms)
    }
  end

  defp server(opts), do: Keyword.get(opts, :name, __MODULE__)
end
