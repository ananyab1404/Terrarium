defmodule Api.Observability.MetricsReporterTest do
  use ExUnit.Case, async: false

  alias Api.Observability.MetricsReporter

  describe "init/1" do
    test "starts with zeroed counters" do
      {:ok, pid} = MetricsReporter.start_link(name: :test_reporter)

      state = :sys.get_state(pid)
      assert state.job_count == 0
      assert state.failure_count == 0
      assert state.latencies == []
      assert state.dead_letter_count == 0

      GenServer.stop(pid)
    end
  end

  describe "handle_cast {:execution_complete, ...}" do
    test "increments job count on success" do
      {:ok, pid} = MetricsReporter.start_link(name: :test_reporter_2)

      GenServer.cast(pid, {:execution_complete, %{wall_time_ms: 120, exit_code: 0}})
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert state.job_count == 1
      assert state.failure_count == 0
      assert state.latencies == [120]

      GenServer.stop(pid)
    end

    test "increments failure count on non-zero exit code" do
      {:ok, pid} = MetricsReporter.start_link(name: :test_reporter_3)

      GenServer.cast(pid, {:execution_complete, %{wall_time_ms: 250, exit_code: 1}})
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert state.job_count == 1
      assert state.failure_count == 1

      GenServer.stop(pid)
    end

    test "accumulates multiple latency samples" do
      {:ok, pid} = MetricsReporter.start_link(name: :test_reporter_4)

      for ms <- [100, 200, 300, 400, 500] do
        GenServer.cast(pid, {:execution_complete, %{wall_time_ms: ms, exit_code: 0}})
      end

      Process.sleep(100)

      state = :sys.get_state(pid)
      assert state.job_count == 5
      assert length(state.latencies) == 5

      GenServer.stop(pid)
    end

    test "caps latency buffer at 1000 samples" do
      {:ok, pid} = MetricsReporter.start_link(name: :test_reporter_5)

      for i <- 1..1050 do
        GenServer.cast(pid, {:execution_complete, %{wall_time_ms: i, exit_code: 0}})
      end

      Process.sleep(200)

      state = :sys.get_state(pid)
      # Buffer capped at 1000 (latest 1000 prepended, old ones dropped)
      assert length(state.latencies) <= 1000

      GenServer.stop(pid)
    end
  end
end
