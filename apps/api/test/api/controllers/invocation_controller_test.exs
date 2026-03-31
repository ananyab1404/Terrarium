defmodule Api.Controllers.InvocationControllerTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Api.Router

  @opts Api.Router.init([])

  setup do
    Application.put_env(:api, :api_key, "test-api-key")

    try do
      Api.Plugs.RateLimitPlug.create_table()
    rescue
      _ -> :ok
    end

    :ok
  end

  describe "POST /v1/functions/:function_id/invoke" do
    test "returns 401 without API key" do
      conn =
        conn(:post, "/v1/functions/func-123/invoke", %{"input_payload" => %{"key" => "value"}})
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 401
    end

    test "returns 400 when input_payload is missing" do
      conn =
        conn(:post, "/v1/functions/func-123/invoke", %{})
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-api-key", "test-api-key")
        |> Router.call(@opts)

      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["message"] =~ "input_payload"
    end
  end

  describe "POST /v1/functions/:function_id/invoke/async" do
    test "returns 401 without API key" do
      conn =
        conn(:post, "/v1/functions/func-123/invoke/async", %{"input_payload" => %{}})
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 401
    end
  end
end
