import json
import os
import boto3
import urllib.parse
import time
from boto3.dynamodb.conditions import Key  # Import Key for GSI queries

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event, indent=2)}") # Log full event for debugging

        # Ensure 'body' exists and is a string
        if 'body' not in event or not event['body']:
            print("Error: No body found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No body found in request', 'debug_received_event': event})
            }

        raw_body = event['body']
        print(f"Raw body received: {raw_body}") # Debug log the body

        # Handle Slack's form-encoded payload or raw JSON from AWS CLI
        if isinstance(raw_body, str):
            if raw_body.startswith("payload="):
                body = urllib.parse.parse_qs(raw_body)
                if 'payload' not in body:
                    print("Error: 'payload' key missing in form-encoded body")
                    return {
                        'statusCode': 400,
                        'body': json.dumps({'error': "Missing 'payload' key in request", 'debug_received_event': event})
                    }
                payload = json.loads(body['payload'][0])
            else:
                payload = json.loads(raw_body)
        else:
            payload = raw_body

        print(f"Parsed payload: {json.dumps(payload, indent=2)}")

        # Extract incident ID and user from payload
        actions = payload.get('actions', [])
        if not actions:
            print("Error: No actions found in payload")
            return {'statusCode': 400, 'body': json.dumps({'error': 'No actions found in payload'})}

        incident_id = actions[0].get('value')

        # Extract user information robustly
        user = None
        if 'user' in payload and 'username' in payload['user']:
            user = payload['user']['username']
        elif 'user' in payload and 'id' in payload['user']:
            user = payload['user']['id']
        elif 'user_id' in payload:
            user = payload['user_id']
        else:
            print("Warning: Could not find user information in payload.")
            user = 'unknown_user' # Provide a default value

        # Get the username if available
        user_name = payload['user'].get('name', user) if 'user' in payload else user

        print(f"Incident ID: {incident_id}, User: {user}")

        # Query DynamoDB using GSI to find matching incident_id
        response = table.query(
            IndexName="incident_id-index",
            KeyConditionExpression=Key("incident_id").eq(incident_id)
        )

        items = response.get('Items', [])
        if not items:
            print("No matching incident found")
            return {'statusCode': 404, 'body': json.dumps({'error': 'Incident not found'})}

        # Update the first matching item found
        item = items[0]
        table.update_item(
            Key={
                'service_name': item['service_name'],
                'timestamp': item['timestamp'] # Must include both partition and sort keys
            },
            UpdateExpression="SET acknowledged_by = :user, acknowledged_at = :time",
            ExpressionAttributeValues={
                ':user': user,
                ':time': time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())
            }
        )

        # Call acknowledge_incident from main.py to store username
        from main import acknowledge_incident
        acknowledge_incident(incident_id, user, user_name)

        return {
            'statusCode': 200,
            'body': json.dumps({'message': f'Incident acknowledged by {user_name} successfully'})
        }

    except Exception as e:
        print(f"Error handling acknowledgment: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
