import json
import os
import time
import urllib3
import boto3
import urllib.parse
from datetime import datetime

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
SLACK_API_TOKEN = os.environ['SLACK_API_TOKEN']
GITHUB_SERVICES = json.loads(os.environ['GITHUB_SERVICES'])
MONITORING_INTERVAL = int(os.environ['MONITORING_INTERVAL'])
ESCALATION_TIMEOUT = int(os.environ['ESCALATION_TIMEOUT'])
ESCALATION_CONTACT = os.environ['ESCALATION_CONTACT']
HEARTBEAT_BUCKET = os.environ['HEARTBEAT_BUCKET']
HEARTBEAT_FILE = os.environ['HEARTBEAT_FILE']

# AWS Clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
http = urllib3.PoolManager()

def send_incident_to_slack(service_name, incident_id, description, is_test=False):
    """Stores incident in DynamoDB and sends Slack notification."""
    timestamp = datetime.utcnow().isoformat()
    
    # Check if incident already exists using the GSI
    response = table.query(
        IndexName='incident_id-index',
        KeyConditionExpression='incident_id = :incident_id',
        ExpressionAttributeValues={':incident_id': incident_id}
    )
    
    if response.get('Items'):
        print(f"Incident {incident_id} already exists. Skipping duplicate entry.")
        return
    
    # Step 1: Store the incident in DynamoDB
    table.put_item(
        Item={
            'service_name': service_name,
            'timestamp': timestamp,
            'incident_id': incident_id,
            'status': 'active',
            'description': description,
            'is_test': is_test,  # Mark test messages
            'acknowledged': False  # Add acknowledgment tracking
        }
    )
    
    # Step 2: Send Slack message with acknowledgment button
    slack_message = {
        "text": f"{'🟢 TEST: ' if is_test else '🔴 Incident Alert: '} {service_name} is experiencing an issue!",
        "attachments": [
            {
                "text": description,
                "fallback": "Acknowledge Incident",
                "callback_id": "incident_acknowledgment",
                "color": "#FF0000" if not is_test else "#36a64f",
                "actions": [
                    {
                        "name": "acknowledge",
                        "text": "Acknowledge",
                        "type": "button",
                        "value": incident_id
                    }
                ]
            }
        ]
    }
    
    response = http.request(
        'POST',
        SLACK_WEBHOOK_URL,
        body=json.dumps(slack_message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )
    
    print(f"Slack response: {response.status}, {response.data}")

def handle_acknowledgment(event):
    """Handles the acknowledgment of an incident from Slack."""
    try:
        # Parse the payload from the Slack button click
        body = event.get('body', '')
        if not body:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'No body in request'})
            }
        
        # The body is URL encoded, so we need to parse it
        parsed_body = urllib.parse.parse_qs(body)
        payload = json.loads(parsed_body['payload'][0])
        
        incident_id = payload['actions'][0]['value']
        user_name = payload['user']['name']
        user_id = payload['user']['id']
        
        # Find the incident in DynamoDB using the GSI
        response = table.query(
            IndexName='incident_id-index',
            KeyConditionExpression='incident_id = :incident_id',
            ExpressionAttributeValues={':incident_id': incident_id}
        )
        
        if not response.get('Items'):
            return {
                'statusCode': 404,
                'body': json.dumps({'message': f'Incident {incident_id} not found'})
            }
        
        incident = response['Items'][0]
        
        # Update the incident with acknowledgment info
        table.update_item(
            Key={
                'service_name': incident['service_name'],
                'timestamp': incident['timestamp']
            },
            UpdateExpression='SET acknowledged = :ack, acknowledged_by = :user, acknowledged_at = :time',
            ExpressionAttributeValues={
                ':ack': True,
                ':user': f"{user_name} ({user_id})",
                ':time': datetime.utcnow().isoformat()
            }
        )

        # Also store in the acknowledgments table
        ack_table = dynamodb.Table('github-incident-acknowledgments')
        ack_table.put_item(
            Item={
                'incident_id': incident_id,
                'acknowledged_by': f"{user_name} ({user_id})",
                'acknowledged_at': datetime.utcnow().isoformat(),
                'service_name': incident['service_name']
            }
        )
        
        # Send confirmation message back to Slack
        confirmation_message = {
            "text": f":white_check_mark: Incident `{incident_id}` has been acknowledged by {user_name}",
            "replace_original": False
        }
        
        http.request(
            'POST',
            payload['response_url'],
            body=json.dumps(confirmation_message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Acknowledgment processed successfully'})
        }
        
    except Exception as e:
        print(f"Error processing acknowledgment: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Error processing acknowledgment: {str(e)}'})
        }

def lambda_handler(event, context):
    """Main Lambda entry point."""
    # Check if this is an acknowledgment from Slack
    if event.get('requestContext', {}).get('resourcePath') == '/acknowledge':
        return handle_acknowledgment(event)
        
    # If not an acknowledgment, proceed with the original monitoring logic
    is_test = event.get('test', False)
    
    for service_name in GITHUB_SERVICES:
        incident_id = f"test-incident-{int(time.time())}" if is_test else f"incident-{int(time.time())}"
        description = f"Service {service_name} is {'TESTING alert.' if is_test else 'down. Investigating.'}"
        send_incident_to_slack(service_name, incident_id, description, is_test=is_test)
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Incident notifications sent'})
    }

