defmodule Worker.TestVMDriver do
  def boot(slot_index, socket_path, vsock_path, limits) do
    notify({:boot, slot_index, socket_path, vsock_path, limits})
    {:ok, :vm_ref}
  end

  def kill(socket_path) do
    notify({:kill, socket_path})
    :ok
  end

  defp notify(message) do
    if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, message)
  end
end

defmodule Worker.TestVsock do
  def inject(socket_path, job) do
    notify({:inject, socket_path, job})
    :persistent_term.get({__MODULE__, :inject_result}, :ok)
  end

  def collect(socket_path, timeout_ms) do
    notify({:collect, socket_path, timeout_ms})
    :persistent_term.get({__MODULE__, :collect_result}, {:ok, %{stdout: "ok\n", stderr: "", exit_code: 0, peak_memory_bytes: 123}})
  end

  defp notify(message) do
    if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, message)
  end
end

defmodule Worker.TestSnapshot do
  def restore_slot(slot_index) do
    if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, {:restore, slot_index})
    :persistent_term.get({__MODULE__, :restore_result}, :ok)
  end
end

defmodule Worker.TestLogStore do
  def put(key, content) do
    if pid = :persistent_term.get({__MODULE__, :owner}, nil), do: send(pid, {:log_put, key, content})
    :ok
  end
end

defmodule Worker.WorkerProcessTest do
  use ExUnit.Case, async: false

  setup do
    original = %{
      vm_driver: Application.get_env(:worker, :vm_driver),
      vsock_module: Application.get_env(:worker, :vsock_module),
      snapshot_module: Application.get_env(:worker, :snapshot_module),
      log_store_module: Application.get_env(:worker, :log_store_module)
    }

    Application.put_env(:worker, :vm_driver, Worker.TestVMDriver)
    Application.put_env(:worker, :vsock_module, Worker.TestVsock)
    Application.put_env(:worker, :snapshot_module, Worker.TestSnapshot)
    Application.put_env(:worker, :log_store_module, Worker.TestLogStore)

    :persistent_term.put({Worker.TestVMDriver, :owner}, self())
    :persistent_term.put({Worker.TestVsock, :owner}, self())
    :persistent_term.put({Worker.TestSnapshot, :owner}, self())
    :persistent_term.put({Worker.TestLogStore, :owner}, self())
    :persistent_term.put({Worker.TestVsock, :inject_result}, :ok)
    :persistent_term.put({Worker.TestVsock, :collect_result}, {:ok, %{stdout: "hi\n", stderr: "warn\n", exit_code: 7, peak_memory_bytes: 4096}})
    :persistent_term.put({Worker.TestSnapshot, :restore_result}, :ok)

    on_exit(fn ->
      restore_env(:vm_driver, original.vm_driver)
      restore_env(:vsock_module, original.vsock_module)
      restore_env(:snapshot_module, original.snapshot_module)
      restore_env(:log_store_module, original.log_store_module)

      :persistent_term.erase({Worker.TestVMDriver, :owner})
      :persistent_term.erase({Worker.TestVsock, :owner})
      :persistent_term.erase({Worker.TestSnapshot, :owner})
      :persistent_term.erase({Worker.TestLogStore, :owner})
      :persistent_term.erase({Worker.TestVsock, :inject_result})
      :persistent_term.erase({Worker.TestVsock, :collect_result})
      :persistent_term.erase({Worker.TestSnapshot, :restore_result})
    end)

    :ok
  end

  test "execute success returns envelope and writes logs" do
    job = %{
      job_id: "job-success",
      artifact_bytes: "echo",
      input_payload: %{"hello" => "world"},
      resource_limits: %{timeout_ms: 5_000, memory_mb: 128, cpu_shares: 1024}
    }

    assert {:ok, result} = Worker.WorkerProcess.execute(0, job)
    assert result.job_id == "job-success"
    assert result.exit_code == 7
    assert result.stdout_s3_key == "logs/job-success/stdout"
    assert result.stderr_s3_key == "logs/job-success/stderr"
    assert result.peak_memory_bytes == 4096

    assert_receive {:boot, 0, _socket, _vsock, _limits}
    assert_receive {:inject, _vsock, ^job}
    assert_receive {:collect, _vsock, _timeout}
    assert_receive {:kill, _socket}
    assert_receive {:log_put, "logs/job-success/stdout", "hi\n"}
    assert_receive {:log_put, "logs/job-success/stderr", "warn\n"}
    assert_receive {:restore, 0}
  end

  test "execute timeout returns error and still restores slot" do
    :persistent_term.put({Worker.TestVsock, :collect_result}, {:error, :timeout})

    job = %{
      job_id: "job-timeout",
      artifact_bytes: "echo",
      input_payload: %{},
      resource_limits: %{timeout_ms: 200}
    }

    assert {:error, :timeout} = Worker.WorkerProcess.execute(0, job)

    assert_receive {:kill, _socket}
    assert_receive {:restore, 0}
  end

  defp restore_env(key, nil), do: Application.delete_env(:worker, key)
  defp restore_env(key, value), do: Application.put_env(:worker, key, value)
end
