defmodule Scheduler.DeadLetterStore.Noop do
  @moduledoc false

  @behaviour Scheduler.DeadLetterStore

  @impl true
  def put(_record), do: :ok
end
