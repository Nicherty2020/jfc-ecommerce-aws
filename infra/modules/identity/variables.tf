variable "project" {
  description = "Prefijo de los recursos."
  type        = string
}

variable "environment" {
  description = "dev o prod."
  type        = string
}

variable "deletion_protection" {
  description = "Impide borrar el user pool (prod)."
  type        = bool
  default     = true
}

variable "ses_identity_arn" {
  description = "Identidad de SES para los correos de Cognito. null = correo por defecto de Cognito."
  type        = string
  default     = null
}

variable "ses_from_address" {
  description = "Remitente de los correos de Cognito cuando se usa SES."
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
