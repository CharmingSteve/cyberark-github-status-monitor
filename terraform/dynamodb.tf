# DynamoDB Global Table for GitHub status tracking
resource "aws_dynamodb_table" "github_status_monitor" {
  name           = "github-status-monitor"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "service_name"
  range_key      = "timestamp"

  attribute {
    name = "service_name"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "incident_id"
    type = "S"
  }

  global_secondary_index {
    name               = "incident_id-index"
    hash_key          = "incident_id"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "service_name-index"
    hash_key           = "service_name"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "timestamp-index"
    hash_key           = "timestamp"
    projection_type    = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    ignore_changes = [ttl]
  }
}

# DynamoDB Table for incident acknowledgments
resource "aws_dynamodb_table" "incident_acknowledgments" {
  name           = "github-incident-acknowledgments"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "incident_id"
  
  attribute {
    name = "incident_id"
    type = "S"
  }
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  tags = local.common_tags
}
