defmodule Api.Plugs.RateLimitPlug do
  @moduledoc """
  Per-IP token bucket rate limiter using ETS.

  Default: 100 tokens max, refills at 10 tokens/second.
  Returns 429 Too Many Requests when exhausted.
  """

  import Plug.Conn

  @behaviour Plug

  @table :api_rate_limit
  @max_tokens 100
  @refill_rate 10  # tokens per second

  @doc "Creates the ETS table. Call from Api.Application on startup."
  def create_table do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
  end

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    ip = client_ip(conn)
    now = System.monotonic_time(:second)

    case check_and_consume(ip, now) do
      :ok ->
        conn

      :rate_limited ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("retry-after", "1")
        |> send_resp(429, Jason.encode!(%{error: "rate_limited", message: "Too many requests"}))
        |> halt()
    end
  end

  defp check_and_consume(ip, now) do
    case :ets.lookup(@table, ip) do
      [{^ip, tokens, last_refill}] ->
        elapsed = max(now - last_refill, 0)
        refilled = min(tokens + elapsed * @refill_rate, @max_tokens)

        if refilled >= 1 do
          :ets.insert(@table, {ip, refilled - 1, now})
          :ok
        else
          :rate_limited
        end

      [] ->
        :ets.insert(@table, {ip, @max_tokens - 1, now})
        :ok
    end
  end

  defp client_ip(conn) do
    # Respect X-Forwarded-For when behind ALB
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      [] ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
