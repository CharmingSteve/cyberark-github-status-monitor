import json
import os
import boto3

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SLACK_API_TOKEN = os.environ['SLACK_API_TOKEN']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']

# Clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)

def acknowledge_incident(incident_id, user, user_name):  # Add user_name parameter
    """
    Acknowledges an incident in DynamoDB and sends a follow-up message to Slack.
    """
    try:
        # Acknowledge in DynamoDB
        table.put_item(Item={
            'incident_id': incident_id,
            'acknowledged_by': user,
            'user_name': user_name  # Add this line to store username
        })

        # Send Slack confirmation message
        send_acknowledgment_confirmation(incident_id, user_name)  # Use user_name instead of user
        return {
            'statusCode': 200,
            'body': json.dumps('Incident acknowledgment processed successfully.')
        }
    except Exception as e:
        print(f"Error acknowledging incident: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
        }

def send_acknowledgment_confirmation(incident_id, user):
    """
    Sends a follow-up message to Slack confirming the acknowledgment.
    """
    try:
        message = {
            "text": f":eyes: {user} is handling incident {incident_id}."
        }
        
        encoded_data = json.dumps(message).encode('utf-8')
        
        # Make a POST request to the Slack webhook URL
        http = urllib3.PoolManager()
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=encoded_data,
            headers={'Content-type': 'application/json'}
        )
        print(f"Slack confirmation message sent: {response.status}")

    except Exception as e:
        print(f"Error sending Slack confirmation message: {e}")
