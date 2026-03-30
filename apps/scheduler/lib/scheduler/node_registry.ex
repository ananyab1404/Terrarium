defmodule Scheduler.NodeRegistry do
  @moduledoc """
  Maintains cluster load vectors and exposes target node selection.

  Load vectors older than `stale_after_ms` are considered unavailable.
  """

  use GenServer

  @default_stale_after_ms 10_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def heartbeat(node_id, load_vector, opts \\ []) do
    GenServer.cast(server(opts), {:heartbeat, node_id, load_vector})
  end

  def least_loaded(opts \\ []) do
    GenServer.call(server(opts), :least_loaded)
  end

  def cluster_available_slots(opts \\ []) do
    GenServer.call(server(opts), :cluster_available_slots)
  end

  @impl true
  def init(opts) do
    state = %{
      loads: %{},
      stale_after_ms: Keyword.get(opts, :stale_after_ms, @default_stale_after_ms),
      now_fun: Keyword.get(opts, :now_fun, fn -> System.system_time(:millisecond) end)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:heartbeat, node_id, load_vector}, state) do
    now = state.now_fun.()

    entry =
      load_vector
      |> Map.put(:node_id, node_id)
      |> Map.put(:last_seen_at, now)
      |> Map.put_new(:available_slots, 0)
      |> Map.put_new(:queue_depth, 0)

    {:noreply, put_in(state, [:loads, node_id], entry)}
  end

  @impl true
  def handle_call(:least_loaded, _from, state) do
    fresh = fresh_entries(state)

    result =
      fresh
      |> Enum.sort_by(fn {_node_id, entry} -> {entry.queue_depth, -entry.available_slots} end)
      |> List.first()
      |> case do
        nil -> {:error, :no_nodes_available}
        {node_id, entry} -> {:ok, %{node_id: node_id, available_slots: entry.available_slots, queue_depth: entry.queue_depth}}
      end

    {:reply, result, state}
  end

  def handle_call(:cluster_available_slots, _from, state) do
    total =
      state
      |> fresh_entries()
      |> Enum.reduce(0, fn {_node_id, entry}, acc -> acc + max(entry.available_slots, 0) end)

    {:reply, total, state}
  end

  defp fresh_entries(state) do
    now = state.now_fun.()

    Enum.filter(state.loads, fn {_node_id, entry} ->
      now - entry.last_seen_at <= state.stale_after_ms
    end)
  end

  defp server(opts), do: Keyword.get(opts, :name, __MODULE__)
end
