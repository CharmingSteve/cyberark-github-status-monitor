# StatusCake Uptime Check for GitHub Status
resource "statuscake_uptime_check" "github_status" {
  name           = "GitHub Status Monitor"
  check_rate     = 300  # 5 minutes
  confirmation   = 2    # Require confirmation from multiple locations
  regions        = ["US", "EU"]  # Monitor from multiple regions
  contact_groups = [statuscake_contact_group.slack_alerts.id]
  test_type      = "HTTP"
  website_url    = "https://www.githubstatus.com/api/v2/summary.json"

  http_check {
    follow_redirects = true
    validate_ssl     = true
  }
}
