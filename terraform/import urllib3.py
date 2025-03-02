import urllib3
import boto3
import os
import time
import json

# Add new environment variables
PRIMARY_REGION = os.environ['PRIMARY_REGION']
SECONDARY_REGION = os.environ['SECONDARY_REGION']
FAILOVER_THRESHOLD = int(os.environ['FAILOVER_THRESHOLD'])

def check_primary_region_health():
    """
    Checks the health of the primary region.
    Returns True if healthy, False otherwise.
    """
    try:
        # Check API Gateway health endpoint
        api_url = f"https://{os.environ['API_GATEWAY_ID']}.execute-api.{PRIMARY_REGION}.amazonaws.com/prod/health"
        response = http.request('GET', api_url, timeout=5.0)
        return response.status == 200
    except:
        return False

def failover_to_secondary():
    """
    Implements failover to secondary region.
    """
    try:
        # Update API Gateway route to point to secondary region
        api_client = boto3.client('apigatewayv2')
        api_client.update_route(
            ApiId=os.environ['API_GATEWAY_ID'],
            RouteId=os.environ['ROUTE_ID'],
            Target=f"integrations/{os.environ['SECONDARY_INTEGRATION_ID']}"
        )
        send_slack_message("FAILOVER", "System", "Failing over to secondary region due to primary region issues.")
    except Exception as e:
        print(f"Failover failed: {e}")

def lambda_handler(event, context):
    """
    Modified handler with health checking and failover.
    """
    try:
        # Check primary region health
        health_checks_failed = 0
        for _ in range(FAILOVER_THRESHOLD):
            if not check_primary_region_health():
                health_checks_failed += 1
            time.sleep(1)

        # Trigger failover if threshold exceeded
        if health_checks_failed >= FAILOVER_THRESHOLD:
            failover_to_secondary()
            
        # ...existing code...
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
        }
