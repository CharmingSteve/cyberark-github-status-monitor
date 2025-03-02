# API Gateway for Slack Acknowledgment
resource "aws_apigatewayv2_api" "lambda" {
  name          = "github-monitor-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
  
  tags = local.common_tags
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "lambda" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "prod"
  auto_deploy = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
  
  tags = local.common_tags
}

# API Gateway Route
variable "handler_function_name" {
  type        = string
  description = "Name of the Lambda function to handle API Gateway requests"
  default     = "acknowledgment_handler"
}

resource "aws_apigatewayv2_integration" "acknowledgment_handler" {
  api_id                 = aws_apigatewayv2_api.lambda.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function[var.handler_function_name].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "acknowledgment_handler" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST /acknowledge"
  target    = "integrations/${aws_apigatewayv2_integration.acknowledgment_handler.id}"
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
  
  tags = local.common_tags
}
