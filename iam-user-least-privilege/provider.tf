# Configure Terraform settings with required providers
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# Default provider configuration
provider "aws" {
  region = var.region

  # Applied to every taggable resource created by this module
  default_tags {
    tags = {
      project          = "iam-user-least-privilege"
      provisioned_with = "opentofu"
    }
  }
}
