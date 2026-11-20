module "ecommerce" {
  source = "../../modules/ecommerce"

  project     = "jfc"
  environment = "prod"

  alarm_email                 = var.alarm_email
  domain_name                 = var.domain_name
  hosted_zone_name            = var.hosted_zone_name
  ses_identity                = var.ses_identity
  ses_from_address            = var.ses_from_address
  cognito_email_via_ses       = var.cognito_email_via_ses
  deletion_protection         = var.deletion_protection
  force_destroy_bucket        = var.force_destroy_bucket
  log_retention_days          = var.log_retention_days
  kms_deletion_window_days    = var.kms_deletion_window_days
  secret_recovery_window_days = var.secret_recovery_window_days
  pricing_plan_tier           = var.pricing_plan_tier
  waf_rate_limit              = var.waf_rate_limit
  api_throttling_rate_limit   = var.api_throttling_rate_limit
  api_throttling_burst_limit  = var.api_throttling_burst_limit
  webhook_signature_header    = var.webhook_signature_header
  reserved_concurrency        = var.reserved_concurrency
  sqs_max_concurrency         = var.sqs_max_concurrency
}

output "site_url" {
  value = module.ecommerce.site_url
}

output "api_execute_url" {
  value = module.ecommerce.api_execute_url
}

output "cloudfront_distribution_id" {
  value = module.ecommerce.cloudfront_distribution_id
}

output "frontend_bucket" {
  value = module.ecommerce.frontend_bucket
}

output "cognito_user_pool_id" {
  value = module.ecommerce.cognito_user_pool_id
}

output "cognito_client_id" {
  value = module.ecommerce.cognito_client_id
}

output "payments_secret_name" {
  value = module.ecommerce.payments_secret_name
}

output "lambda_functions" {
  value = module.ecommerce.lambda_functions
}

output "dashboard" {
  value = module.ecommerce.dashboard
}
