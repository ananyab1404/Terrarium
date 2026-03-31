defmodule Api.Controllers.HealthController do
  use Phoenix.Controller, formats: [:json]

  import Api.Helpers.Response

  def check(conn, _params) do
    success(conn, 200, %{status: "ok", version: "0.1.0"})
  end
end
