aws_region = "us-east-1"
secondary_region = "us-west-2"

# S3 Bucket for Lambda Heartbeat
heartbeat_bucket_name = "github-monitor-heartbeat"

# Tags for AWS resources
common_tags = {
  Project     = "GitHub Monitor"
  Environment = "Production"
  Owner       = "DevOps Team"
}
