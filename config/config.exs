import Config

config :logger, level: :info

config :worker,
  pool_size: 4,
  logs_bucket: System.get_env("LOGS_BUCKET", "infinity-node-logs")

config :ex_aws,
  region: System.get_env("AWS_REGION", "us-east-1")
