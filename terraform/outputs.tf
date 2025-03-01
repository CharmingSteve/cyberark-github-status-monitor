output "primary_lambda_function_name" {
  description = "Name of the primary Lambda function"
  value       = aws_lambda_function.github_monitor.function_name
}

output "secondary_lambda_function_name" {
  description = "Name of the secondary Lambda function"
  value       = aws_lambda_function.github_monitor_secondary.function_name
}

output "acknowledgment_api_gateway_url" {
  description = "URL for the acknowledgment API Gateway"
  value       = "${aws_apigatewayv2_stage.lambda.invoke_url}/acknowledge"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for GitHub status"
  value       = aws_dynamodb_table.github_status.name
}

output "heartbeat_url" {
  description = "URL for the Lambda heartbeat file"
  value       = "https://${aws_s3_bucket.heartbeat.bucket_regional_domain_name}/${aws_s3_object.heartbeat_file.key}"
}

output "statuscake_contact_group_id" {
  description = "ID of the StatusCake contact group"
  value       = statuscake_contact_group.slack_alerts.id
}

output "statuscake_uptime_check_id" {
  description = "ID of the StatusCake uptime check"
  value       = statuscake_uptime_check.github_status.id
}
