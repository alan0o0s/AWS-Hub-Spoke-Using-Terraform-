output "firewall_arn" {
  description = "ARN of the AWS Network Firewall."
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_policy_arn" {
  description = "ARN of the firewall policy."
  value       = aws_networkfirewall_firewall_policy.this.arn
}

output "endpoint_ids_by_az" {
  description = "Map of Availability Zone -> Network Firewall VPC endpoint ID, for use when building route tables that must send traffic through the firewall in a specific AZ."
  value       = local.endpoint_by_az
}

output "log_group_name" {
  description = "CloudWatch log group receiving firewall flow/alert logs."
  value       = aws_cloudwatch_log_group.firewall.name
}
