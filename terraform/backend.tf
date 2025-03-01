
terraform {
  backend "s3" {
    bucket       = "cyberark-github-status-monitor"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # For Terraform v1.10+ native S3 locking
  }
}

