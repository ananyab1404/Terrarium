defmodule Scheduler.WorkerGateway.Default do
  @moduledoc false

  @behaviour Scheduler.WorkerGateway

  @impl true
  def available_slots do
    if Code.ensure_loaded?(Worker.WorkerProcess) and function_exported?(Worker.WorkerProcess, :available_slots, 0) do
      Worker.WorkerProcess.available_slots()
    else
      0
    end
  end

  @impl true
  def execute(job_envelope) do
    slot_index = Map.get(job_envelope, :slot_index, 0)

    if Code.ensure_loaded?(Worker.WorkerProcess) and function_exported?(Worker.WorkerProcess, :execute, 2) do
      Worker.WorkerProcess.execute(slot_index, job_envelope)
    else
      {:error, :worker_module_unavailable}
    end
  end
end
