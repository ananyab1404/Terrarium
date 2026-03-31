defmodule Api.Router do
  use Phoenix.Router

  import Phoenix.LiveDashboard.Router

  # --- Pipelines ---

  pipeline :api do
    plug :accepts, ["json"]
    plug Api.Plugs.TelemetryPlug
    plug Api.Plugs.AuthPlug
    plug Api.Plugs.RateLimitPlug
  end

  pipeline :health do
    plug :accepts, ["json"]
  end

  pipeline :dashboard do
    plug :accepts, ["html"]
    plug Api.Plugs.AuthPlug
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug Api.Plugs.TelemetryPlug
    plug Api.Plugs.RateLimitPlug
    # No AuthPlug — webhook uses per-function token auth
  end

  # --- Health check (no auth) ---
  scope "/", Api.Controllers do
    pipe_through :health
    get "/health", HealthController, :check
  end

  # --- API v1 ---
  scope "/v1", Api.Controllers do
    pipe_through :api

    # Functions
    post "/functions", FunctionController, :create
    post "/functions/:function_id/upload-url", FunctionController, :upload_url
    post "/functions/:function_id/rotate-webhook-token", WebhookController, :rotate_token

    # Invocations
    post "/functions/:function_id/invoke", InvocationController, :invoke_sync
    post "/functions/:function_id/invoke/async", InvocationController, :invoke_async

    # Jobs
    get "/jobs/:job_id", JobController, :show
  end

  # --- Webhooks (token-based auth, no API key) ---
  scope "/v1/webhooks", Api.Controllers do
    pipe_through :webhook
    post "/:function_id/:token", WebhookController, :invoke
  end

  # --- LiveDashboard (gated behind auth) ---
  scope "/" do
    pipe_through :dashboard

    live_dashboard "/dashboard",
      metrics: Api.Telemetry,
      additional_pages: [
        cluster_overview: Api.LiveDashboard.ClusterOverviewPage,
        queue_state: Api.LiveDashboard.QueueStatePage,
        latency: Api.LiveDashboard.LatencyPage,
        job_explorer: Api.LiveDashboard.JobExplorerPage,
        failure_log: Api.LiveDashboard.FailureLogPage
      ]
  end
end
