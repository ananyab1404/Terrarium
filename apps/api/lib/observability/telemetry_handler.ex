defmodule Api.Observability.TelemetryHandler do
  @moduledoc """
  Attaches to :telemetry events from Person 1's WorkerProcess and
  forwards enriched telemetry envelopes to the buffered exporter.

  Event consumed: [:worker, :execution, :complete]
  Measurements: %{wall_time_ms: integer, peak_memory_bytes: integer}
  Metadata: %{job_id: string, slot_index: integer, exit_code: integer}
  """

  require Logger

  @handler_id "infinity-node-execution-handler"

  @doc "Attaches the telemetry handler. Call once on application startup."
  def attach do
    :telemetry.attach(
      @handler_id,
      [:worker, :execution, :complete],
      &__MODULE__.handle_event/4,
      nil
    )

    Logger.info("TelemetryHandler attached to [:worker, :execution, :complete]")
  end

  @doc "Detaches the handler (for testing/shutdown)."
  def detach do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event([:worker, :execution, :complete], measurements, metadata, _config) do
    envelope = %{
      job_id: Map.get(metadata, :job_id, "unknown"),
      vm_slot_index: Map.get(metadata, :slot_index, -1),
      exit_code: Map.get(metadata, :exit_code, -1),
      execution_wall_ms: Map.get(measurements, :wall_time_ms, 0),
      peak_memory_bytes: Map.get(measurements, :peak_memory_bytes, 0),
      node_id: node_id(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Forward to buffered exporter if running
    case Process.whereis(Api.Observability.OtelExporter) do
      nil -> Logger.debug("OtelExporter not running, skipping telemetry record")
      _pid -> GenServer.cast(Api.Observability.OtelExporter, {:record, envelope})
    end
  rescue
    e ->
      Logger.error("TelemetryHandler crashed: #{Exception.message(e)}")
      :ok
  end

  defp node_id do
    node() |> to_string()
  end
end
