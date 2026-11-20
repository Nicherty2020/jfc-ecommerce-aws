variable "project" {
  description = "Prefijo de los recursos."
  type        = string
}

variable "environment" {
  description = "dev o prod."
  type        = string
}

variable "alarm_topic_arn" {
  description = "Tema SNS que reciben las alarmas."
  type        = string
}

variable "api_name" {
  description = "Nombre de la API REST."
  type        = string
}

variable "api_stage" {
  description = "Stage de la API."
  type        = string
}

variable "api_5xx_rate_threshold" {
  description = "Tasa de 5XX que dispara la alarma (0.01 = 1 %)."
  type        = number
  default     = 0.01
}

variable "function_names" {
  description = "Funciones Lambda del entorno."
  type        = list(string)
}

variable "table_names" {
  description = "Tablas DynamoDB del entorno."
  type        = list(string)
}

variable "queue_names" {
  description = "Colas SQS principales."
  type        = list(string)
}

variable "dlq_names" {
  description = "Colas DLQ."
  type        = list(string)
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
