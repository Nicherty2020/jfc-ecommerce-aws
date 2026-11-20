output "site_url" {
  description = "URL pública del sitio."
  value       = module.edge.site_url
}

output "api_execute_url" {
  description = "URL directa de API Gateway; debe responder 403 sin la API key de CloudFront."
  value       = "https://${module.api.origin_domain}${module.api.origin_path}"
}

output "cloudfront_distribution_id" {
  description = "Distribución (el pipeline invalida index.html)."
  value       = module.edge.distribution_id
}

output "frontend_bucket" {
  description = "Bucket donde el pipeline copia el build del frontend."
  value       = module.edge.frontend_bucket_name
}

output "cognito_user_pool_id" {
  description = "User pool (configuración de la SPA)."
  value       = module.identity.user_pool_id
}

output "cognito_client_id" {
  description = "App client de la SPA."
  value       = module.identity.client_id
}

output "payments_secret_name" {
  description = "Secreto donde se cargan las credenciales de la pasarela."
  value       = aws_secretsmanager_secret.payments_gateway.name
}

output "lambda_functions" {
  description = "Funciones que despliega el pipeline."
  value       = { for k, s in local.services : k => s.function_name }
}

output "dashboard" {
  description = "Dashboard de CloudWatch."
  value       = module.observability.dashboard_name
}
