defmodule Api.Plugs.AuthPlug do
  @moduledoc """
  Static API key authentication via `x-api-key` header.

  MVP only — TODO: Replace with proper authentication for production
  (JWT, OAuth2, or AWS IAM-based auth).
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected_key = Application.get_env(:api, :api_key, "")

    case get_req_header(conn, "x-api-key") do
      [^expected_key] when expected_key != "" ->
        conn

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized", message: "Invalid or missing API key"}))
        |> halt()
    end
  end
end
