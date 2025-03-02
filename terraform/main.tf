# Main Terraform configuration file
# This file serves as the entry point and coordinates other resources

locals {
  common_tags = {
    Project     = "GitHub Status Monitor"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
