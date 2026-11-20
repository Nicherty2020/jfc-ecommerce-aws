alarm_email = "alertas@example.com"

domain_name      = null # p. ej. "tienda-jfc.com"
hosted_zone_name = null # p. ej. "tienda-jfc.com"

ses_identity          = "notificaciones@example.com"
ses_from_address      = "notificaciones@example.com"
cognito_email_via_ses = true

deletion_protection         = true
force_destroy_bucket        = false
log_retention_days          = 30
kms_deletion_window_days    = 30
secret_recovery_window_days = 30

pricing_plan_tier = "FREE"
waf_rate_limit    = 2000

api_throttling_rate_limit  = 1000
api_throttling_burst_limit = 2000

reserved_concurrency = { orders = 100, inventory = 50 }

sqs_max_concurrency = { orders = 50, inventory = 40 }
