defmodule Worker.VsockChannel do
  @moduledoc false

  require Logger

  def inject(socket_path, job) do
    Logger.debug("Injecting artifact for #{job_id(job)} via vsock #{socket_path} (stubbed)")
    :ok
  end

  def collect(_socket_path, _timeout_ms) do
    {:ok, %{stdout: "hello from vm\n", stderr: "", exit_code: 0, peak_memory_bytes: 0}}
  end

  defp job_id(%{job_id: id}), do: id
  defp job_id(_), do: "unknown-job"
end
