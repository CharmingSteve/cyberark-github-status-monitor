terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    statuscake = {
      source  = "StatusCakeDev/statuscake"
      version = "~> 2.1.0"  # Updated to latest 2.x version
    }
  }
  required_version = ">= 1.0.0"
}

# Primary region provider
provider "aws" {
  region = var.primary_region
}

# Secondary region provider for high availability
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# StatusCake provider
provider "statuscake" {
  api_token = var.statuscake_api_key
}
