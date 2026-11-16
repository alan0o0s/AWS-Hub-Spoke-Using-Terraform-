############################################################
# staging environment - thin wrapper around the reusable root module.
############################################################

module "platform" {
  source = "../../"

  aws_region   = var.aws_region
  environment  = "staging"
  project_name = "aws-hub-spoke"
  owner        = "Platform-Team"
  cost_center  = "eng-platform"

  availability_zones = ["us-east-2a", "us-east-2b"]
  # Same CIDR scheme as dev - environments are isolated deployments (separate
  # state, and typically separate AWS accounts in a real enterprise setup),
  # so there's no need for distinct IP ranges between them unless you plan
  # to VPC-peer environments together (not the case here). Overriding this
  # to a genuinely different range would also require overriding
  # hub_subnet_cidrs/spoke_subnet_cidrs to match - see README.md
  # "Environment Strategy" if you do need per-environment CIDR isolation.
  hub_vpc_cidr   = "10.0.0.0/16"
  spoke_vpc_cidr = "10.1.0.0/16"

  key_name = var.key_name

  instance_type    = "t3.small"
  asg_min_size     = 2
  asg_desired_size = 2
  asg_max_size     = 6

  enable_flow_logs                  = true
  enable_monitoring                 = true
  enable_firewall_delete_protection = true
  enable_lb_deletion_protection     = true
  log_retention_days                = 30
}
