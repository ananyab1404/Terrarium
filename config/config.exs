import Config

config :logger, level: :info

config :worker,
  pool_size: 4,
  logs_bucket: System.get_env("LOGS_BUCKET", "infinity-node-logs"),
  artifacts_bucket: System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts"),
  snapshot_s3_prefix: System.get_env("SNAPSHOT_S3_PREFIX", "snapshots/default"),
  prefetch_snapshot_on_boot: true

config :ex_aws,
  region: System.get_env("AWS_REGION", "us-east-1")
