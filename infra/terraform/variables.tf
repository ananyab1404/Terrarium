variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "infinity-node"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = ""
}

variable "api_container_image" {
  description = "Docker image for API task definition (placeholder OK for skeleton)"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023-minimal"
}

variable "worker_container_image" {
  description = "Docker image for Worker task definition (placeholder OK for skeleton)"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023-minimal"
}

variable "vpc_id" {
  description = "VPC ID for ALB and ECS (must exist)"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
  default     = []
}
