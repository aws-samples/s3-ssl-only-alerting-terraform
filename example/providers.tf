terraform {
  required_version = "~> 1.0.5"
  required_providers {
    # aws = "~> 3.50.0"
  }
}

provider "aws" {
  default_tags {
    tags = {
      DeployedBy = "Terraform"
      Environment = "dev"
    }
    
  }

  region = "eu-west-1"
}