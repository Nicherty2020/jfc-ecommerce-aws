variable "project" {
  description = "Prefijo de los recursos."
  type        = string
  default     = "jfc"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.project))
    error_message = "project: solo minúsculas, números y guiones (2 a 20 caracteres)."
  }
}

variable "environment" {
  description = "dev o prod."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser dev o prod."
  }
}

variable "api_origin_domain" {
  description = "Dominio del API Gateway (abc123.execute-api.us-east-1.amazonaws.com). null = sin origen de API."
  type        = string
  default     = null
}

variable "api_origin_path" {
  description = "Stage del API Gateway, p. ej. /v1."
  type        = string
  default     = ""
}

variable "catalog_cache_default_ttl" {
  description = "TTL por defecto del catálogo, en segundos."
  type        = number
  default     = 60
}

variable "catalog_cache_max_ttl" {
  description = "TTL máximo del catálogo, en segundos."
  type        = number
  default     = 300
}

variable "aliases" {
  description = "Dominios propios. Vacío = dominio *.cloudfront.net."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "Certificado ACM en us-east-1. Obligatorio si hay aliases."
  type        = string
  default     = null
}

variable "price_class" {
  description = "Clase de precio de CloudFront. PriceClass_All incluye Sudamérica."
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class inválida."
  }
}

variable "enable_waf" {
  description = "Crea y asocia un Web ACL de WAF."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Peticiones máximas por IP cada 5 minutos."
  type        = number
  default     = 2000
}

variable "force_destroy_bucket" {
  description = "Permite borrar el bucket con objetos dentro (solo dev)."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Días que se conservan las versiones antiguas del frontend."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
