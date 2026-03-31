defmodule Api.Controllers.JobControllerTest do
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

  describe "GET /v1/jobs/:job_id" do
    test "returns 401 without API key" do
      conn =
        conn(:get, "/v1/jobs/nonexistent-job-id")
        |> Router.call(@opts)

      assert conn.status == 401
    end

    test "returns 404 for nonexistent job" do
      conn =
        conn(:get, "/v1/jobs/00000000-0000-0000-0000-000000000000")
        |> put_req_header("x-api-key", "test-api-key")
        |> Router.call(@opts)

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "not_found"
    end
  end
end
