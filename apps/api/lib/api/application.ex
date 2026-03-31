defmodule Api.Application do
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Initialize ETS table for rate limiting before starting endpoint
    Api.Plugs.RateLimitPlug.create_table()

    # Attach telemetry handler (not a supervised process — just a function attachment)
    Api.Observability.TelemetryHandler.attach()

    children = [
      # Telemetry supervisor (metrics definitions + poller)
      Api.Telemetry,
      # Buffered CloudWatch Logs exporter
      Api.Observability.OtelExporter,
      # CloudWatch Metrics reporter (10s push interval)
      Api.Observability.MetricsReporter,
      # Phoenix HTTP endpoint
      Api.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Api.Supervisor]
    Logger.info("Api application starting on port #{Application.get_env(:api, :port, 4000)}")
    Supervisor.start_link(children, opts)
  end
end

