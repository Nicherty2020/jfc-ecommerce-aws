output "name" {
  description = "Nombre del bucket."
  value       = aws_s3_bucket.this.bucket
}

output "arn" {
  description = "ARN del bucket."
  value       = aws_s3_bucket.this.arn
}
