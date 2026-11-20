terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "Región de la cuenta."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de los recursos."
  type        = string
  default     = "jfc"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "jfc-ecommerce"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

module "tfstate" {
  source = "../modules/private-bucket"

  name                               = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
  versioning                         = true
  noncurrent_version_expiration_days = 90
}

output "tfstate_bucket" {
  description = "Úsalo en: terraform init -backend-config=\"bucket=<valor>\""
  value       = module.tfstate.name
}
