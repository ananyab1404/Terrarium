import Config

config :logger, level: :info

config :worker,
  pool_size: 4,
  logs_bucket: System.get_env("LOGS_BUCKET", "infinity-node-logs"),
  artifacts_bucket: System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts"),
  snapshot_s3_prefix: System.get_env("SNAPSHOT_S3_PREFIX", "snapshots/default"),
  prefetch_snapshot_on_boot: true,
  snapshot_boot_enabled: true,
  use_jailer: false,
  jailer_uid: 1000,
  jailer_gid: 1000,
  infinity_jailer_bin: "/usr/local/bin/infinity-jailer",
  vm_driver: Worker.FirecrackerVM,
  vsock_module: Worker.VsockChannel,
  snapshot_module: Worker.SnapshotManager,
  log_store_module: Worker.LogStore

config :ex_aws,
  region: System.get_env("AWS_REGION", "us-east-1")

# --- API app (Person 3) ---
config :api,
  port: 4000,
  api_key: "dev-api-key-change-in-production",
  artifacts_bucket: "infinity-node-artifacts-dev",
  logs_bucket: "infinity-node-logs-dev",
  sqs_queue_url: "",
  sqs_dlq_url: "",
  dynamodb_jobs_table: "infinity-node-jobs-v1",
  dynamodb_idempotency_table: "infinity-node-idempotency-v1",
  dynamodb_deadletter_table: "infinity-node-deadletter-v1",
  sns_alerts_topic_arn: ""

# --- Phoenix Endpoint ---
config :api, Api.Endpoint,
  url: [host: "localhost"],
  http: [port: 4000],
  server: true,
  secret_key_base: "dev-only-secret-key-base-replace-in-production-with-64-char-string-from-mix-phx-gen-secret",
  live_view: [signing_salt: "infinity_dev"],
  render_errors: [formats: [json: Api.ErrorJSON]]

config :phoenix, :json_library, Jason

config :scheduler,
  enable_runtime_processes: true,
  worker_gateway_module: Scheduler.WorkerGateway.Default,
  queue_client_module: Scheduler.QueueClient.Noop,
  dead_letter_store_module: Scheduler.DeadLetterStore.Noop,
  autoscaler_client_module: Scheduler.AutoscalerClient.Noop

import_config "#{config_env()}.exs"
