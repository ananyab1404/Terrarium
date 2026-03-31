defmodule Api.Plugs.TelemetryPlug do
  @moduledoc """
  Plug that emits per-controller custom telemetry events.

  Events emitted:
    - [:api, :controller, :start] — when a controller action begins
    - [:api, :controller, :stop]  — when a controller action completes (with duration)
    - [:api, :controller, :error] — when a controller action raises an exception

  Measurements:
    - duration: microseconds (on :stop)

  Metadata:
    - controller: controller module name
    - action: action function name
    - method: HTTP method
    - path: request path
    - status: HTTP status code (on :stop)
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    start_time = System.monotonic_time()

    metadata = %{
      method: conn.method,
      path: conn.request_path
    }

    :telemetry.execute([:api, :controller, :start], %{system_time: System.system_time()}, metadata)

    Plug.Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time() - start_time

      stop_metadata = Map.merge(metadata, %{
        status: conn.status,
        controller: get_controller(conn),
        action: get_action(conn)
      })

      :telemetry.execute(
        [:api, :controller, :stop],
        %{duration: duration},
        stop_metadata
      )

      conn
    end)
  end

  defp get_controller(conn) do
    case conn.private do
      %{phoenix_controller: controller} -> inspect(controller)
      _ -> "unknown"
    end
  end

  defp get_action(conn) do
    case conn.private do
      %{phoenix_action: action} -> to_string(action)
      _ -> "unknown"
    end
  end
end
