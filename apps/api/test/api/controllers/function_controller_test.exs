defmodule Api.Controllers.FunctionControllerTest do
  use ExUnit.Case, async: false
  use Plug.Test

  # Note: These tests exercise the controller logic through the Router.
  # They require Phoenix.ConnTest which is available after `mix deps.get`.
  # For now, they test the request/response cycle via Plug.Test.

  alias Api.Router

  @opts Api.Router.init([])

  setup do
    Application.put_env(:api, :api_key, "test-api-key")

    # Create ETS table for rate limiter if not exists
    try do
      Api.Plugs.RateLimitPlug.create_table()
    rescue
      _ -> :ok
    end

    :ok
  end

  describe "POST /v1/functions" do
    test "returns 401 without API key" do
      conn =
        conn(:post, "/v1/functions", %{"name" => "my-func", "runtime" => "python3.11"})
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 401
    end

    test "returns 400 when name is missing" do
      conn =
        conn(:post, "/v1/functions", %{"runtime" => "python3.11"})
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "test-api-key")
        |> Router.call(@opts)

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["message"] =~ "name"
    end

    test "returns 400 when runtime is missing" do
      conn =
        conn(:post, "/v1/functions", %{"name" => "my-func"})
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "test-api-key")
        |> Router.call(@opts)

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["message"] =~ "runtime"
    end
  end

  describe "GET /health" do
    test "returns 200 OK without auth" do
      conn =
        conn(:get, "/health")
        |> Router.call(@opts)

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["data"]["status"] == "ok"
    end
  end
end
