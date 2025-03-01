# DynamoDB Global Table for GitHub status tracking
resource "aws_dynamodb_table" "github_status" {
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
    name               = "incident_index"
    hash_key           = "incident_id"
    projection_type    = "ALL"
    write_capacity     = 0
    read_capacity      = 0
  }
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  replica {
    region_name = var.secondary_region
  }
  
  tags = local.common_tags
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
  
  replica {
    region_name = var.secondary_region
  }
  
  tags = local.common_tags
}
