
variable "region" {
  description = "Región principal. CloudFront, su WAF y su certificado ACM deben vivir en us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "alarm_email" {
  type = string
}

variable "domain_name" {
  type    = string
  default = null
}

variable "hosted_zone_name" {
  type    = string
  default = null
}

variable "ses_identity" {
  type = string
}

variable "ses_from_address" {
  type = string
}

variable "cognito_email_via_ses" {
  type = bool
}

variable "deletion_protection" {
  type = bool
}

variable "force_destroy_bucket" {
  type = bool
}

variable "log_retention_days" {
  type = number
}

variable "kms_deletion_window_days" {
  type = number
}

variable "secret_recovery_window_days" {
  type = number
}

variable "pricing_plan_tier" {
  type    = string
  default = "FREE"
}

variable "waf_rate_limit" {
  type = number
}

variable "api_throttling_rate_limit" {
  type = number
}

variable "api_throttling_burst_limit" {
  type = number
}

variable "webhook_signature_header" {
  type    = string
  default = null
}

variable "reserved_concurrency" {
  type = object({
    orders    = number
    inventory = number
  })
}

variable "sqs_max_concurrency" {
  type = object({
    orders    = optional(number)
    inventory = optional(number)
  })
  default = {}
}
