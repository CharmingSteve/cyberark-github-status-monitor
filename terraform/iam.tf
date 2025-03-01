# IAM role for Lambda execution in primary region
resource "aws_iam_role" "lambda_execution_role" {
  name = "github-monitor-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM role for Lambda execution in secondary region
resource "aws_iam_role" "lambda_execution_role_secondary" {
  provider = aws.secondary
  name     = "github-monitor-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM policy for Lambda to access DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "github-monitor-lambda-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          aws_dynamodb_table.github_status.arn,
          "${aws_dynamodb_table.github_status.arn}/index/*",
          aws_dynamodb_table.incident_acknowledgments.arn
        ]
      }
    ]
  })
}

# IAM policy for Lambda to access S3
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "github-monitor-lambda-s3-policy"
  description = "Policy for Lambda to access S3 heartbeat bucket"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.heartbeat.arn,
          "${aws_s3_bucket.heartbeat.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for Lambda to write logs
resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "github-monitor-lambda-logging-policy"
  description = "Policy for Lambda to write logs to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policies to primary region role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

# Attach policies to secondary region role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach_secondary" {
  provider   = aws.secondary
  role       = aws_iam_role.lambda_execution_role_secondary.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach_secondary" {
  provider   = aws.secondary
  role       = aws_iam_role.lambda_execution_role_secondary.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attach_secondary" {
  provider   = aws.secondary
  role       = aws_iam_role.lambda_execution_role_secondary.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}
