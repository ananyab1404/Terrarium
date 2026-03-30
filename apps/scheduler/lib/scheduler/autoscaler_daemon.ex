defmodule Scheduler.AutoscalerDaemon do
  @moduledoc """
  Computes scale out/in decisions using hysteresis.

  Scale out:
    queue_depth > available_slots * 2 for 2 consecutive polls

  Scale in:
    available_slots > queue_depth * 3 for 5 consecutive polls
  """

  use GenServer

  @default_poll_ms 15_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      poll_ms: Keyword.get(opts, :poll_ms, @default_poll_ms),
      queue_client: Keyword.get(opts, :queue_client, Scheduler.QueueClient),
      autoscaler_client: Keyword.get(opts, :autoscaler_client, Scheduler.AutoscalerClient),
      node_registry: Keyword.get(opts, :node_registry, Scheduler.NodeRegistry),
      node_registry_opts: Keyword.get(opts, :node_registry_opts, []),
      queue_opts: Keyword.get(opts, :queue_opts, []),
      slots_per_node: Keyword.get(opts, :slots_per_node, 4),
      min_nodes: Keyword.get(opts, :min_nodes, 1),
      max_nodes: Keyword.get(opts, :max_nodes, 50),
      high_count: 0,
      low_count: 0
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    queue_depth = state.queue_client.approximate_depth(state.queue_opts)
    available_slots = max(state.node_registry.cluster_available_slots(state.node_registry_opts), 0)

    state =
      cond do
        queue_depth > available_slots * 2 ->
          maybe_scale_out(%{state | high_count: state.high_count + 1, low_count: 0}, queue_depth)

        available_slots > queue_depth * 3 ->
          maybe_scale_in(%{state | low_count: state.low_count + 1, high_count: 0}, queue_depth, available_slots)

        true ->
          %{state | high_count: 0, low_count: 0}
      end

    Process.send_after(self(), :poll, state.poll_ms)
    {:noreply, state}
  end

  defp maybe_scale_out(%{high_count: high_count} = state, queue_depth) when high_count >= 2 do
    nodes_to_add =
      queue_depth
      |> Kernel./(max(state.slots_per_node, 1))
      |> Float.ceil()
      |> trunc()
      |> max(1)

    _ = state.autoscaler_client.scale_out(nodes_to_add)
    %{state | high_count: 0}
  end

  defp maybe_scale_out(state, _queue_depth), do: state

  defp maybe_scale_in(%{low_count: low_count} = state, _queue_depth, _available_slots) when low_count >= 5 do
    # Guardrail: min_nodes respected by external autoscaler policy; we still issue one scale-in signal.
    _ = state.autoscaler_client.scale_in()
    %{state | low_count: 0}
  end

  defp maybe_scale_in(state, _queue_depth, _available_slots), do: state
end
