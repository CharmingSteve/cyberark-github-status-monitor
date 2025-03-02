# S3 bucket for Lambda heartbeat file
resource "aws_s3_bucket" "heartbeat" {
  bucket = var.heartbeat_bucket_name
  
  tags = local.common_tags
}

# Enable versioning on the bucket
resource "aws_s3_bucket_versioning" "heartbeat" {
  bucket = aws_s3_bucket.heartbeat.id
  
  versioning_configuration {
    status = "Enabled"
  }
}
# Ensure S3 Block Public Access is disabled to allow public policies
resource "aws_s3_bucket_public_access_block" "heartbeat" {
  bucket = aws_s3_bucket.heartbeat.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
# Enable default encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "heartbeat" {
  bucket = aws_s3_bucket.heartbeat.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create initial heartbeat file
resource "aws_s3_object" "heartbeat_file" {
  bucket       = aws_s3_bucket.heartbeat.id
  key          = "lambda-heartbeat.html"
  content      = "<html><body>Lambda heartbeat: Initial setup</body></html>"
  content_type = "text/html"
  
  tags = local.common_tags
}

# Make the heartbeat file publicly accessible
resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.heartbeat.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.heartbeat.arn}/${aws_s3_object.heartbeat_file.key}"
      }
    ]
  })
}

# Configure CORS for the bucket
resource "aws_s3_bucket_cors_configuration" "heartbeat" {
  bucket = aws_s3_bucket.heartbeat.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
