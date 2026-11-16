output "alb_sg_id" {
  description = "ID of the ALB security group (Hub)."
  value       = aws_security_group.alb.id
}

output "nlb_sg_id" {
  description = "ID of the internal NLB security group (Spoke)."
  value       = aws_security_group.nlb.id
}

output "spoke_app_sg_id" {
  description = "ID of the Spoke application security group (Spoke)."
  value       = aws_security_group.spoke_app.id
}
