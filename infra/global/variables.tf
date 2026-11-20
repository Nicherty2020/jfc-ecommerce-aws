variable "region" {
  description = "Región de la cuenta."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de los recursos."
  type        = string
  default     = "jfc"
}

variable "github_repository" {
  description = "Repositorio que puede asumir los roles de CI/CD, formato organizacion/repositorio."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository debe tener el formato organizacion/repositorio."
  }
}

variable "alert_email" {
  description = "Correo que recibe las alertas de la cuenta y de AWS Budgets."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual de la cuenta en USD."
  type        = number
}

variable "domain_name" {
  description = "Dominio raíz con zona en Route 53 (p. ej. tienda-jfc.com). Se usa para la identidad de SES. null = sin dominio."
  type        = string
  default     = null
}

variable "ses_from_email" {
  description = "Correo remitente que se verifica en SES cuando no hay dominio propio."
  type        = string
  default     = null
}

variable "lambda_concurrency_quota" {
  description = "Cuota de ejecuciones concurrentes de Lambda de la cuenta (revisar en Service Quotas)."
  type        = number
  default     = 1000
}

variable "cloudtrail_retention_days" {
  description = "Días que se conservan los logs de CloudTrail en S3."
  type        = number
  default     = 365
}

variable "artifacts_retention_days" {
  description = "Días que se conservan los paquetes de las Lambdas."
  type        = number
  default     = 90
}
