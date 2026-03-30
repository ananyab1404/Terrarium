defmodule Scheduler.AutoscalerClient.Noop do
  @moduledoc false

  @behaviour Scheduler.AutoscalerClient

  @impl true
  def scale_out(_nodes_to_add), do: :ok

  @impl true
  def scale_in, do: :ok
end
