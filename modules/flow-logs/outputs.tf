output "log_group_name" {
  description = "CloudWatch log group receiving this VPC's flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
