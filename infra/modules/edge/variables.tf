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

variable "api_origin_key" {
  description = "API key que CloudFront envía a API Gateway en x-api-key. Obligatoria si hay api_origin_domain."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.api_origin_domain == null || var.api_origin_key != null
    error_message = "Si defines api_origin_domain, también debes definir api_origin_key."
  }
}

variable "domain_name" {
  description = "Dominio del sitio (p. ej. tienda-jfc.com o dev.tienda-jfc.com). null = dominio *.cloudfront.net."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Zona de Route 53 del dominio. Obligatoria si hay domain_name."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "Si defines domain_name, también debes definir hosted_zone_id."
  }
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

variable "pricing_plan_tier" {
  description = "Plan de tarifa plana de CloudFront (FREE, PRO, BUSINESS, PREMIUM). null = pago por uso."
  type        = string
  default     = null

  validation {
    condition     = var.pricing_plan_tier == null || contains(["FREE", "PRO", "BUSINESS", "PREMIUM"], coalesce(var.pricing_plan_tier, "-"))
    error_message = "pricing_plan_tier debe ser FREE, PRO, BUSINESS, PREMIUM o null."
  }

  validation {
    condition     = var.pricing_plan_tier == null || var.enable_waf
    error_message = "Los planes de tarifa plana exigen un WAF asociado: enable_waf debe ser true."
  }
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
