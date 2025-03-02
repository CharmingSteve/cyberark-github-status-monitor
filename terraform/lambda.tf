data "archive_file" "github_monitor_zip" {
  type        = "zip"
  source_dir  = "./src/github_monitor"
  output_path = "./lambda_packages/github_monitor.zip"
}

data "archive_file" "acknowledgment_handler_zip" {
  type        = "zip"
  source_dir  = "./src/acknowledgment_handler"
  output_path = "./lambda_packages/acknowledgment_handler.zip"
}

data "archive_file" "escalation_handler_zip" {
  type        = "zip"
  source_dir  = "./src/escalation_handler"
  output_path = "./lambda_packages/escalation_handler.zip"
}

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

# Secondary region Lambda function
resource "aws_lambda_function" "github_monitor_secondary" {
  provider         = aws.secondary
  filename         = data.archive_file.github_monitor_zip.output_path
  function_name    = "github-status-monitor"
  role             = aws_iam_role.lambda_execution_role_secondary.arn
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

# API Gateway Integration for Acknowledgment Handler
resource "aws_apigatewayv2_integration" "acknowledgment_handler_integration" {
  api_id           = aws_apigatewayv2_api.lambda.id
  integration_type = "AWS_PROXY"
  
  integration_uri    = aws_lambda_function.acknowledgment_handler.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "acknowledgment_handler_route" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST /acknowledge"
  
  target = "integrations/${aws_apigatewayv2_integration.acknowledgment_handler_integration.id}"
}

resource "aws_lambda_permission" "api_gw_acknowledgment_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acknowledgment_handler.function_name
  principal     = "apigateway.amazonaws.com"
  
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
