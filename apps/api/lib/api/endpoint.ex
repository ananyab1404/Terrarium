defmodule Api.Endpoint do
  use Phoenix.Endpoint, otp_app: :api

  # LiveDashboard socket (for real-time dashboard pages)
  socket "/live", Phoenix.LiveView.Socket

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:api, :request]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  plug Api.Router
end
