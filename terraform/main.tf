# Main Terraform configuration file
# This file serves as the entry point and coordinates other resources

locals {
  common_tags = {
    Project     = "GitHub Status Monitor"
    Environment = "Production"
    ManagedBy   = "Terraform"
    ManagedBy   = "Terraform"
  }
  
  lambda_environment_vars_github_monitor = {
    DYNAMODB_TABLE       = aws_dynamodb_table.github_status.name
    SLACK_WEBHOOK_URL    = var.slack_webhook_url
    SLACK_API_TOKEN      = var.slack_api_token
    GITHUB_SERVICES      = jsonencode(var.github_services)
    MONITORING_INTERVAL  = var.monitoring_interval
    ESCALATION_TIMEOUT   = var.escalation_timeout
    ESCALATION_CONTACT   = var.escalation_contact
    HEARTBEAT_BUCKET     = aws_s3_bucket.heartbeat.bucket
    HEARTBEAT_FILE       = "lambda-heartbeat.html"
  }
  lambda_environment_vars_acknowledgment_handler = {
    DYNAMODB_TABLE       = aws_dynamodb_table.github_status.name
    SLACK_WEBHOOK_URL    = var.slack_webhook_url
    SLACK_API_TOKEN      = var.slack_api_token
  }
  lambda_environment_vars_escalation_handler = {
    DYNAMODB_TABLE       = aws_dynamodb_table.github_status.name
    SLACK_WEBHOOK_URL    = var.slack_webhook_url
    ESCALATION_TIMEOUT   = var.escalation_timeout
    ESCALATION_CONTACT   = var.escalation_contact
  }
}
