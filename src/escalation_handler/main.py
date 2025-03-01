import json
import os
import time
import boto3
import urllib3

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
ESCALATION_TIMEOUT = int(os.environ['ESCALATION_TIMEOUT'])
ESCALATION_CONTACT = os.environ['ESCALATION_CONTACT']

# Clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Checks for incidents that have not been acknowledged and escalates them.
    """
    try:
        escalate_unacknowledged_incidents()
        return {
            'statusCode': 200,
            'body': json.dumps('Escalation check completed.')
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
        }

def escalate_unacknowledged_incidents():
    """
    Escalates any incidents older than the configured timeout that haven't been acknowledged.
    """
    current_time = time.time()
    
    try:
        # Scan active incidents (status != 'operational')
        scan_response = table.scan(
            FilterExpression='attribute_not_exists(acknowledged_by)'
        )
        items = scan_response.get('Items', [])
        
        for item in items:
            timestamp = time.mktime(time.strptime(item['timestamp'], '%Y-%m-%d %H:%M:%S UTC'))
            
            # Check if incident has timed out
            if (current_time - timestamp) > (ESCALATION_TIMEOUT * 60):
                escalate_incident(item)

    except Exception as e:
        print(f"Error scanning DynamoDB: {e}")

def escalate_incident(item):
    """
    Escalates an incident by sending a message to the configured escalation
def escalate_incident(item):
    """
    Escalates an incident by sending a message to the configured escalation contact.
    """
    service_name = item['service_name']
    incident_id = item['incident_id']
    
    try:
        # Send escalation message to Slack
        message = {
            "text": f":rotating_light: *ESCALATION*: Incident {incident_id} for {service_name} has not been acknowledged. Escalating to {ESCALATION_CONTACT}."
        }
        
        encoded_data = json.dumps(message).encode('utf-8')
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=encoded_data,
            headers={'Content-type': 'application/json'}
        )
        print(f"Escalation message sent to Slack: {response.status}")

    except Exception as e:
        print(f"Error sending escalation message: {e}")
