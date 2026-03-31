import Config

config :worker,
  prefetch_snapshot_on_boot: false,
  snapshot_boot_enabled: false

config :scheduler,
  enable_runtime_processes: false

# --- API test configuration ---
config :api,
  api_key: "test-api-key"

config :api, Api.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: "test-secret-key-base-for-testing-only-must-be-at-least-64-characters-long-to-pass-validation"
