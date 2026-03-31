defmodule Api.Observability.MetricsReporter do
  @moduledoc """
  GenServer that pushes 9 custom metrics to CloudWatch every 10 seconds.

  Metrics:
    - active_worker_count, available_worker_slots (Cluster)
    - jobs_per_second (Throughput)
    - queue_depth (Queue)
    - execution_latency_p50/p95/p99 (Latency)
    - failure_rate, dead_letter_count (Reliability)
  """

  use GenServer

  require Logger

  @push_interval_ms 10_000
  @dlq_poll_interval_ms 300_000  # 5 minutes
  @namespace "InfinityNode"

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    schedule_push()
    schedule_dlq_poll()

    state = %{
      job_count: 0,
      failure_count: 0,
      latencies: [],
      dead_letter_count: 0,
      last_push: System.monotonic_time(:second)
    }

    # Attach counters to telemetry events
    :telemetry.attach(
      "metrics-reporter-complete",
      [:worker, :execution, :complete],
      &__MODULE__.handle_execution_complete/4,
      nil
    )

    Logger.info("MetricsReporter started, pushing to CloudWatch every #{@push_interval_ms}ms")
    {:ok, state}
  end

  @impl true
  def handle_info(:push_metrics, state) do
    schedule_push()
    {:noreply, do_push(state)}
  end

  @impl true
  def handle_info(:poll_dlq, state) do
    schedule_dlq_poll()
    dead_count = poll_dead_letter_count()
    {:noreply, %{state | dead_letter_count: dead_count}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_cast({:execution_complete, measurements}, state) do
    wall_time = Map.get(measurements, :wall_time_ms, 0)
    exit_code = Map.get(measurements, :exit_code, 0)

    failures = if exit_code != 0, do: state.failure_count + 1, else: state.failure_count
    latencies = [wall_time | Enum.take(state.latencies, 999)]

    {:noreply, %{state | job_count: state.job_count + 1, failure_count: failures, latencies: latencies}}
  end

  # Telemetry callback (called in the emitting process, forwarded via cast)
  @doc false
  def handle_execution_complete(_event, measurements, metadata, _config) do
    merged = Map.merge(measurements, Map.take(metadata, [:exit_code]))

    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:execution_complete, merged})
    end
  end

  # --- Private ---

  defp do_push(state) do
    now = System.monotonic_time(:second)
    elapsed = max(now - state.last_push, 1)
    jobs_per_second = state.job_count / elapsed

    {p50, p95, p99} = compute_percentiles(state.latencies)

    failure_rate =
      if state.job_count > 0, do: state.failure_count / state.job_count, else: 0.0

    metrics = [
      # Cluster
      metric("ActiveWorkerCount", get_active_workers(), "Count", "Cluster"),
      metric("AvailableWorkerSlots", get_available_slots(), "Count", "Cluster"),
      # Throughput
      metric("JobsPerSecond", jobs_per_second, "Count/Second", "Throughput"),
      # Queue
      metric("QueueDepth", get_queue_depth(), "Count", "Queue"),
      # Latency
      metric("ExecutionLatencyP50", p50, "Milliseconds", "Latency"),
      metric("ExecutionLatencyP95", p95, "Milliseconds", "Latency"),
      metric("ExecutionLatencyP99", p99, "Milliseconds", "Latency"),
      # Reliability
      metric("FailureRate", failure_rate, "None", "Reliability"),
      metric("DeadLetterCount", state.dead_letter_count, "Count", "Reliability")
    ]

    push_to_cloudwatch(metrics)

    %{state | job_count: 0, failure_count: 0, last_push: now}
  end

  defp metric(name, value, unit, sub_namespace) do
    %{
      "MetricName" => name,
      "Value" => value,
      "Unit" => unit,
      "Dimensions" => [
        %{"Name" => "NodeId", "Value" => node() |> to_string()},
        %{"Name" => "Component", "Value" => sub_namespace}
      ]
    }
  end

  defp push_to_cloudwatch(metrics) do
    request = %ExAws.Operation.JSON{
      http_method: :post,
      service: :monitoring,
      headers: [
        {"content-type", "application/x-amz-json-1.0"}
      ],
      data: %{
        "Namespace" => @namespace,
        "MetricData" => metrics
      }
    }

    case ExAws.request(request) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("CloudWatch PutMetricData failed: #{inspect(reason)}")
    end
  rescue
    e -> Logger.error("MetricsReporter push error: #{Exception.message(e)}")
  end

  defp compute_percentiles([]), do: {0, 0, 0}

  defp compute_percentiles(latencies) do
    sorted = Enum.sort(latencies)
    len = length(sorted)

    p50 = Enum.at(sorted, floor(len * 0.50))
    p95 = Enum.at(sorted, min(floor(len * 0.95), len - 1))
    p99 = Enum.at(sorted, min(floor(len * 0.99), len - 1))

    {p50, p95, p99}
  end

  defp get_active_workers do
    # Queries Person 1's WorkerPoolSupervisor child count
    try do
      children = Supervisor.which_children(Worker.WorkerPoolSupervisor)
      length(children)
    rescue
      _ -> 0
    end
  end

  defp get_available_slots do
    try do
      Worker.WorkerProcess.available_slots()
    rescue
      _ -> 0
    end
  end

  defp get_queue_depth do
    queue_url = Application.get_env(:api, :sqs_queue_url, "")

    if queue_url == "" do
      0
    else
      case ExAws.SQS.get_queue_attributes(queue_url, [:approximate_number_of_messages])
           |> ExAws.request() do
        {:ok, %{"Attributes" => %{"ApproximateNumberOfMessages" => count}}} ->
          String.to_integer(count)

        _ ->
          0
      end
    end
  rescue
    _ -> 0
  end

  defp poll_dead_letter_count do
    dlq_url = Application.get_env(:api, :sqs_dlq_url, "")

    if dlq_url == "" do
      0
    else
      case ExAws.SQS.get_queue_attributes(dlq_url, [:approximate_number_of_messages])
           |> ExAws.request() do
        {:ok, %{"Attributes" => %{"ApproximateNumberOfMessages" => count}}} ->
          String.to_integer(count)

        _ ->
          0
      end
    end
  rescue
    _ -> 0
  end

  defp schedule_push, do: Process.send_after(self(), :push_metrics, @push_interval_ms)
  defp schedule_dlq_poll, do: Process.send_after(self(), :poll_dlq, @dlq_poll_interval_ms)
end
