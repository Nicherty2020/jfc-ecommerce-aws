data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_route53_zone" "this" {
  count = var.hosted_zone_name != null ? 1 : 0
  name  = var.hosted_zone_name
}

locals {
  name             = "${var.project}-${var.environment}"
  ses_identity_arn = "arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/${var.ses_identity}"
}

module "platform" {
  source = "../platform"

  project                  = var.project
  environment              = var.environment
  alarm_email              = var.alarm_email
  kms_deletion_window_days = var.kms_deletion_window_days
}

resource "aws_secretsmanager_secret" "payments_gateway" {
  name                    = "${local.name}/payments/gateway"
  description             = "JSON con api_key y webhook_secret de la pasarela de pagos"
  kms_key_id              = module.platform.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_days
}

module "identity" {
  source = "../identity"

  project             = var.project
  environment         = var.environment
  deletion_protection = var.deletion_protection
  ses_identity_arn    = var.cognito_email_via_ses ? local.ses_identity_arn : null
  ses_from_address    = var.cognito_email_via_ses ? var.ses_from_address : null
}

module "catalog" {
  source = "../microservice"

  project             = var.project
  environment         = var.environment
  service             = "catalog"
  kms_key_arn         = module.platform.kms_key_arn
  alarm_topic_arn     = module.platform.alarm_topic_arn
  runtime             = var.lambda_runtime
  memory_size         = var.lambda_memory_mb
  log_retention_days  = var.log_retention_days
  deletion_protection = var.deletion_protection
}

module "users" {
  source = "../microservice"

  project             = var.project
  environment         = var.environment
  service             = "users"
  kms_key_arn         = module.platform.kms_key_arn
  alarm_topic_arn     = module.platform.alarm_topic_arn
  runtime             = var.lambda_runtime
  memory_size         = var.lambda_memory_mb
  log_retention_days  = var.log_retention_days
  deletion_protection = var.deletion_protection
}

module "orders" {
  source = "../microservice"

  project              = var.project
  environment          = var.environment
  service              = "orders"
  kms_key_arn          = module.platform.kms_key_arn
  alarm_topic_arn      = module.platform.alarm_topic_arn
  runtime              = var.lambda_runtime
  memory_size          = var.lambda_memory_mb
  log_retention_days   = var.log_retention_days
  deletion_protection  = var.deletion_protection
  event_bus_name       = module.platform.event_bus_name
  event_bus_arn        = module.platform.event_bus_arn
  publishes_events     = true
  alarm_on_any_error   = true
  reserved_concurrency = var.reserved_concurrency.orders
  schedule_expression  = "rate(5 minutes)"

  queues = {
    events = {
      event_types     = ["StockRejected", "PaymentReady", "PaymentApproved", "PaymentFailed"]
      max_concurrency = var.sqs_max_concurrency.orders
    }
  }

  table_gsis = [{ name = "por-estado", hash_key = "gsi1pk", range_key = "gsi1sk" }]

  environment_variables = {
    CATALOG_FUNCTION_ARN = module.catalog.alias_arn
  }

  extra_policy_statements = [{
    sid       = "ConsultarPrecioEnCatalogo"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.catalog.alias_arn]
  }]
}

module "inventory" {
  source = "../microservice"

  project              = var.project
  environment          = var.environment
  service              = "inventory"
  kms_key_arn          = module.platform.kms_key_arn
  alarm_topic_arn      = module.platform.alarm_topic_arn
  runtime              = var.lambda_runtime
  memory_size          = var.lambda_memory_mb
  log_retention_days   = var.log_retention_days
  deletion_protection  = var.deletion_protection
  event_bus_name       = module.platform.event_bus_name
  event_bus_arn        = module.platform.event_bus_arn
  publishes_events     = true
  alarm_on_any_error   = true
  reserved_concurrency = var.reserved_concurrency.inventory

  queues = {
    events = {
      event_types     = ["OrderCreated", "OrderConfirmed", "OrderCancelled"]
      max_concurrency = var.sqs_max_concurrency.inventory
    }
  }
}

