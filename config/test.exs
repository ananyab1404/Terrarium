import Config

config :worker,
  prefetch_snapshot_on_boot: false,
  snapshot_boot_enabled: false

config :scheduler,
  enable_runtime_processes: false
