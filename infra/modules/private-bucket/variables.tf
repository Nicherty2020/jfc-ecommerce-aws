variable "name" {
  description = "Nombre global del bucket."
  type        = string
}

variable "versioning" {
  description = "Activa el versionado."
  type        = bool
  default     = true
}

variable "expiration_days" {
  description = "Días tras los que expiran los objetos actuales. null = nunca."
  type        = number
  default     = null
}

variable "noncurrent_version_expiration_days" {
  description = "Días que se conservan las versiones antiguas."
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Permite borrar el bucket con objetos dentro."
  type        = bool
  default     = false
}

variable "extra_policy_statements" {
  description = "Statements adicionales para la política del bucket (p. ej. CloudTrail)."
  type        = any
  default     = []
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
