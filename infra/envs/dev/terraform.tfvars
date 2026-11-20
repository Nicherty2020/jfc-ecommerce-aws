alarm_email = "alertas@example.com"

domain_name      = null # p. ej. "dev.tienda-jfc.com"
hosted_zone_name = null # p. ej. "tienda-jfc.com"

ses_identity          = "notificaciones@example.com"
ses_from_address      = "notificaciones@example.com"
cognito_email_via_ses = false

deletion_protection         = false
force_destroy_bucket        = true
log_retention_days          = 14
kms_deletion_window_days    = 7
secret_recovery_window_days = 0

pricing_plan_tier = "FREE"
waf_rate_limit    = 2000

api_throttling_rate_limit  = 50
api_throttling_burst_limit = 100

reserved_concurrency = { orders = -1, inventory = -1 }
