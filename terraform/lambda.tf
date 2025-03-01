# Lambda functions - GitHub Monitor
resource "aws_lambda_function" "github_monitor" {
  function_name    = "github-status-monitor"
  filename         = data.archive_file.github_monitor_zip.output_path
  source_code_hash = data.archive_file.github_monitor_zip.output_base64sha256
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128
  role             = aws_iam_role.lambda_execution_role.arn
  
  environment {
    variables = local.lambda_environment_vars_github_monitor
  }
  
  tags = local.common_tags
}

resource "aws_lambda_function" "github_monitor_secondary" {
  provider        = aws.secondary
  function_name   = "github-status-monitor"
  filename        = data.archive_file.github_monitor_zip.output_path
  source_code_hash = data.archive_file.github_monitor_zip.output_base64sha256
  handler         = "main.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128
  role            = aws_iam_role.lambda_execution_role_secondary.arn
  
  environment {
    variables = local.lambda_environment_vars_github_monitor
  }
  
  tags = local.common_tags
}
# Lambda functions - Acknowledgment Handler
resource "aws_lambda_function" "acknowledgment_handler" {
  function_name    = "github-acknowledgment-handler"
  filename         = data.archive_file.acknowledgment_handler_zip.output_path
  source_code_hash = data.archive_file.acknowledgment_handler_zip.output_base64sha256
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128
  role             = aws_iam_role.lambda_execution_role.arn
  
  environment {
    variables = local.lambda_environment_vars_acknowledgment_handler
  }
  
  tags = local.common_tags
}
# Lambda functions - Escalation Handler
resource "aws_lambda_function" "escalation_handler" {
  function_name    = "github-escalation-handler"
  filename         = data.archive_file.escalation_handler_zip.output_path
  source_code_hash = data.archive_file.escalation_handler_zip.output_base64sha256
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128
  role             = aws_iam_role.lambda_execution_role.arn
  
  environment {
    variables = local.lambda_environment_vars_escalation_handler
  }
  
  tags = local.common_tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.acknowledgment_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
