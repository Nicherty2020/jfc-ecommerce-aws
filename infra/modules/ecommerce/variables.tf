variable "project" {
  description = "Prefijo de los recursos."
  type        = string
  default     = "jfc"
}

variable "environment" {
  description = "dev o prod."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser dev o prod."
  }
}

variable "alarm_email" {
  description = "Correo que recibe las alarmas del entorno."
  type        = string
}

variable "domain_name" {
  description = "Dominio del sitio en este entorno (p. ej. dev.tienda-jfc.com). null = *.cloudfront.net."
  type        = string
  default     = null
}

variable "hosted_zone_name" {
  description = "Zona de Route 53 que contiene domain_name (p. ej. tienda-jfc.com)."
  type        = string
  default     = null

  validation {
    condition     = (var.domain_name == null) == (var.hosted_zone_name == null)
    error_message = "domain_name y hosted_zone_name se definen juntos o ninguno."
  }
}

variable "ses_identity" {
  description = "Identidad de SES creada en global/ (dominio o correo)."
  type        = string
}

variable "ses_from_address" {
  description = "Remitente de los correos (debe pertenecer a ses_identity)."
  type        = string
}

variable "cognito_email_via_ses" {
  description = "Cognito envía sus correos con SES (prod) en lugar de su correo por defecto."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protección contra borrado de tablas y user pool."
  type        = bool
  default     = true
}

variable "force_destroy_bucket" {
  description = "Permite borrar el bucket del frontend con objetos (solo dev)."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retención de logs de Lambda y API Gateway."
  type        = number
  default     = 30
}

variable "kms_deletion_window_days" {
  description = "Días de espera antes de borrar la llave KMS."
  type        = number
  default     = 30
}

variable "secret_recovery_window_days" {
  description = "Días para recuperar un secreto borrado (0 = borrado inmediato)."
  type        = number
  default     = 30
}

variable "pricing_plan_tier" {
  description = "Plan de tarifa plana de CloudFront (D11). null = pago por uso."
  type        = string
  default     = "FREE"
}

variable "waf_rate_limit" {
  description = "Peticiones máximas por IP cada 5 minutos."
  type        = number
  default     = 2000
}

variable "api_throttling_rate_limit" {
  description = "Peticiones por segundo sostenidas en la API."
  type        = number
  default     = 1000
}

variable "api_throttling_burst_limit" {
  description = "Ráfaga máxima de peticiones en la API."
  type        = number
  default     = 2000
}

variable "webhook_signature_header" {
  description = "Header con la firma del webhook. null = la firma viene en el cuerpo."
  type        = string
  default     = null
}

variable "lambda_runtime" {
  description = "Runtime de las Lambdas (supuesto)."
  type        = string
  default     = "python3.13"
}

variable "lambda_memory_mb" {
  description = "Memoria de las Lambdas en MB."
  type        = number
  default     = 256
}

variable "reserved_concurrency" {
  description = "Concurrencia reservada del checkout. -1 = sin reserva."
  type = object({
    orders    = number
    inventory = number
  })
  default = { orders = -1, inventory = -1 }
}

variable "sqs_max_concurrency" {
  description = "Tope de Lambdas leyendo cada cola del checkout; debe ser menor que la concurrencia reservada. null = sin tope."
  type = object({
    orders    = optional(number)
    inventory = optional(number)
  })
  default = {}
}
