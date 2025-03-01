#!/bin/bash

# Test script to simulate a GitHub outage

# Set environment variables (replace with actual values)
export AWS_ACCESS_KEY_ID="your_aws_access_key_id"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_access_key"
export AWS_REGION="us-east-1"
export DYNAMODB_TABLE="github-status-monitor"
export SLACK_WEBHOOK_URL="your_slack_webhook_url"
export SLACK_API_TOKEN="your_slack_api_token"
export STATUSCAKE_API_KEY="your_statuscake_api_key"
export HEARTBEAT_BUCKET="github-monitor-heartbeat"
export HEARTBEAT_FILE="lambda-heartbeat.html"

# Simulate an outage
echo "Simulating GitHub outage..."

# Update DynamoDB to simulate a service outage
aws dynamodb put-item \
    --table-name "$DYNAMODB_TABLE" \
    --item '{"service_name": {"S": "Git Operations"}, "status": {"S": "major_outage"}, "timestamp": {"S": "2024-05-03 00:00:00 UTC"}}' \
    --region "$AWS_REGION"

# Invoke the GitHub Monitor Lambda
echo "Invoking GitHub Monitor Lambda..."
aws lambda invoke \
    --function-name github-status-monitor \
    --payload '{"test": "true"}' \
    output.txt \
    --region "$AWS_REGION"

# Check the result
echo "Lambda invocation result:"
cat output.txt

# Optionally, simulate a resolution later
# aws dynamodb put-item ... (similar to above, but with "operational" status)

echo "Test completed."
