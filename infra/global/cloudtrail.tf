locals {
  trail_name = "${var.project}-management"
  trail_arn  = "arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/${local.trail_name}"
}

module "cloudtrail_bucket" {
  source = "../modules/private-bucket"

  name            = "${var.project}-cloudtrail-${local.account_id}"
  versioning      = false
  expiration_days = var.cloudtrail_retention_days

  extra_policy_statements = [
    {
      Sid       = "CloudTrailLeeACL"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:GetBucketAcl"
      Resource  = "arn:aws:s3:::${var.project}-cloudtrail-${local.account_id}"
      Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
    },
    {
      Sid       = "CloudTrailEscribe"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "arn:aws:s3:::${var.project}-cloudtrail-${local.account_id}/AWSLogs/${local.account_id}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl"  = "bucket-owner-full-control"
          "aws:SourceArn" = local.trail_arn
        }
      }
    },
  ]
}

resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = module.cloudtrail_bucket.name
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [module.cloudtrail_bucket]
}
