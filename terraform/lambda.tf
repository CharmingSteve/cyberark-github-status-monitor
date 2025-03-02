locals {
  lambda_environment_vars_github_monitor = {
    DYNAMODB_TABLE      = aws_dynamodb_table.github_status.id
    SLACK_WEBHOOK_URL   = var.slack_webhook_url
    SLACK_API_TOKEN     = var.slack_api_token
    GITHUB_SERVICES     = jsonencode(var.github_services)
    MONITORING_INTERVAL = var.monitoring_interval
    ESCALATION_TIMEOUT  = var.escalation_timeout
    ESCALATION_CONTACT  = var.escalation_contact
    HEARTBEAT_BUCKET    = var.heartbeat_bucket_name
    HEARTBEAT_FILE      = "heartbeat.html"
  }

  lambda_environment_vars_acknowledgment_handler = {
    DYNAMODB_TABLE    = aws_dynamodb_table.github_status.id
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    SLACK_API_TOKEN   = var.slack_api_token
  }

  lambda_environment_vars_escalation_handler = {
    DYNAMODB_TABLE      = aws_dynamodb_table.github_status.id
    SLACK_WEBHOOK_URL   = var.slack_webhook_url
    ESCALATION_TIMEOUT  = var.escalation_timeout
    ESCALATION_CONTACT  = var.escalation_contact
  }
}

# Archive source code for Lambda functions
data "archive_file" "github_monitor_zip" {
  type        = "zip"
  source_dir  = "../src/github_monitor"
  output_path = "./lambda_packages/github_monitor.zip"
}

data "archive_file" "acknowledgment_handler_zip" {
  type        = "zip"
  source_dir  = "../src/acknowledgment_handler"
  output_path = "./lambda_packages/acknowledgment_handler.zip"
}

data "archive_file" "escalation_handler_zip" {
  type        = "zip"
  source_dir  = "../src/escalation_handler"
  output_path = "./lambda_packages/escalation_handler.zip"
}

# Primary region Lambda functions
resource "aws_lambda_function" "github_monitor" {
  filename         = data.archive_file.github_monitor_zip.output_path
  function_name    = "github-status-monitor"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.github_monitor_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_github_monitor
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "acknowledgment_handler" {
  filename         = data.archive_file.acknowledgment_handler_zip.output_path
  function_name    = "github-acknowledgment-handler"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.acknowledgment_handler_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_acknowledgment_handler
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "escalation_handler" {
  filename         = data.archive_file.escalation_handler_zip.output_path
  function_name    = "github-escalation-handler"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.escalation_handler_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_escalation_handler
  }

  tags = local.common_tags
}

# Secondary region Lambda function (Only deploys Lambda, no API Gateway)
resource "aws_lambda_function" "github_monitor_secondary" {
  provider         = aws.secondary
  filename         = data.archive_file.github_monitor_zip.output_path
  function_name    = "github-status-monitor-secondary"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.github_monitor_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_github_monitor
  }

  tags = local.common_tags
}

# Additional Secondary Region Lambda Functions
resource "aws_lambda_function" "acknowledgment_handler_secondary" {
  provider         = aws.secondary
  filename         = data.archive_file.acknowledgment_handler_zip.output_path
  function_name    = "github-acknowledgment-handler-secondary"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.acknowledgment_handler_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_acknowledgment_handler
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "escalation_handler_secondary" {
  provider         = aws.secondary
  filename         = data.archive_file.escalation_handler_zip.output_path
  function_name    = "github-escalation-handler-secondary"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.escalation_handler_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = local.lambda_environment_vars_escalation_handler
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gw_acknowledgment_handler" {
  count         = var.primary_region ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acknowledgment_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda.execution_arn}/*/*"
}

# Lambda permission for secondary region handler
resource "aws_lambda_permission" "api_gw_acknowledgment_handler_secondary" {
  provider      = aws.secondary
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acknowledgment_handler_secondary.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda.execution_arn}/*/*"
}

# API Gateway Integration for Primary Lambda
resource "aws_api_gateway_integration" "acknowledgment_handler_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda.id
  resource_id             = aws_api_gateway_resource.acknowledge.id
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.acknowledgment_handler.invoke_arn
  timeout_milliseconds    = 29000
}

# API Gateway Integration for Secondary Lambda (Failover)
resource "aws_api_gateway_integration" "acknowledgment_handler_integration_secondary" {
  rest_api_id             = aws_api_gateway_rest_api.lambda.id
  resource_id             = aws_api_gateway_resource.acknowledge.id
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.acknowledgment_handler_secondary.invoke_arn
  timeout_milliseconds    = 29000
  connection_type         = "INTERNET"
}
