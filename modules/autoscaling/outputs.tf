output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.arn
}

output "cpu_target_tracking_policy_arn" {
  description = "ARN of the CPU-based Target Tracking scaling policy."
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}
