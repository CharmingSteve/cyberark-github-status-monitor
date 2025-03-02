variable "aws_region" {
  description = "Primary AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for high availability"
  type        = string
  default     = "us-west-2"
}

variable "slack_api_token" {
  description = "Slack API token for bot interactions"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
}

variable "github_services" {
  description = "GitHub services to monitor"
  type        = list(string)
  default     = ["Git Operations", "API Requests"]
}

variable "monitoring_interval" {
  description = "Interval in minutes to check GitHub status"
  type        = number
  default     = 5
}

variable "escalation_timeout" {
  description = "Time in minutes before escalating an unacknowledged incident"
  type        = number
  default     = 15
}

variable "escalation_contact" {
  description = "Slack user ID to escalate to if no acknowledgment"
  type        = string
  default     = "@steve"  # Update with actual Slack user ID
}

variable "heartbeat_bucket_name" {
  description = "S3 bucket name for Lambda heartbeat file"
  type        = string
  default     = "github-monitor-heartbeat"
}

variable "primary_region" {
  description = "Set to true if deploying in the primary region, false for secondary"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "failover_threshold" {
  type        = number
  description = "Number of failed health checks before failover"
  default     = 3
}
