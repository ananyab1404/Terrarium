defmodule InfinityNode.TelemetryEnvelope do
  @moduledoc """
  Telemetry envelope emitted by Person 1's WorkerProcess on execution completion.

  IMPORTANT: The actual telemetry event from WorkerProcess is:
    Event:        [:worker, :execution, :complete]
    Measurements: %{wall_time_ms: integer, peak_memory_bytes: integer}
    Metadata:     %{job_id: string, slot_index: integer, exit_code: integer}

  Person 3's TelemetryHandler attaches to this event and enriches it with
  additional fields (function_id, node_id, queue_wait_ms, etc.) before
  exporting to CloudWatch.
  """

  @type t :: %{
          job_id: String.t(),
          function_id: String.t(),
          function_version: String.t(),
          node_id: String.t(),
          vm_slot_index: non_neg_integer(),
          queue_wait_ms: non_neg_integer(),
          execution_wall_ms: non_neg_integer(),
          peak_memory_bytes: non_neg_integer(),
          exit_code: integer(),
          failure_reason: String.t() | nil,
          stdout_s3_key: String.t(),
          stderr_s3_key: String.t(),
          cost_receipt: map() | nil
        }

  @doc "The telemetry event name emitted by WorkerProcess."
  def event_name, do: [:worker, :execution, :complete]
end
