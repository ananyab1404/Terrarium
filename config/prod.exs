import Config

# =============================================================================
# Production-specific configuration
# All sensitive values read from environment variables in config/runtime.exs
# =============================================================================

# --- Logger ---
config :logger, level: :info

# --- Phoenix Endpoint ---
config :api, Api.Endpoint,
  server: true,
  check_origin: true

# --- Worker ---
config :worker,
  prefetch_snapshot_on_boot: true,
  snapshot_boot_enabled: true,
  use_jailer: true

# --- Scheduler ---
config :scheduler,
  enable_runtime_processes: true
  # Production adapter modules set via runtime.exs
