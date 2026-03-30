defmodule Scheduler.LeaseReaperTest do
  use ExUnit.Case, async: false

  alias Scheduler.JobStore
  alias Scheduler.JobStore.InMemoryAdapter

  defmodule MockQueueClient do
    @behaviour Scheduler.QueueClient

    @impl true
    def receive_messages(_opts), do: []

    @impl true
    def delete_message(_receipt_handle, _opts), do: :ok

    @impl true
    def requeue_job(job, opts) do
      owner = Keyword.fetch!(opts, :owner)
      send(owner, {:requeued, job.job_id})
      :ok
    end

    @impl true
    def approximate_depth(_opts), do: 0
  end

  defmodule MockDeadLetterStore do
    @behaviour Scheduler.DeadLetterStore

    @impl true
    def put(record) do
      if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, {:deadletter, record.job_id})
      :ok
    end
  end

  setup do
    name = String.to_atom("reaper_store_#{System.unique_integer([:positive])}")
    {:ok, _pid} = InMemoryAdapter.start_link(name: name)
    :persistent_term.put({MockDeadLetterStore, :owner}, self())

    on_exit(fn ->
      :persistent_term.erase({MockDeadLetterStore, :owner})
    end)

    [store_opts: [adapter: InMemoryAdapter, name: name]]
  end

  test "requeues expired running job under retry limit", ctx do
    now = System.system_time(:millisecond)

    assert {:ok, _} =
             JobStore.put_new_job(
               %{
                 job_id: "job-requeue",
                 state: "RUNNING",
                 assigned_node: "node-a",
                 lease_expires_at: now - 10,
                 retry_count: 1,
                 max_retries: 3
               },
               ctx.store_opts
             )

    {:ok, pid} =
      Scheduler.LeaseReaper.start_link(
        name: :reaper_requeue,
        interval_ms: 500,
        next_delay_ms: 100,
        queue_client: MockQueueClient,
        dead_letter_store: MockDeadLetterStore,
        job_store_opts: ctx.store_opts,
        queue_opts: [owner: self()]
      )

    assert_receive {:requeued, "job-requeue"}, 150

    assert {:ok, job} = JobStore.get("job-requeue", ctx.store_opts)
    assert job.state == "SCHEDULED"

    GenServer.stop(pid)
  end

  test "deadletters expired running job at retry limit", ctx do
    now = System.system_time(:millisecond)

    assert {:ok, _} =
             JobStore.put_new_job(
               %{
                 job_id: "job-dlq",
                 state: "RUNNING",
                 assigned_node: "node-a",
                 lease_expires_at: now - 10,
                 retry_count: 3,
                 max_retries: 3
               },
               ctx.store_opts
             )

    {:ok, pid} =
      Scheduler.LeaseReaper.start_link(
        name: :reaper_dlq,
        interval_ms: 500,
        queue_client: MockQueueClient,
        dead_letter_store: MockDeadLetterStore,
        job_store_opts: ctx.store_opts,
        queue_opts: [owner: self()]
      )

    assert_receive {:deadletter, "job-dlq"}, 150

    assert {:ok, job} = JobStore.get("job-dlq", ctx.store_opts)
    assert job.state == "TERMINAL"

    GenServer.stop(pid)
  end
end
