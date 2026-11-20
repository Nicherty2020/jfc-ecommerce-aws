output "github_plan_role_arn" {
  description = "Variable AWS_PLAN_ROLE_ARN en GitHub."
  value       = aws_iam_role.github_plan.arn
}

output "github_deploy_role_arns" {
  description = "Variable AWS_DEPLOY_ROLE_ARN de cada environment de GitHub (dev y prod)."
  value       = { for env, role in aws_iam_role.github_deploy : env => role.arn }
}

output "artifacts_bucket" {
  description = "Variable ARTIFACTS_BUCKET en GitHub."
  value       = module.artifacts_bucket.name
}

output "cloudtrail_bucket" {
  description = "Bucket con los logs de auditoría."
  value       = module.cloudtrail_bucket.name
}

output "ses_identity" {
  description = "Valor de ses_identity en los terraform.tfvars de los entornos."
  value       = aws_sesv2_email_identity.this.email_identity
}
