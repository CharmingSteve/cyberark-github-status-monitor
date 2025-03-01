import json
import os
import time
import urllib3
import boto3

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

# Clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
s3 = boto3.client('s3')
http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Monitors GitHub service statuses and sends alerts to Slack.
    """
    try:
        # Check heartbeat before proceeding
        check_heartbeat()

        # Get GitHub status
        status_data = get_github_status()

        # Process each service defined in GITHUB_SERVICES
        for service_name in GITHUB_SERVICES:
            component = next((comp for comp in status_data['components'] if comp['name'] == service_name), None)
            if component:
                process_github_service(component)

        # Update heartbeat after successful run
        update_heartbeat()

        return {
            'statusCode': 200,
            'body': json.dumps('GitHub status check completed successfully.')
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'An error occurred: {str(e)}')
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
