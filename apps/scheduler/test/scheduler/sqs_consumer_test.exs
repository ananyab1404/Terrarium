defmodule Scheduler.SQSConsumerTest do
  use ExUnit.Case, async: false

  defmodule MockQueueClient do
    @behaviour Scheduler.QueueClient

    @impl true
    def receive_messages(opts) do
      agent = Keyword.fetch!(opts, :name)
      Agent.get(agent, & &1.messages)
    end

    @impl true
    def delete_message(receipt_handle, opts) do
      agent = Keyword.fetch!(opts, :name)

      Agent.update(agent, fn state ->
        %{state | deleted: [receipt_handle | state.deleted]}
      end)

      :ok
    end

    @impl true
    def requeue_job(_job, _opts), do: :ok

    @impl true
    def approximate_depth(_opts), do: 0
  end

  defmodule MockWorkerGateway do
    @behaviour Scheduler.WorkerGateway

    @impl true
    def available_slots do
      :persistent_term.get({__MODULE__, :slots}, 0)
    end

    @impl true
    def execute(_job), do: {:ok, %{}}
  end

  defmodule MockDispatchCoordinator do
    def dispatch(job_envelope) do
      if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, {:dispatched, job_envelope.job_id})
      {:ok, %{}}
    end
  end

  setup do
    queue_agent = String.to_atom("queue_agent_#{System.unique_integer([:positive])}")
    {:ok, _pid} = Agent.start_link(fn -> %{messages: [], deleted: []} end, name: queue_agent)

    :persistent_term.put({MockDispatchCoordinator, :owner}, self())

    on_exit(fn ->
      :persistent_term.erase({MockWorkerGateway, :slots})
      :persistent_term.erase({MockDispatchCoordinator, :owner})
    end)

    [queue_agent: queue_agent]
  end

  test "backpressure: does not dispatch when no available slots", ctx do
    :persistent_term.put({MockWorkerGateway, :slots}, 0)

    Agent.update(ctx.queue_agent, fn _ ->
      %{messages: [%{receipt_handle: "rh-1", job_envelope: %{job_id: "job-bp"}}], deleted: []}
    end)

    {:ok, pid} =
      Scheduler.SQSConsumer.start_link(
        name: :sqs_bp,
        queue_client: MockQueueClient,
        worker_gateway: MockWorkerGateway,
        dispatch_coordinator: MockDispatchCoordinator,
        queue_opts: [name: ctx.queue_agent],
        busy_backoff_ms: 20,
        poll_interval_ms: 20
      )

    refute_receive {:dispatched, "job-bp"}, 60

    deleted = Agent.get(ctx.queue_agent, & &1.deleted)
    assert deleted == []

    GenServer.stop(pid)
  end

  test "dispatches and deletes message when slots are available", ctx do
    :persistent_term.put({MockWorkerGateway, :slots}, 1)

    Agent.update(ctx.queue_agent, fn _ ->
      %{messages: [%{receipt_handle: "rh-2", job_envelope: %{job_id: "job-ok"}}], deleted: []}
    end)

    {:ok, pid} =
      Scheduler.SQSConsumer.start_link(
        name: :sqs_ok,
        queue_client: MockQueueClient,
        worker_gateway: MockWorkerGateway,
        dispatch_coordinator: MockDispatchCoordinator,
        queue_opts: [name: ctx.queue_agent],
        busy_backoff_ms: 20,
        poll_interval_ms: 20
      )

    assert_receive {:dispatched, "job-ok"}, 120

    deleted = Agent.get(ctx.queue_agent, & &1.deleted)
    assert "rh-2" in deleted

    GenServer.stop(pid)
  end
end
