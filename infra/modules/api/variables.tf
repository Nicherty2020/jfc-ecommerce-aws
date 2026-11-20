variable "project" {
  description = "Prefijo de los recursos."
  type        = string
}

variable "environment" {
  description = "dev o prod."
  type        = string
}

variable "stage_name" {
  description = "Stage de la API. CloudFront lo usa como origin_path."
  type        = string
  default     = "v1"
}

variable "user_pool_arn" {
  description = "User pool de Cognito que valida los JWT."
  type        = string
}

variable "integrations" {
  description = "Servicios detrás de la API. Claves esperadas: catalog, users, orders."
  type = map(object({
    function_name = string
    alias_name    = string
    invoke_arn    = string
  }))

  validation {
    condition     = alltrue([for k in ["catalog", "users", "orders"] : contains(keys(var.integrations), k)])
    error_message = "integrations debe incluir catalog, users y orders."
  }
}

variable "webhook_queue" {
  description = "Cola donde API Gateway deja los webhooks de la pasarela."
  type = object({
    name = string
    arn  = string
  })
}

variable "webhook_signature_header" {
  description = "Header con la firma del webhook (p. ej. Stripe-Signature). null = la firma viene en el cuerpo (Wompi)."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "Llave que cifra la cola del webhook."
  type        = string
}

variable "throttling_rate_limit" {
  description = "Peticiones por segundo sostenidas en el stage."
  type        = number
  default     = 1000
}

variable "throttling_burst_limit" {
  description = "Ráfaga máxima de peticiones en el stage."
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "Retención de los access logs."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
