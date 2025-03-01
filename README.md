# GitHub Status Monitoring Solution

## Overview
This solution monitors GitHub's service status (Git Operations and API Requests) and sends notifications to Slack when outages occur. It includes an acknowledgment mechanism and escalation policy.

## Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform v1.0.0+
- Python 3.8+
- Slack workspace with webhook configured
- StatusCake account (free tier)

## Getting Started

### 1. Clone the Repository
```
git clone https://github.com/CharmingSteve/cyberark-github-status-monitor.git
cd cyberark-github-status-monitor
```

### 2. Slack Setup (Manual Steps)
1. Create a Slack workspace (if not already done)
2. Create a channel for alerts (e.g., #github-status)
3. Go to https://api.slack.com/apps and create a new app
4. Choose "From scratch" and name your app "GitHub Status Monitor"
5. Select your workspace and click "Create App"
6. In the app settings, click on "Incoming Webhooks" in the left sidebar
7. Toggle "Activate Incoming Webhooks" to On
8. Click "Add New Webhook to Workspace"
9. Select your alerts channel and click "Allow"
10. Copy the webhook URL - you'll need this for configuration

### 3. StatusCake Setup (Backup Monitoring)
1. Create a StatusCake Account:
   - Sign up for a free StatusCake account at https://www.statuscake.com/
   - The free tier is sufficient for our backup monitoring needs

2. Configure Webhook for Slack Integration:
   - In StatusCake, go to "Contact Groups"
   - Click "Add New Contact Group"
   - Name it "GitHub Status Alerts"
   - Under "Add Contact Method", select "WebHook"
   - Enter your Slack webhook URL (the same one from step 2)
   - Save the contact group

3. Create an Uptime Test:
   - Click "Add New Test" or "Create Test"
   - Select "Uptime Test" as the test type
   - Enter these settings:
     - Test Name: GitHub Status Monitor
     - Website URL: https://www.githubstatus.com/api/v2/summary.json
     - Check Rate: 5 minutes (or lowest available on free tier)
     - Test Type: HTTP
   - Under "Alert Settings", select the contact group you created
   - Save the test

4. Get API Credentials:
   - Go to Account → API Keys
   - Generate a new API key if one doesn't exist
   - Copy this key for use in our Terraform configuration

This provides a redundant monitoring system that will continue to function even if AWS experiences a multi-region outage, ensuring you're always notified of GitHub status changes.

### 4. S3 Bucket Setup for Terraform State

1. Create the S3 Bucket:
```bash
aws s3api create-bucket \
  --bucket cyberark-github-status-monitor \
  --region us-east-1
```

2. Enable Versioning:
```bash
aws s3api put-bucket-versioning \
  --bucket cyberark-github-status-monitor \
  --versioning-configuration Status=Enabled
```

3. Enable Default Encryption:
```bash
aws s3api put-bucket-encryption \
  --bucket cyberark-github-status-monitor \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

4. Block Public Access:
```bash
aws s3api put-public-access-block \
  --bucket cyberark-github-status-monitor \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

5. Configure Terraform Backend:
   - Edit `terraform/backend.tf` and update the bucket name to match your S3 bucket
   - Ensure the region matches your AWS region
   - Run `terraform init` to initialize the backend

### 5. Secret Management Setup

1. GitHub Secrets Configuration:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
     - `SLACK_WEBHOOK_URL`: Your Slack webhook URL
     - `STATUSCAKE_API_KEY`: Your StatusCake API key

2. Terraform Variables:
   - Update `terraform/variables.tf` with appropriate default values
   - Sensitive values will be pulled from GitHub Secrets during deployment

### 6. Infrastructure Deployment
1. Initialize Terraform:
```bash
cd terraform
terraform init
```

2. Review the deployment plan:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

This will deploy:
- Lambda functions in two AWS regions
- DynamoDB Global Tables for state tracking
- API Gateway for Slack interactions
- CloudWatch Events for scheduled monitoring
- StatusCake integration via the Terraform provider

### 7. Testing
1. Use the provided test script to simulate a GitHub outage:
```bash
./scripts/test.sh
```

2. Verify that notifications appear in your Slack channel
3. Test the acknowledgment mechanism by clicking the "I'm handling this" button
4. Test the StatusCake backup by temporarily disabling the AWS Lambda functions

## Architecture

This solution uses a multi-layered approach to ensure high availability:

1. **Primary Monitoring**: AWS Lambda functions deployed in multiple regions (us-east-1 and us-west-2) check GitHub's status API every 5 minutes and send alerts to Slack.

2. **State Management**: DynamoDB Global Tables replicated across regions store the current status and acknowledgment information.

3. **Backup Monitoring**: StatusCake provides an independent monitoring system that sends alerts directly to Slack using the same webhook URL, ensuring notifications even if AWS experiences a multi-region outage.

4. **Acknowledgment System**: When someone acknowledges an incident in Slack, their name is recorded in DynamoDB and a follow-up message is sent to the channel.

5. **Escalation System**: If no one acknowledges an incident within 15 minutes, an escalation notification is sent to ensure critical issues are addressed.

## CI/CD Pipeline

The included GitHub Actions workflows automate testing and deployment:

1. **Testing Workflow**: Runs on pull requests to validate changes
2. **Deployment Workflow**: Runs on merges to main branch to deploy infrastructure
3. **Security Scanning**: Checks for sensitive information and security vulnerabilities

## Infrastructure State Management

This project uses an S3 bucket for Terraform state management with native S3 locking (without DynamoDB).

### Why No DynamoDB for Terraform State?
1. Single-User Test Environment: 
   - This implementation is for a test/demo environment with a single operator
   - No risk of concurrent modifications that would require distributed locking

2. Terraform v1.10+ Support:
   - Recent Terraform versions support native S3 locking without DynamoDB
   - The `use_lockfile = true` setting enables this functionality

### Security Considerations
While we've simplified the Terraform state architecture, we maintain strong security practices:
1. S3 Bucket Encryption: All state files are encrypted at rest using AES-256
2. Versioning: Bucket versioning is enabled to prevent accidental state loss
3. Secure Credentials: All AWS credentials, Slack webhook URLs, and StatusCake API keys are stored as GitHub Secrets
4. Least Privilege: IAM roles follow the principle of least privilege

### Enterprise Considerations
In an enterprise environment, CyberArk Conjur could replace GitHub Secrets for enhanced security. CyberArk provides a dedicated GitHub Action (CyberArk Conjur Secret Fetcher) for secure secrets delivery, centralizing secrets management and providing advanced auditing capabilities.

## Production Considerations
For a production deployment, consider:
1. Adding DynamoDB for Terraform state locking in team environments
2. Implementing additional access controls and audit logging
3. Setting up state file backup procedures
4. Using CyberArk Conjur for enterprise-grade secrets management
5. Configuring additional notification channels beyond Slack
6. Implementing more sophisticated escalation procedures