variable "project" {
  description = "Prefijo de los recursos."
  type        = string
}

variable "environment" {
  description = "dev o prod."
  type        = string
}

variable "alarm_email" {
  description = "Correo que recibe las alarmas del entorno."
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Días de espera antes de borrar la llave KMS (7 a 30)."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days debe estar entre 7 y 30."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
