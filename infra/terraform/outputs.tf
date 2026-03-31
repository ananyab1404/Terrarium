# =============================================================================
# Infinity Node — Terraform Outputs
# Shared with Person 1 and Person 2 for app configuration
# =============================================================================

# --- S3 ---

output "artifacts_bucket_name" {
  description = "S3 bucket for function artifacts and VM snapshots"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "logs_bucket_name" {
  description = "S3 bucket for execution stdout/stderr logs"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  value       = aws_s3_bucket.logs.arn
}

# --- SQS ---

output "sqs_jobs_queue_url" {
  description = "URL of the main job queue (Person 2 consumes this)"
  value       = aws_sqs_queue.jobs.url
}

output "sqs_jobs_queue_arn" {
  description = "ARN of the main job queue"
  value       = aws_sqs_queue.jobs.arn
}

output "sqs_dlq_url" {
  description = "URL of the dead-letter queue"
  value       = aws_sqs_queue.jobs_dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN of the dead-letter queue"
  value       = aws_sqs_queue.jobs_dlq.arn
}

# --- DynamoDB (provisioned by Person 2 via create-tables.ps1) ---

output "dynamodb_jobs_table_name" {
  description = "DynamoDB jobs state machine table name"
  value       = "${var.project_name}-jobs-v1"
}

output "dynamodb_idempotency_table_name" {
  description = "DynamoDB idempotency key deduplication table name"
  value       = "${var.project_name}-idempotency-v1"
}

output "dynamodb_deadletter_table_name" {
  description = "DynamoDB dead-letter table for failed jobs"
  value       = "${var.project_name}-deadletter-v1"
}

# --- SNS ---

output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

# --- IAM ---

output "ecs_task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution (ECR pull, CloudWatch log write)"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "IAM role ARN for application (SQS, DynamoDB, S3, AutoScaling, SNS)"
  value       = aws_iam_role.ecs_task.arn
}

# --- ECS ---

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_api_task_definition_arn" {
  description = "ARN of the API Fargate task definition"
  value       = aws_ecs_task_definition.api.arn
}

output "ecs_worker_task_definition_arn" {
  description = "ARN of the Worker EC2/metal task definition"
  value       = aws_ecs_task_definition.worker.arn
}

# --- CloudWatch ---

output "cloudwatch_log_group_api" {
  description = "CloudWatch log group for API service"
  value       = aws_cloudwatch_log_group.api.name
}

output "cloudwatch_log_group_worker" {
  description = "CloudWatch log group for worker nodes"
  value       = aws_cloudwatch_log_group.worker.name
}

output "cloudwatch_log_group_scheduler" {
  description = "CloudWatch log group for scheduler"
  value       = aws_cloudwatch_log_group.scheduler.name
}

# --- Summary for team ---

output "team_config_summary" {
  description = "Copy-paste config values for .env / runtime.exs"
  value = <<-EOT
    # ============================================
    # Infinity Node — Infrastructure Outputs
    # Share this with Person 1 and Person 2
    # ============================================

    AWS_REGION=${var.aws_region}
    ARTIFACTS_BUCKET=${aws_s3_bucket.artifacts.id}
    LOGS_BUCKET=${aws_s3_bucket.logs.id}
    SQS_QUEUE_URL=${aws_sqs_queue.jobs.url}
    SQS_DLQ_URL=${aws_sqs_queue.jobs_dlq.url}
    DYNAMODB_JOBS_TABLE=${var.project_name}-jobs-v1
    DYNAMODB_IDEMPOTENCY_TABLE=${var.project_name}-idempotency-v1
    DYNAMODB_DEADLETTER_TABLE=${var.project_name}-deadletter-v1
    SNS_ALERTS_TOPIC_ARN=${aws_sns_topic.alerts.arn}
    ECS_TASK_ROLE_ARN=${aws_iam_role.ecs_task.arn}
    ECS_CLUSTER_NAME=${aws_ecs_cluster.main.name}
  EOT
}