def check_heartbeat():
    """
    Checks the heartbeat file in S3 to ensure the Lambda function is running.
    """
    try:
        response = s3.get_object(Bucket=HEARTBEAT_BUCKET, Key=HEARTBEAT_FILE)
        content = response['Body'].read().decode('utf-8')
        print(f"Heartbeat file content: {content}")
    except Exception as e:
        print(f"Heartbeat check failed: {e}")
        raise Exception("Lambda heartbeat check failed. Failing before GitHub status check.")

def update_heartbeat():
    """
    Updates the heartbeat file in S3 to confirm the Lambda function is still running.
    """
    try:
        timestamp = time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())
        content = f"<html><body>Lambda heartbeat: Last updated {timestamp}</body></html>"
        s3.put_object(Bucket=HEARTBEAT_BUCKET, Key=HEARTBEAT_FILE, Body=content.encode('utf-8'), ContentType='text/html', ACL='public-read')
        print(f"Heartbeat file updated successfully.")
    except Exception as e:
        print(f"Error updating heartbeat file: {e}")
        raise Exception("Failed to update Lambda heartbeat.")

def get_github_status():
    """
    Fetches GitHub status from the public API.
    """
    try:
        url = 'https://www.githubstatus.com/api/v2/summary.json'
        response = http.request('GET', url)
        data = json.loads(response.data.decode('utf-8'))
        return data
    except Exception as e:
        print(f"Error fetching GitHub status: {e}")
        raise Exception("Failed to fetch GitHub status.")

def process_github_service(component):
    """
    Processes a specific GitHub service component.
    """
    service_name = component['name']
    current_status = component['status']
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())
    
    incident = None
    if component.get('incident_updates'):
        incident = component.get('incident_updates')[0]

    # Check if the service is already in DynamoDB
    existing_status = get_service_status(service_name)

    if existing_status:
        # Check if the status has changed
        if existing_status['status'] != current_status:
            handle_status_change(service_name, current_status, timestamp, incident)
    else:
        # Add the new service to DynamoDB
        add_new_service(service_name, current_status, timestamp, incident)

def get_service_status(service_name):
    """
    Retrieves the current status of a service from DynamoDB.
    """
    try:
        response = table.get_item(Key={'service_name': service_name, 'timestamp': 'latest'})
        return response.get('Item')
    except Exception as e:
        print(f"Error retrieving service status: {e}")
        return None

def handle_status_change(service_name, current_status, timestamp, incident):
    """
    Handles a change in service status.
    """
    print(f"Status change detected for {service_name}: {current_status}")

    # Determine if there is an active incident
    if incident:
        incident_id = incident.get('id')
    else:
        incident_id = None

    if current_status != 'operational':
        # Report new incident and escalation
        if incident_id:
            send_slack_message(service_name, current_status, incident)
            add_new_service(service_name, current_status, timestamp, incident)
            create_incident(service_name, current_status, timestamp, incident)
        else:
            print(f"No incident found for {service_name} with status {current_status}")

    elif current_status == 'operational':
        if incident_id:
            # Incident is resolved
            update_incident_resolution(service_name, current_status, timestamp)
        else:
            clear_incident(service_name, current_status, timestamp)

