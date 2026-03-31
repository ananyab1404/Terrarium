defmodule Api.Helpers.Response do
  @moduledoc "Standardized JSON response helpers for all controllers."

  import Plug.Conn

  def success(conn, status \\ 200, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  def error(conn, status, message, details \\ nil) do
    body =
      %{error: error_key(status), message: message}
      |> maybe_add(:details, details)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  defp error_key(400), do: "bad_request"
  defp error_key(401), do: "unauthorized"
  defp error_key(404), do: "not_found"
  defp error_key(409), do: "conflict"
  defp error_key(429), do: "rate_limited"
  defp error_key(503), do: "service_unavailable"
  defp error_key(_), do: "internal_error"

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
