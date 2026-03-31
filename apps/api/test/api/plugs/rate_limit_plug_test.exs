defmodule Api.Plugs.RateLimitPlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Api.Plugs.RateLimitPlug

  @opts RateLimitPlug.init([])

  setup do
    # Recreate ETS table fresh for each test
    try do
      :ets.delete(:api_rate_limit)
    rescue
      _ -> :ok
    end

    RateLimitPlug.create_table()
    :ok
  end

  describe "call/2" do
    test "allows requests under rate limit" do
      conn =
        conn(:get, "/v1/jobs/123")
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> RateLimitPlug.call(@opts)

      refute conn.halted
    end

    test "allows multiple requests from same IP within limit" do
      for _i <- 1..50 do
        conn =
          conn(:get, "/v1/jobs/123")
          |> Map.put(:remote_ip, {192, 168, 1, 2})
          |> RateLimitPlug.call(@opts)

        refute conn.halted
      end
    end

    test "rate limits after exhausting tokens" do
      # Exhaust all 100 tokens
      for _i <- 1..100 do
        conn(:get, "/v1/jobs/123")
        |> Map.put(:remote_ip, {10, 0, 0, 1})
        |> RateLimitPlug.call(@opts)
      end

      # 101st request should be rate limited
      conn =
        conn(:get, "/v1/jobs/123")
        |> Map.put(:remote_ip, {10, 0, 0, 1})
        |> RateLimitPlug.call(@opts)

      assert conn.halted
      assert conn.status == 429
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "rate_limited"
      assert Plug.Conn.get_resp_header(conn, "retry-after") == ["1"]
    end

    test "different IPs have separate rate limits" do
      # Exhaust IP 1
      for _i <- 1..100 do
        conn(:get, "/v1/jobs/123")
        |> Map.put(:remote_ip, {10, 0, 0, 10})
        |> RateLimitPlug.call(@opts)
      end

      # IP 2 should still work
      conn =
        conn(:get, "/v1/jobs/123")
        |> Map.put(:remote_ip, {10, 0, 0, 20})
        |> RateLimitPlug.call(@opts)

      refute conn.halted
    end

    test "respects X-Forwarded-For header" do
      conn =
        conn(:get, "/v1/jobs/123")
        |> put_req_header("x-forwarded-for", "203.0.113.50, 70.41.3.18")
        |> RateLimitPlug.call(@opts)

      refute conn.halted

      # Check that the first IP from X-Forwarded-For is used
      [{ip, _, _}] = :ets.lookup(:api_rate_limit, "203.0.113.50")
      assert ip == "203.0.113.50"
    end
  end
end
