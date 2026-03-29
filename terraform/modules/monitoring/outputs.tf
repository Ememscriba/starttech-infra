output "backend_log_group" {
  description = "Name of the backend log group"
  value       = aws_cloudwatch_log_group.backend.name
}

output "frontend_log_group" {
  description = "Name of the frontend log group"
  value       = aws_cloudwatch_log_group.frontend.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
