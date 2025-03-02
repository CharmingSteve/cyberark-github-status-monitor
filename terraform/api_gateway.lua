// ...existing code...

resource "aws_apigatewayv2_integration" "acknowledgment_handler" {
  api_id                 = aws_apigatewayv2_api.lambda.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.primary_handler.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  
  timeout_milliseconds   = 30000
  connection_type       = "INTERNET"
  
  # Add health check configuration
  tls_config {
    server_name_to_verify = "execute-api.${var.primary_region}.amazonaws.com"
  }
}

# Secondary region integration
resource "aws_apigatewayv2_integration" "secondary_handler" {
  provider              = aws.secondary
  api_id               = aws_apigatewayv2_api.lambda.id
  integration_type     = "AWS_PROXY"
  integration_uri      = aws_lambda_function.secondary_handler.invoke_arn
  integration_method   = "POST"
  payload_format_version = "2.0"
}

# Health check route
resource "aws_apigatewayv2_route" "health_check" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.acknowledgment_handler.id}"
}
