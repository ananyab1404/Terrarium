defmodule Scheduler.WorkerGateway do
  @moduledoc """
  Boundary used by scheduler components to query slot capacity and execute jobs.

  Default implementation delegates to `Worker.WorkerProcess`.
  """

  @callback available_slots() :: non_neg_integer()
  @callback execute(map()) :: {:ok, map()} | {:error, term()}

  def available_slots do
    module().available_slots()
  end

  def execute(job_envelope) do
    module().execute(job_envelope)
  end

  defp module do
    Application.get_env(:scheduler, :worker_gateway_module, Scheduler.WorkerGateway.Default)
  end
end
