output "api_id" {
  description = "ID de la API."
  value       = aws_api_gateway_rest_api.this.id
}

output "api_name" {
  description = "Nombre de la API (dimensión ApiName de las métricas)."
  value       = aws_api_gateway_rest_api.this.name
}

output "stage_name" {
  description = "Stage desplegado."
  value       = aws_api_gateway_stage.this.stage_name
}

output "origin_domain" {
  description = "Dominio de la API para el origen de CloudFront."
  value       = "${aws_api_gateway_rest_api.this.id}.execute-api.${local.region}.amazonaws.com"
}

output "origin_api_key" {
  description = "API key que CloudFront envía en x-api-key."
  value       = aws_api_gateway_api_key.cloudfront.value
  sensitive   = true
}

output "origin_path" {
  description = "origin_path de CloudFront (el stage)."
  value       = "/${aws_api_gateway_stage.this.stage_name}"
}
