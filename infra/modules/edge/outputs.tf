output "distribution_id" {
  description = "ID de la distribución (para invalidar caché desde el pipeline)."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN de la distribución."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Dominio *.cloudfront.net (destino del alias de Route 53 si hay dominio propio)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "site_url" {
  description = "URL pública del sitio."
  value       = "https://${local.has_domain ? var.domain_name : aws_cloudfront_distribution.this.domain_name}"
}

output "frontend_bucket_name" {
  description = "Bucket donde el pipeline copia el build del frontend."
  value       = aws_s3_bucket.frontend.bucket
}

output "web_acl_arn" {
  description = "ARN del Web ACL de WAF (null si está desactivado)."
  value       = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null
}
