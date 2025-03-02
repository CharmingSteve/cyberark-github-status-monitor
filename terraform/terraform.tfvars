# Define whether this deployment is for the primary region
# Set to `true` in the primary region and `false` in the secondary region
primary_region = true

# AWS Region (Update accordingly)
aws_region = "us-east-1"

# Secondary Region (Only used for multi-region setup)
secondary_aws_region = "us-west-2"

# S3 Bucket for Lambda Heartbeat File
heartbeat_bucket_name = "github-monitor-heartbeat"

# Common Tags for AWS Resources
common_tags = {
  Project     = "GitHub Monitor"
  Environment = "Production"
  Owner       = "DevOps Team"
}

# Lambda Memory & Timeout Defaults
lambda_memory_size  = 128
lambda_timeout      = 30

# DynamoDB Table Names
dynamodb_table_github_status              = "github-status"
dynamodb_table_incident_acknowledgments   = "incident-acknowledgments"

# API Gateway Settings
api_gateway_stage_name = "prod"

# Logging Configuration
log_retention_days = 30
