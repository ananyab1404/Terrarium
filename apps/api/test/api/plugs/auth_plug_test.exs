defmodule Api.Plugs.AuthPlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Api.Plugs.AuthPlug

  @opts AuthPlug.init([])

  setup do
    # Ensure the test API key is configured
    Application.put_env(:api, :api_key, "test-api-key")
    :ok
  end

  describe "call/2" do
    test "passes with valid API key" do
      conn =
        conn(:get, "/v1/jobs/123")
        |> put_req_header("x-api-key", "test-api-key")
        |> AuthPlug.call(@opts)

      refute conn.halted
    end

    test "returns 401 with invalid API key" do
      conn =
        conn(:get, "/v1/jobs/123")
        |> put_req_header("x-api-key", "wrong-key")
        |> AuthPlug.call(@opts)

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "unauthorized"
    end

    test "returns 401 with missing API key header" do
      conn =
        conn(:get, "/v1/jobs/123")
        |> AuthPlug.call(@opts)

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when api_key config is empty string" do
      Application.put_env(:api, :api_key, "")

      conn =
        conn(:get, "/v1/jobs/123")
        |> put_req_header("x-api-key", "")
        |> AuthPlug.call(@opts)

      assert conn.halted
      assert conn.status == 401
    end
  end
end
