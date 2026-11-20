output "dashboard_name" {
  description = "Nombre del dashboard en CloudWatch."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
