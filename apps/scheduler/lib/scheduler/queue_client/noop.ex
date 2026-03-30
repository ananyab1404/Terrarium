defmodule Scheduler.QueueClient.Noop do
  @moduledoc false

  @behaviour Scheduler.QueueClient

  @impl true
  def receive_messages(_opts), do: []

  @impl true
  def delete_message(_receipt_handle, _opts), do: :ok

  @impl true
  def requeue_job(_job, _opts), do: :ok

  @impl true
  def approximate_depth(_opts), do: 0
end
