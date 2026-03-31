import Config

# =============================================================================
# Development-specific configuration
# =============================================================================

# --- Logger ---
config :logger, level: :debug

# --- API ---
config :api,
  api_key: "dev-api-key-change-in-production"

# --- Phoenix Endpoint ---
config :api, Api.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  secret_key_base: "dev-only-secret-key-base-replace-in-production-with-64-char-string-from-mix-phx-gen-secret"

# --- Worker ---
config :worker,
  prefetch_snapshot_on_boot: false,
  snapshot_boot_enabled: false

# --- Scheduler ---
config :scheduler,
  enable_runtime_processes: true,
  queue_client_module: Scheduler.QueueClient.Noop,
  dead_letter_store_module: Scheduler.DeadLetterStore.Noop,
  autoscaler_client_module: Scheduler.AutoscalerClient.Noop

# --- ExAws (use localstack in dev if available) ---
# To use localstack: `docker run -d -p 4566:4566 localstack/localstack`
# Then uncomment the following:
# config :ex_aws,
#   access_key_id: "test",
#   secret_access_key: "test",
#   region: "us-east-1",
#   dynamodb: [scheme: "http://", host: "localhost", port: 4566],
#   sqs: [scheme: "http://", host: "localhost", port: 4566],
#   s3: [scheme: "http://", host: "localhost", port: 4566]
