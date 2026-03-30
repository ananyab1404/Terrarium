defmodule Scheduler.SQSConsumer do
  @moduledoc """
  Polls queue messages and dispatches jobs while respecting worker backpressure.

  Design choices aligned with Person 2 plan:
    - long polling at queue client layer
    - pause polling when no available slots
    - delete queue message after successful dispatch claim path
  """

  use GenServer

  @default_busy_backoff_ms 500
  @default_poll_interval_ms 100

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      queue_client: Keyword.get(opts, :queue_client, Scheduler.QueueClient),
      worker_gateway: Keyword.get(opts, :worker_gateway, Scheduler.WorkerGateway),
      dispatch_coordinator: Keyword.get(opts, :dispatch_coordinator, Scheduler.DispatchCoordinator),
      busy_backoff_ms: Keyword.get(opts, :busy_backoff_ms, @default_busy_backoff_ms),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms),
      queue_opts: Keyword.get(opts, :queue_opts, [])
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    next_delay =
      case state.worker_gateway.available_slots() do
        0 ->
          state.busy_backoff_ms

        _slots ->
          state.queue_client
          |> apply(:receive_messages, [state.queue_opts])
          |> Enum.each(&dispatch_one(&1, state))

          state.poll_interval_ms
      end

    Process.send_after(self(), :poll, next_delay)
    {:noreply, state}
  end

  defp dispatch_one(message, state) do
    case state.dispatch_coordinator.dispatch(message.job_envelope) do
      {:ok, _result} ->
        _ = state.queue_client.delete_message(message.receipt_handle, state.queue_opts)
        :ok

      {:error, _reason} ->
        :ok
    end
  end
end
