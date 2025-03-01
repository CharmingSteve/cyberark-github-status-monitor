# CloudWatch Event Rule for GitHub Status Monitoring - Primary Region
resource "aws_cloudwatch_event_rule" "github_monitor_schedule" {
  name                = "github-status-monitor-schedule"
  description         = "Triggers the GitHub Status Monitor Lambda function"
  schedule_expression = "rate(${var.monitoring_interval} minutes)"
  
  tags = local.common_tags
}

# CloudWatch Event Target for GitHub Monitor Lambda - Primary Region
resource "aws_cloudwatch_event_target" "github_monitor_target" {
  rule      = aws_cloudwatch_event_rule.github_monitor_schedule.name
  target_id = "github-monitor"
  arn       = aws_lambda_function.github_monitor.arn
}

# Permission for CloudWatch to invoke the Lambda function - Primary Region
resource "aws_lambda_permission" "allow_cloudwatch_to_call_github_monitor" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.github_monitor_schedule.arn
}

# CloudWatch Event Rule for GitHub Status Monitoring - Secondary Region
resource "aws_cloudwatch_event_rule" "github_monitor_schedule_secondary" {
  provider          = aws.secondary
  name              = "github-status-monitor-schedule"
  description       = "Triggers the GitHub Status Monitor Lambda function in secondary region"
  schedule_expression = "rate(${var.monitoring_interval} minutes)"
  
  tags = local.common_tags
}

# CloudWatch Event Target for GitHub Monitor Lambda - Secondary Region
resource "aws_cloudwatch_event_target" "github_monitor_target_secondary" {
  provider  = aws.secondary
  rule      = aws_cloudwatch_event_rule.github_monitor_schedule_secondary.name
  target_id = "github-monitor"
  arn       = aws_lambda_function.github_monitor_secondary.arn
}

# Permission for CloudWatch to invoke the Lambda function - Secondary Region
resource "aws_lambda_permission" "allow_cloudwatch_to_call_github_monitor_secondary" {
  provider      = aws.secondary
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_monitor_secondary.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.github_monitor_schedule_secondary.arn
}

# CloudWatch Event Rule for Escalation Checking
resource "aws_cloudwatch_event_rule" "escalation_check_schedule" {
  name                = "github-escalation-check-schedule"
  description         = "Triggers the Escalation Handler Lambda function"
  schedule_expression = "rate(5 minutes)"
  
  tags = local.common_tags
}

# CloudWatch Event Target for Escalation Handler Lambda
resource "aws_cloudwatch_event_target" "escalation_check_target" {
  rule      = aws_cloudwatch_event_rule.escalation_check_schedule.name
  target_id = "escalation-handler"
  arn       = aws_lambda_function.escalation_handler.arn
}

# Permission for CloudWatch to invoke the Escalation Handler Lambda
resource "aws_lambda_permission" "allow_cloudwatch_to_call_escalation_handler" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.escalation_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.escalation_check_schedule.arn
}

# CloudWatch Alarm for GitHub Monitor Lambda Errors
resource "aws_cloudwatch_metric_alarm" "github_monitor_errors" {
  alarm_name          = "github-monitor-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.github_monitor.function_name
  }
  
  tags = local.common_tags
}
