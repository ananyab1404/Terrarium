defmodule Scheduler.AutoscalerDaemonTest do
  use ExUnit.Case, async: false

  defmodule MockQueueClient do
    @behaviour Scheduler.QueueClient

    @impl true
    def receive_messages(_opts), do: []

    @impl true
    def delete_message(_receipt_handle, _opts), do: :ok

    @impl true
    def requeue_job(_job, _opts), do: :ok

    @impl true
    def approximate_depth(opts) do
      agent = Keyword.fetch!(opts, :name)

      Agent.get_and_update(agent, fn
        [head | tail] -> {head, tail}
        [] -> {0, []}
      end)
    end
  end

  defmodule MockAutoscalerClient do
    @behaviour Scheduler.AutoscalerClient

    @impl true
    def scale_out(nodes_to_add) do
      if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, {:scale_out, nodes_to_add})
      :ok
    end

    @impl true
    def scale_in do
      if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, :scale_in)
      :ok
    end
  end

  setup do
    :persistent_term.put({MockAutoscalerClient, :owner}, self())
    {:ok, _pid} = Scheduler.NodeRegistry.start_link(name: :autoscaler_registry)

    on_exit(fn ->
      :persistent_term.erase({MockAutoscalerClient, :owner})
      if Process.whereis(:autoscaler_registry), do: GenServer.stop(:autoscaler_registry)
    end)

    :ok
  end

  test "scales out after two consecutive high-pressure polls" do
    queue_agent = String.to_atom("queue_depths_#{System.unique_integer([:positive])}")
    {:ok, _pid} = Agent.start_link(fn -> [10, 10, 0] end, name: queue_agent)

    Scheduler.NodeRegistry.heartbeat("node-a", %{available_slots: 1, queue_depth: 0}, name: :autoscaler_registry)

    {:ok, pid} =
      Scheduler.AutoscalerDaemon.start_link(
        name: :autoscaler_out,
        poll_ms: 20,
        queue_client: MockQueueClient,
        autoscaler_client: MockAutoscalerClient,
        node_registry: Scheduler.NodeRegistry,
        node_registry_opts: [name: :autoscaler_registry],
        queue_opts: [name: queue_agent],
        slots_per_node: 4
      )

    assert_receive {:scale_out, nodes}, 160
    assert nodes >= 1

    GenServer.stop(pid)
  end

  test "scales in after five consecutive low-pressure polls" do
    queue_agent = String.to_atom("queue_depths_#{System.unique_integer([:positive])}")
    {:ok, _pid} = Agent.start_link(fn -> [0, 0, 0, 0, 0, 0] end, name: queue_agent)

    Scheduler.NodeRegistry.heartbeat("node-a", %{available_slots: 10, queue_depth: 0}, name: :autoscaler_registry)

    {:ok, pid} =
      Scheduler.AutoscalerDaemon.start_link(
        name: :autoscaler_in,
        poll_ms: 20,
        queue_client: MockQueueClient,
        autoscaler_client: MockAutoscalerClient,
        node_registry: Scheduler.NodeRegistry,
        node_registry_opts: [name: :autoscaler_registry],
        queue_opts: [name: queue_agent],
        slots_per_node: 4
      )

    assert_receive :scale_in, 220

    GenServer.stop(pid)
  end
end
