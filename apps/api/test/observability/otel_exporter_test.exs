defmodule Api.Observability.OtelExporterTest do
  use ExUnit.Case, async: false

  alias Api.Observability.OtelExporter

  describe "buffer management" do
    test "starts with empty buffer" do
      {:ok, pid} = OtelExporter.start_link(name: :test_exporter)

      state = :sys.get_state(pid)
      assert state.buffer == []
      assert state.buffer_size == 0

      GenServer.stop(pid)
    end

    test "accumulates records via cast" do
      {:ok, pid} = OtelExporter.start_link(name: :test_exporter_2)

      envelope = %{job_id: "test-1", execution_wall_ms: 100}
      GenServer.cast(pid, {:record, envelope})

      # Allow async cast to process
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert state.buffer_size == 1
      assert length(state.buffer) == 1

      GenServer.stop(pid)
    end
  end
end
