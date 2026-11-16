output "nlb_arn" {
  description = "ARN of the internal NLB."
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "Internal DNS name of the NLB."
  value       = aws_lb.nlb.dns_name
}

output "target_group_arn" {
  description = "ARN of the NLB's target group, for the autoscaling module to attach the ASG to."
  value       = aws_lb_target_group.app.arn
}

output "nlb_arn_suffix" {
  description = "ARN suffix of the NLB, required for CloudWatch metric dimensions."
  value       = aws_lb.nlb.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, required for CloudWatch metric dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}
