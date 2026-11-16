############################################################
# prod environment - thin wrapper around the reusable root module.
############################################################

module "platform" {
  source = "../../"

  aws_region   = var.aws_region
  environment  = "prod"
  project_name = "aws-hub-spoke"
  owner        = "Platform-Team"
  cost_center  = "eng-platform"

  availability_zones = ["us-east-2a", "us-east-2b"]
  # Same CIDR scheme as dev/staging - see staging/main.tf comment for why
  # environments don't need distinct IP ranges in this design.
  hub_vpc_cidr   = "10.0.0.0/16"
  spoke_vpc_cidr = "10.1.0.0/16"

  key_name = var.key_name

  instance_type    = "t3.medium"
  asg_min_size     = 2
  asg_desired_size = 3
  asg_max_size     = 8

  # Detailed (1-minute) CloudWatch monitoring gives the CPU-based Target
  # Tracking scaling policy roughly 4x faster visibility into load changes
  # than the default 5-minute basic monitoring - worth the small added
  # cost in prod where scaling responsiveness matters most.
  enable_detailed_monitoring = true

  enable_flow_logs                  = true
  enable_monitoring                 = true
  enable_firewall_delete_protection = true # prod: protect against accidental destroy
  enable_lb_deletion_protection     = true
  log_retention_days                = 90 # prod: longer retention for audits
}
