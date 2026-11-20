variable "project" {
  description = "Prefijo de los recursos."
  type        = string
}

variable "environment" {
  description = "dev o prod."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment debe ser dev o prod."
  }
}

variable "service" {
  description = "Nombre del microservicio (catalog, orders, ...)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.service))
    error_message = "service: minúsculas, números y guiones (2 a 21 caracteres)."
  }
}

variable "runtime" {
  description = "Runtime de la Lambda (supuesto: Python)."
  type        = string
  default     = "python3.13"
}

variable "handler" {
  description = "Handler de la Lambda. El pipeline sube código que respeta este nombre."
  type        = string
  default     = "app.handler"
}

variable "memory_size" {
  description = "Memoria en MB (también define la CPU)."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Tiempo máximo de ejecución en segundos."
  type        = number
  default     = 10
}

variable "reserved_concurrency" {
  description = "Concurrencia reservada. -1 = sin reserva."
  type        = number
  default     = -1
}

variable "layers" {
  description = "ARNs de layers. Por defecto Powertools va empaquetado con el código."
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Variables de entorno adicionales."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Retención de los logs (por defecto no expiran, y eso cuesta)."
  type        = number
  default     = 14
}

variable "schedule_expression" {
  description = "Invoca la función de forma programada, p. ej. rate(5 minutes). null = sin programación."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "Llave KMS que cifra la tabla y las colas."
  type        = string
}

variable "create_table" {
  description = "Crea la tabla DynamoDB propia del servicio."
  type        = bool
  default     = true
}

variable "table_access" {
  description = "Permisos sobre la tabla propia: read o readwrite."
  type        = string
  default     = "readwrite"

  validation {
    condition     = contains(["read", "readwrite"], var.table_access)
    error_message = "table_access debe ser read o readwrite."
  }
}

variable "table_ttl_attribute" {
  description = "Atributo TTL (registros de idempotencia). 'expiration' es el que usa Powertools."
  type        = string
  default     = "expiration"
}

variable "table_gsis" {
  description = "Índices secundarios globales (atributos tipo string)."
  type = list(object({
    name      = string
    hash_key  = string
    range_key = string
  }))
  default = []
}

variable "deletion_protection" {
  description = "Protección contra borrado de la tabla."
  type        = bool
  default     = true
}

variable "event_bus_name" {
  description = "Bus de EventBridge del entorno."
  type        = string
  default     = null
}

variable "event_bus_arn" {
  description = "ARN del bus de EventBridge."
  type        = string
  default     = null
}

variable "publishes_events" {
  description = "Permite publicar eventos en el bus."
  type        = bool
  default     = false
}

variable "queues" {
  description = <<-EOT
    Colas que consume la función. Cada cola tiene su DLQ.
    event_types: tipos de evento del bus que llegan a la cola (vacío = la llena otro productor, p. ej. API Gateway).
    max_concurrency: tope de Lambdas que procesan la cola a la vez (útil con concurrencia reservada).
  EOT
  type = map(object({
    event_types       = list(string)
    max_receive_count = optional(number, 5)
    max_concurrency   = optional(number)
  }))
  default = {}
}

variable "extra_policy_statements" {
  description = "Permisos adicionales del rol (p. ej. leer un secreto o enviar con SES)."
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
    condition = optional(any)
  }))
  default = []
}

variable "alarm_topic_arn" {
  description = "Tema SNS que reciben las alarmas."
  type        = string
}

variable "alarm_on_any_error" {
  description = "Alarma con cualquier error de la función (servicios del checkout)."
  type        = bool
  default     = false
}

variable "queue_age_alarm_seconds" {
  description = "Edad máxima del mensaje más antiguo de una cola antes de avisar."
  type        = number
  default     = 300
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
