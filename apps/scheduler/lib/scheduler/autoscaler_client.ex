defmodule Scheduler.AutoscalerClient do
  @moduledoc """
  Boundary for scale-out / scale-in actions.
  """

  @callback scale_out(non_neg_integer()) :: :ok | {:error, term()}
  @callback scale_in() :: :ok | {:error, term()}

  def scale_out(nodes_to_add), do: module().scale_out(nodes_to_add)
  def scale_in, do: module().scale_in()

  defp module do
    Application.get_env(:scheduler, :autoscaler_client_module, Scheduler.AutoscalerClient.Noop)
  end
end
