############################
# Networking
############################

output "hub_vpc_id" {
  description = "Hub VPC ID."
  value       = module.hub_vpc.vpc_id
}

output "spoke_vpc_id" {
  description = "Spoke VPC ID."
  value       = module.spoke_vpc.vpc_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = module.transit_gateway.transit_gateway_id
}

output "network_firewall_arn" {
  description = "ARN of the AWS Network Firewall."
  value       = module.network_firewall.firewall_arn
}

############################
# Compute / Access
############################

output "autoscaling_group_name" {
  description = "Name of the Spoke Auto Scaling Group."
  value       = module.autoscaling.autoscaling_group_name
}

output "ssm_connect_command_hint" {
  description = "Administrative access is via SSM Session Manager, not a Bastion. Run: aws ec2 describe-instances --filters \"Name=tag:Name,Values=<name_prefix>-app\" --query \"Reservations[].Instances[].InstanceId\" then: aws ssm start-session --target <instance-id>"
  value       = "aws ssm start-session --target <instance-id>  (see README.md \"SSM instead of Bastion\")"
}

############################
# Load Balancers
############################

output "alb_dns_name" {
  description = "Public DNS name of the Hub ALB. curl http://<this> to test the public entry path."
  value       = module.alb.alb_dns_name
}

output "nlb_dns_name" {
  description = "Internal DNS name of the Spoke NLB. Reachable only from within the VPC/TGW-connected network."
  value       = module.nlb.nlb_dns_name
}

output "nlb_static_ips" {
  description = "The two fixed private IPs of the internal NLB - these are what the Hub ALB registers as its permanent targets (see modules/nlb README 'Static private IPs')."
  value       = local.nlb_static_ips
}

############################
# Observability
############################

output "network_firewall_log_group" {
  description = "CloudWatch log group for Network Firewall flow/alert logs."
  value       = module.network_firewall.log_group_name
}
