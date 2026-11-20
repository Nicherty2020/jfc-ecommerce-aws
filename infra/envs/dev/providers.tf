terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Pendiente: estado remoto en S3.
  # backend "s3" {
  #   bucket       = "jfc-tfstate-<ID_CUENTA>"
  #   key          = "dev/edge.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "jfc-ecommerce"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
