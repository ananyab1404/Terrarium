defmodule Scheduler.DeadLetterStore do
  @moduledoc """
  Boundary for dead-letter persistence.
  """

  @callback put(map()) :: :ok | {:error, term()}

  def put(record), do: module().put(record)

  defp module do
    Application.get_env(:scheduler, :dead_letter_store_module, Scheduler.DeadLetterStore.Noop)
  end
end
