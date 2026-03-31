import Config

# =============================================================================
# Runtime Configuration — reads environment variables at boot
# Person 3 owns this file
# =============================================================================

# --- AWS Region ---
config :ex_aws,
  region: System.get_env("AWS_REGION", "us-east-1")

# --- S3 Buckets ---
config :worker,
  logs_bucket: System.get_env("LOGS_BUCKET", "infinity-node-logs-dev"),
  artifacts_bucket: System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts-dev"),
  snapshot_s3_prefix: System.get_env("SNAPSHOT_S3_PREFIX", "snapshots/default")

# --- API Configuration ---
config :api,
  port: String.to_integer(System.get_env("API_PORT", "4000")),
  api_key: System.get_env("INFINITY_NODE_API_KEY", "dev-api-key-change-in-production"),
  artifacts_bucket: System.get_env("ARTIFACTS_BUCKET", "infinity-node-artifacts-dev"),
  logs_bucket: System.get_env("LOGS_BUCKET", "infinity-node-logs-dev"),
  sqs_queue_url: System.get_env("SQS_QUEUE_URL", ""),
  sqs_dlq_url: System.get_env("SQS_DLQ_URL", ""),
  dynamodb_jobs_table: System.get_env("DYNAMODB_JOBS_TABLE", "infinity-node-jobs-v1"),
  dynamodb_idempotency_table: System.get_env("DYNAMODB_IDEMPOTENCY_TABLE", "infinity-node-idempotency-v1"),
  dynamodb_deadletter_table: System.get_env("DYNAMODB_DEADLETTER_TABLE", "infinity-node-deadletter-v1"),
  sns_alerts_topic_arn: System.get_env("SNS_ALERTS_TOPIC_ARN", "")

# --- Scheduler Configuration ---
config :scheduler,
  sqs_queue_url: System.get_env("SQS_QUEUE_URL", ""),
  sqs_dlq_url: System.get_env("SQS_DLQ_URL", ""),
  dynamodb_jobs_table: System.get_env("DYNAMODB_JOBS_TABLE", "infinity-node-jobs-v1"),
  dynamodb_idempotency_table: System.get_env("DYNAMODB_IDEMPOTENCY_TABLE", "infinity-node-idempotency-v1"),
  dynamodb_deadletter_table: System.get_env("DYNAMODB_DEADLETTER_TABLE", "infinity-node-deadletter-v1"),
  sns_alerts_topic_arn: System.get_env("SNS_ALERTS_TOPIC_ARN", "")

# --- OpenTelemetry ---
if config_env() == :prod do
  config :opentelemetry_exporter,
    otlp_endpoint: System.get_env("OTEL_ENDPOINT", "http://localhost:4318")
end
