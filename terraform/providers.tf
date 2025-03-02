terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Primary region provider
provider "aws" {
  region = var.aws_region
}

# Secondary region provider for high availability
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
