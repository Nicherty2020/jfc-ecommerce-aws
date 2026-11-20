variable "region" {
  description = "Región principal. CloudFront, su WAF y su certificado ACM deben vivir en us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "api_origin_domain" {
  description = "Dominio del API Gateway; null mientras el módulo de API no exista."
  type        = string
  default     = null
}

variable "api_origin_path" {
  description = "Stage del API Gateway."
  type        = string
  default     = ""
}

variable "enable_waf" {
  type = bool
}

variable "waf_rate_limit" {
  type = number
}

variable "force_destroy_bucket" {
  type = bool
}
