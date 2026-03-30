defmodule Scheduler.DispatchCoordinatorTest do
  use ExUnit.Case, async: false

  alias Scheduler.JobStore
  alias Scheduler.JobStore.InMemoryAdapter

  defmodule MockWorkerGateway do
    @behaviour Scheduler.WorkerGateway

    @impl true
    def available_slots, do: 1

    @impl true
    def execute(job_envelope) do
      case :persistent_term.get({__MODULE__, :mode}, :ok) do
        :ok ->
          {:ok,
           %{
             job_id: job_envelope.job_id,
             stdout_s3_key: "logs/#{job_envelope.job_id}/stdout",
             stderr_s3_key: "logs/#{job_envelope.job_id}/stderr",
             exit_code: 0,
             wall_time_ms: 12
           }}

        :error ->
          {:error, :vm_failed}
      end
    end
  end

  setup do
    name = String.to_atom("dispatch_store_#{System.unique_integer([:positive])}")
    {:ok, _pid} = InMemoryAdapter.start_link(name: name)

    :persistent_term.put({MockWorkerGateway, :mode}, :ok)

    on_exit(fn ->
      :persistent_term.erase({MockWorkerGateway, :mode})
    end)

    [store_opts: [adapter: InMemoryAdapter, name: name]]
  end

  test "dispatch success drives terminal success transition", ctx do
    assert {:ok, _job} =
             JobStore.put_new_job(%{job_id: "job-1", state: "SCHEDULED", retry_count: 0}, ctx.store_opts)

    {:ok, pid} =
      Scheduler.DispatchCoordinator.start_link(
        name: :dispatch_success,
        node_id: "node-a",
        worker_gateway: MockWorkerGateway,
        job_store_opts: ctx.store_opts
      )

    assert {:ok, result} = Scheduler.DispatchCoordinator.dispatch(%{job_id: "job-1"}, name: :dispatch_success)
    assert result.exit_code == 0

    assert {:ok, final_job} = JobStore.get("job-1", ctx.store_opts)
    assert final_job.state == "TERMINAL"
    assert is_map(final_job.result_ref)

    GenServer.stop(pid)
  end

  test "dispatch failure records terminal failure", ctx do
    :persistent_term.put({MockWorkerGateway, :mode}, :error)

    assert {:ok, _job} =
             JobStore.put_new_job(%{job_id: "job-2", state: "SCHEDULED", retry_count: 0}, ctx.store_opts)

    {:ok, pid} =
      Scheduler.DispatchCoordinator.start_link(
        name: :dispatch_failure,
        node_id: "node-a",
        worker_gateway: MockWorkerGateway,
        job_store_opts: ctx.store_opts
      )

    assert {:error, :vm_failed} = Scheduler.DispatchCoordinator.dispatch(%{job_id: "job-2"}, name: :dispatch_failure)

    assert {:ok, final_job} = JobStore.get("job-2", ctx.store_opts)
    assert final_job.state == "TERMINAL"
    assert is_map(final_job.failure)

    GenServer.stop(pid)
  end
end
