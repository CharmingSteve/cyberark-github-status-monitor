# Single IAM role for Lambda execution across all regions
resource "aws_iam_role" "lambda_execution_role" {
  name = "github-monitor-lambda-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda to access DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "github-monitor-lambda-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "${aws_dynamodb_table.github_status_monitor.arn}",
            "${aws_dynamodb_table.github_status_monitor.arn}/index/*",
            "arn:aws:dynamodb:us-east-1:701355440535:table/github_monitor_data_store/index/incident_id-index"
          ]
        }
      ]
    }
  )
}

# IAM policy for Lambda to access S3
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "github-monitor-lambda-s3-policy"
  description = "Policy for Lambda to access S3 heartbeat bucket"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
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
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
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

# Attach policies to the single IAM role
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

# The following resources were REMOVED
# resource "aws_iam_policy" "github_monitor_lambda_policy" { ... }
# resource "aws_iam_role_policy_attachment" "github_monitor_lambda_policy_attachment" { ... }

# The following resources were added to lambda_dynamodb_policy
# "arn:aws:dynamodb:us-east-1:701355440535:table/github_monitor_data_store/index/incident_id-index"
