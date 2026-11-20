output "function_name" {
  description = "Nombre de la función."
  value       = aws_lambda_function.this.function_name
}

output "alias_name" {
  description = "Alias que reciben API Gateway, SQS y EventBridge."
  value       = aws_lambda_alias.live.name
}

output "alias_arn" {
  description = "ARN del alias."
  value       = aws_lambda_alias.live.arn
}

output "alias_invoke_arn" {
  description = "ARN de invocación del alias (integración de API Gateway)."
  value       = aws_lambda_alias.live.invoke_arn
}

output "role_arn" {
  description = "Rol de la función."
  value       = aws_iam_role.this.arn
}

output "table_name" {
  description = "Tabla del servicio (null si no tiene)."
  value       = var.create_table ? aws_dynamodb_table.this[0].name : null
}

output "queues" {
  description = "Colas del servicio por clave: nombre, ARN, URL y su DLQ."
  value = {
    for k, q in aws_sqs_queue.this : k => {
      name     = q.name
      arn      = q.arn
      url      = q.id
      dlq_name = aws_sqs_queue.dlq[k].name
    }
  }
}