def create_incident(service_name, current_status, timestamp, incident):
    try:
        incident_id = incident['id']
        acknowledgment = {'incident_id': incident_id}
    except Exception as e:
        print(f"Error generating acknowledgment button: {e}")

def clear_incident(service_name, current_status, timestamp):
    """
    Clears incident data from the DynamoDB for the service when status returns to operational.
    """
    try:
        # Update latest entry
        table.put_item(Item={
            'service_name': service_name,
            'status': current_status,
            'timestamp': 'latest',
            'incident_id': None
        })

        print(f"Incident cleared for {service_name}.")
    except Exception as e:
        print(f"Error updating the DynamoDB table: {e}")

def add_new_service(service_name, current_status, timestamp, incident):
    """
    Adds a new service to DynamoDB.
    """
    try:
        if incident:
            incident_id = incident['id']
        else:
            incident_id = None

        table.put_item(Item={
            'service_name': service_name,
            'status': current_status,
            'timestamp': 'latest',
            'incident_id': incident_id
        })

        table.put_item(Item={
            'service_name': service_name,
            'status': current_status,
            'timestamp': timestamp,
            'incident_id': incident_id
        })
        print(f"New service {service_name} added with status {current_status}.")

    except Exception as e:
        print(f"Error adding new service: {e}")

def update_incident_resolution(service_name, current_status, timestamp):
    """
    Marks an incident as resolved.
    """
    try:
        incident_id = table.get_item(Key={'service_name': service_name, 'timestamp': 'latest'}).get('Item').get('incident_id')

        if incident_id:
            # Update latest entry
            table.put_item(Item={
                'service_name': service_name,
                'status': current_status,
                'timestamp': 'latest',
                'incident_id': None
            })

        # Send a resolved notification
        send_resolution_message(service_name)

        print(f"Incident {incident_id} resolved for {service_name}.")

    except Exception as e:
        print(f"Error updating incident resolution: {e}")

def send_resolution_message(service_name):
    """
    Sends a message to Slack that the service is resolved.
    """
    try:
        # Send message to Slack
        message = {
            "text": f":white_check_mark: *RESOLVED*: {service_name} is now operational."
        }

        encoded_data = json.dumps(message).encode('utf-8')
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=encoded_data,
            headers={'Content-type': 'application/json'}
        )
        print(f"Slack notification sent: {response.status}")

    except Exception as e:
        print(f"Error sending Slack notification: {e}")

def generate_acknowledgment_button(incident_id):
    """
    Generates an acknowledgment button.
    """
    try:
        # Build the acknowledgment button
        blocks = [
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "text": "Acknowledge",
                            "emoji": True
                        },
                        "style": "primary",
                        "action_id": "acknowledge_incident",
                        "value": incident_id
                    }
                ]
            }
        ]

        return blocks
    except Exception as e:
        print(f"Error generating acknowledgment button: {e}")

def send_slack_message(service_name, current_status, incident):
    """
    Sends a message to Slack about the GitHub service status.
    """
    try:
        print(f"Attempting to send Slack message for {service_name}")  # Debug print
        message_text = f":red_circle: *{current_status.upper()}*: {service_name} - {incident['shortlink']}\n{incident['body']}"
        
        blocks = [
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": message_text
                }
            },
        ]

        if incident.get('id'):
            blocks.extend(generate_acknowledgment_button(incident.get('id')))

        # Send message to Slack
        message = {
            "text": f"{current_status.upper()}: {service_name} - {incident['shortlink']}",
            "blocks": blocks
        }

        print(f"Sending to Slack webhook: {message}")  # Debug print
        encoded_data = json.dumps(message).encode('utf-8')
        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=encoded_data,
            headers={'Content-type': 'application/json'}
        )
        print(f"Slack response status: {response.status}")  # Debug print
        print(f"Slack response data: {response.data}")  # Debug print

    except Exception as e:
        print(f"Error sending Slack notification: {str(e)}")  # Detailed error
        raise  # Re-raise to see in CloudWatch
