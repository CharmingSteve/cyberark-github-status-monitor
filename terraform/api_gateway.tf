resource "aws_api_gateway_rest_api" "lambda" {
  name        = "github-status-api"
  description = "API Gateway for GitHub Status Monitor"
}

resource "aws_api_gateway_resource" "acknowledge" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  parent_id   = aws_api_gateway_rest_api.lambda.root_resource_id
  path_part   = "acknowledge"
}

resource "aws_api_gateway_method" "acknowledge_post" {
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  resource_id   = aws_api_gateway_resource.acknowledge.id
  http_method   = "POST"
  authorization = "NONE"
}

# Add GET method
resource "aws_api_gateway_method" "acknowledge_get" {
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  resource_id   = aws_api_gateway_resource.acknowledge.id
  http_method   = "GET"
  authorization = "NONE"
}

# Enable CORS
resource "aws_api_gateway_method" "acknowledge_options" {
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  resource_id   = aws_api_gateway_resource.acknowledge.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  resource_id   = aws_api_gateway_resource.acknowledge.id
  http_method   = aws_api_gateway_method.acknowledge_options.http_method
  status_code   = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  resource_id = aws_api_gateway_resource.acknowledge.id
  http_method = aws_api_gateway_method.acknowledge_options.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options" {
  rest_api_id   = aws_api_gateway_rest_api.lambda.id
  resource_id   = aws_api_gateway_resource.acknowledge.id
  http_method   = aws_api_gateway_method.acknowledge_options.http_method
  status_code   = aws_api_gateway_method_response.options_200.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Method Response
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  resource_id = aws_api_gateway_resource.acknowledge.id
  http_method = aws_api_gateway_method.acknowledge_post.http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integration Responses
resource "aws_api_gateway_integration_response" "primary_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  resource_id = aws_api_gateway_resource.acknowledge.id
  http_method = aws_api_gateway_method.acknowledge_post.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  selection_pattern = ""  # Default response

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.acknowledgment_handler_integration
  ]
}

resource "aws_api_gateway_integration_response" "secondary_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  resource_id = aws_api_gateway_resource.acknowledge.id
  http_method = aws_api_gateway_method.acknowledge_post.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  selection_pattern = ".*Task timed out.*"  # Trigger secondary on timeout

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.acknowledgment_handler_integration_secondary
  ]
}

# GET method integration
resource "aws_api_gateway_integration" "acknowledgment_handler_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lambda.id
  resource_id             = aws_api_gateway_resource.acknowledge.id
  http_method             = aws_api_gateway_method.acknowledge_get.http_method
  integration_http_method = "POST"  # Lambda requires POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.acknowledgment_handler.invoke_arn
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.lambda.id
  
  depends_on = [
    aws_api_gateway_integration.acknowledgment_handler_integration,
    aws_api_gateway_integration.acknowledgment_handler_integration_secondary,
    aws_api_gateway_integration.acknowledgment_handler_get_integration,
    aws_api_gateway_integration_response.primary_integration_response,
    aws_api_gateway_integration_response.secondary_integration_response,
    aws_api_gateway_method_response.response_200
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id  = aws_api_gateway_rest_api.lambda.id
  stage_name   = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp               = "$context.identity.sourceIp"
      requestTime            = "$context.requestTime"
      protocol               = "$context.protocol"
      httpMethod             = "$context.httpMethod"
      resourcePath           = "$context.resourcePath"
      routeKey               = "$context.routeKey"
      status                 = "$context.status"
      responseLength         = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  depends_on = [
    aws_api_gateway_account.main
  ]
}
