# StatusCake monitoring (backup system)

# StatusCake Contact Group for alerts
resource "statuscake_contact_group" "slack_alerts" {
  name = "github-status-alerts"
  
  # Slack integration via webhook
  integrations = {
    slack = {
      url = var.slack_webhook_url
    }
  }
  
  # Optional: Include email addresses if needed as backup
  #email_addresses = var.alert_email_addresses
}

# StatusCake Uptime Check for GitHub Status
resource "statuscake_uptime_check" "github_status" {
  name           = "github-status-check"
  website_url    = "https://www.githubstatus.com"
  check_rate     = 300 # 5 minutes
  contact_groups = [statuscake_contact_group.slack_alerts.id]
  regions        = ["US", "EU"]
  
  confirmation   = 2
  trigger_rate   = 5
  
  http_check {
    follow_redirects = true
    validate_ssl     = true
  }
}