module "payments" {
  source = "../microservice"

  project             = var.project
  environment         = var.environment
  service             = "payments"
  kms_key_arn         = module.platform.kms_key_arn
  alarm_topic_arn     = module.platform.alarm_topic_arn
  runtime             = var.lambda_runtime
  memory_size         = var.lambda_memory_mb
  log_retention_days  = var.log_retention_days
  deletion_protection = var.deletion_protection
  event_bus_name      = module.platform.event_bus_name
  event_bus_arn       = module.platform.event_bus_arn
  publishes_events    = true
  alarm_on_any_error  = true

  queues = {
    events  = { event_types = ["StockReserved"] }
    webhook = { event_types = [] } # la llena API Gateway
  }

  environment_variables = {
    GATEWAY_SECRET_ARN = aws_secretsmanager_secret.payments_gateway.arn
  }

  extra_policy_statements = [{
    sid       = "LeerSecretoDeLaPasarela"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.payments_gateway.arn]
  }]
}

module "notifications" {
  source = "../microservice"

  project            = var.project
  environment        = var.environment
  service            = "notifications"
  kms_key_arn        = module.platform.kms_key_arn
  alarm_topic_arn    = module.platform.alarm_topic_arn
  runtime            = var.lambda_runtime
  memory_size        = var.lambda_memory_mb
  log_retention_days = var.log_retention_days
  create_table       = false
  event_bus_name     = module.platform.event_bus_name

  queues = {
    events = { event_types = ["OrderConfirmed", "OrderCancelled"] }
  }

  environment_variables = {
    SES_FROM_ADDRESS = var.ses_from_address
  }

  extra_policy_statements = [{
    sid       = "EnviarCorreosDePedidos"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/*"]
    condition = { StringEquals = { "ses:FromAddress" = var.ses_from_address } }
  }]
}

module "api" {
  source = "../api"

  project                  = var.project
  environment              = var.environment
  user_pool_arn            = module.identity.user_pool_arn
  kms_key_arn              = module.platform.kms_key_arn
  log_retention_days       = var.log_retention_days
  throttling_rate_limit    = var.api_throttling_rate_limit
  throttling_burst_limit   = var.api_throttling_burst_limit
  webhook_signature_header = var.webhook_signature_header

  integrations = {
    for k, m in { catalog = module.catalog, users = module.users, orders = module.orders } : k => {
      function_name       = m.function_name
      alias_name          = m.alias_name
      invoke_arn          = m.alias_invoke_arn
    }
  }

  webhook_queue = {
    name = module.payments.queues["webhook"].name
    arn  = module.payments.queues["webhook"].arn
  }
}

module "edge" {
  source = "../edge"

  project              = var.project
  environment          = var.environment
  api_origin_domain    = module.api.origin_domain
  api_origin_path      = module.api.origin_path
  api_origin_key       = module.api.origin_api_key
  domain_name          = var.domain_name
  hosted_zone_id       = var.hosted_zone_name != null ? data.aws_route53_zone.this[0].zone_id : null
  pricing_plan_tier    = var.pricing_plan_tier
  waf_rate_limit       = var.waf_rate_limit
  force_destroy_bucket = var.force_destroy_bucket
}

locals {
  services = {
    catalog       = module.catalog
    users         = module.users
    orders        = module.orders
    inventory     = module.inventory
    payments      = module.payments
    notifications = module.notifications
  }
  all_queues = flatten([for s in values(local.services) : values(s.queues)])
}

module "observability" {
  source = "../observability"

  project         = var.project
  environment     = var.environment
  alarm_topic_arn = module.platform.alarm_topic_arn
  api_name        = module.api.api_name
  api_stage       = module.api.stage_name
  function_names  = [for s in values(local.services) : s.function_name]
  table_names     = compact([for s in values(local.services) : s.table_name])
  queue_names     = [for q in local.all_queues : q.name]
  dlq_names       = [for q in local.all_queues : q.dlq_name]
}
