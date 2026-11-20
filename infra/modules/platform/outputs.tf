output "kms_key_arn" {
  description = "ARN de la llave de datos."
  value       = aws_kms_key.data.arn
}

output "event_bus_name" {
  description = "Nombre del bus de eventos."
  value       = aws_cloudwatch_event_bus.ecommerce.name
}

output "event_bus_arn" {
  description = "ARN del bus de eventos."
  value       = aws_cloudwatch_event_bus.ecommerce.arn
}

output "alarm_topic_arn" {
  description = "Tema SNS al que avisan las alarmas."
  value       = aws_sns_topic.alarms.arn
}
