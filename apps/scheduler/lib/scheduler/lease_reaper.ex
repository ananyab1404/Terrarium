defmodule Scheduler.LeaseReaper do
  @moduledoc """
  Reclaims expired running leases and re-enqueues jobs.

  When retry budget is exhausted, routes terminal failure to dead-letter.
  """

  use GenServer

  alias Scheduler.JobStore

  @default_interval_ms 30_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms),
      next_delay_ms: Keyword.get(opts, :next_delay_ms, 1_000),
      queue_client: Keyword.get(opts, :queue_client, Scheduler.QueueClient),
      dead_letter_store: Keyword.get(opts, :dead_letter_store, Scheduler.DeadLetterStore),
      job_store_opts: Keyword.get(opts, :job_store_opts, []),
      queue_opts: Keyword.get(opts, :queue_opts, [])
    }

    send(self(), :reap)
    {:ok, state}
  end

  @impl true
  def handle_info(:reap, state) do
    JobStore.list_expired_running_jobs(state.job_store_opts)
    |> Enum.each(&handle_expired_job(&1, state))

    Process.send_after(self(), :reap, state.interval_ms)
    {:noreply, state}
  end

  defp handle_expired_job(job, state) do
    max_retries = Map.get(job, :max_retries, 3)
    retry_count = Map.get(job, :retry_count, 0)

    if retry_count >= max_retries do
      _ =
        JobStore.force_terminal_deadletter(
          job.job_id,
          %{category: "deadlettered", message: "Retry budget exhausted", retriable: false},
          state.job_store_opts
        )

      _ =
        state.dead_letter_store.put(%{
          job_id: job.job_id,
          retry_count: retry_count,
          max_retries: max_retries,
          failure_reason: "Retry budget exhausted"
        })

      :ok
    else
      with {:ok, requeued} <-
             JobStore.requeue_expired_lease(
               job.job_id,
               Map.get(job, :assigned_node, "unknown"),
               state.next_delay_ms,
               state.job_store_opts
             ) do
        _ = state.queue_client.requeue_job(requeued, state.queue_opts)
      end
    end
  end
end
