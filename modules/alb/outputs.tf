output "alb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.alb.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.alb.dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB's IP-type target group. Targets are the Spoke NLB's two static private IPs (see modules/nlb), registered by modules/alb's aws_lb_target_group_attachment resources."
  value       = aws_lb_target_group.app.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB, required for CloudWatch metric dimensions."
  value       = aws_lb.alb.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, required for CloudWatch metric dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}
