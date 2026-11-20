output "user_pool_id" {
  description = "ID del user pool (configuración de la SPA)."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN del user pool (autorizador de API Gateway)."
  value       = aws_cognito_user_pool.this.arn
}

output "client_id" {
  description = "ID del app client de la SPA."
  value       = aws_cognito_user_pool_client.spa.id
}
