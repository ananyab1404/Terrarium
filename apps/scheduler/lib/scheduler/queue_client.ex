defmodule Scheduler.QueueClient do
  @moduledoc """
  Queue boundary for SQS operations used by scheduler services.

  In production this should be backed by ExAws.SQS.
  """

  @callback receive_messages(keyword()) :: [map()]
  @callback delete_message(String.t(), keyword()) :: :ok | {:error, term()}
  @callback requeue_job(map(), keyword()) :: :ok | {:error, term()}
  @callback approximate_depth(keyword()) :: non_neg_integer()

  def receive_messages(opts \\ []), do: module().receive_messages(opts)
  def delete_message(receipt_handle, opts \\ []), do: module().delete_message(receipt_handle, opts)
  def requeue_job(job, opts \\ []), do: module().requeue_job(job, opts)
  def approximate_depth(opts \\ []), do: module().approximate_depth(opts)

  defp module do
    Application.get_env(:scheduler, :queue_client_module, Scheduler.QueueClient.Noop)
  end
end
