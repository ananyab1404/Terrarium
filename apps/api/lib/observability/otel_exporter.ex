defmodule Api.Observability.OtelExporter do
  @moduledoc """
  Buffered exporter that batches telemetry records and ships to CloudWatch Logs.

  Flush conditions (whichever comes first):
    - Buffer reaches 100 records
    - 2-second timer fires

  On CloudWatch API failure: logs error, retries up to 3 times, then drops with warning.
  """

  use GenServer

  require Logger

  @flush_interval_ms 2_000
  @max_buffer_size 100
  @max_retries 3

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    schedule_flush()

    state = %{
      buffer: [],
      buffer_size: 0,
      log_group: "/infinity-node/worker",
      log_stream: "telemetry-#{node()}-#{System.system_time(:second)}",
      sequence_token: nil
    }

    Logger.info("OtelExporter started, flushing every #{@flush_interval_ms}ms or #{@max_buffer_size} records")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record, envelope}, state) do
    new_buffer = [envelope | state.buffer]
    new_size = state.buffer_size + 1

    if new_size >= @max_buffer_size do
      {:noreply, do_flush(%{state | buffer: new_buffer, buffer_size: new_size})}
    else
      {:noreply, %{state | buffer: new_buffer, buffer_size: new_size}}
    end
  end

  @impl true
  def handle_info(:flush, state) do
    schedule_flush()
    {:noreply, do_flush(state)}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private ---

  defp do_flush(%{buffer: [], buffer_size: 0} = state), do: state

  defp do_flush(state) do
    records = Enum.reverse(state.buffer)
    count = state.buffer_size

    case send_to_cloudwatch(records, state, 0) do
      {:ok, new_token} ->
        Logger.debug("Flushed #{count} telemetry records to CloudWatch")
        %{state | buffer: [], buffer_size: 0, sequence_token: new_token}

      {:error, _reason} ->
        Logger.warning("Failed to flush #{count} records after #{@max_retries} retries — dropping")
        %{state | buffer: [], buffer_size: 0}
    end
  end

  defp send_to_cloudwatch(_records, _state, attempt) when attempt >= @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp send_to_cloudwatch(records, state, attempt) do
    log_events =
      Enum.map(records, fn record ->
        %{
          "timestamp" => System.system_time(:millisecond),
          "message" => Jason.encode!(record)
        }
      end)

    request_body =
      %{
        "logGroupName" => state.log_group,
        "logStreamName" => state.log_stream,
        "logEvents" => log_events
      }
      |> maybe_add_sequence_token(state.sequence_token)

    request = %ExAws.Operation.JSON{
      http_method: :post,
      service: :logs,
      headers: [
        {"x-amz-target", "Logs_20140328.PutLogEvents"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: request_body
    }

    case ExAws.request(request) do
      {:ok, %{"nextSequenceToken" => token}} ->
        {:ok, token}

      {:ok, _} ->
        {:ok, state.sequence_token}

      {:error, {:http_error, 400, %{"__type" => "ResourceNotFoundException"}}} ->
        # Log group/stream doesn't exist yet — create and retry
        ensure_log_stream(state.log_group, state.log_stream)
        send_to_cloudwatch(records, state, attempt + 1)

      {:error, reason} ->
        Logger.warning("CloudWatch PutLogEvents attempt #{attempt + 1} failed: #{inspect(reason)}")
        Process.sleep(100 * (attempt + 1))
        send_to_cloudwatch(records, state, attempt + 1)
    end
  rescue
    e ->
      Logger.error("CloudWatch export error: #{Exception.message(e)}")
      {:error, e}
  end

  defp ensure_log_stream(log_group, log_stream) do
    create_group = %ExAws.Operation.JSON{
      http_method: :post,
      service: :logs,
      headers: [
        {"x-amz-target", "Logs_20140328.CreateLogGroup"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: %{"logGroupName" => log_group}
    }

    ExAws.request(create_group)

    create_stream = %ExAws.Operation.JSON{
      http_method: :post,
      service: :logs,
      headers: [
        {"x-amz-target", "Logs_20140328.CreateLogStream"},
        {"content-type", "application/x-amz-json-1.1"}
      ],
      data: %{"logGroupName" => log_group, "logStreamName" => log_stream}
    }

    ExAws.request(create_stream)
  end

  defp maybe_add_sequence_token(body, nil), do: body
  defp maybe_add_sequence_token(body, token), do: Map.put(body, "sequenceToken", token)

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end
end
