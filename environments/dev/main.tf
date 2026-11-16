############################################################
# dev environment - thin wrapper around the reusable root module.
# No Terraform logic lives here beyond variable passthrough: every module
# and resource definition is shared with staging/prod via ../../.
############################################################

module "platform" {
  source = "../../"

  aws_region   = var.aws_region
  environment  = "dev"
  project_name = "aws-hub-spoke"
  owner        = "Platform-Team"
  cost_center  = "eng-platform"

  availability_zones = ["us-east-2a", "us-east-2b"]
  hub_vpc_cidr       = "10.0.0.0/16"
  spoke_vpc_cidr     = "10.1.0.0/16"

  key_name = var.key_name

  instance_type    = "t2.micro"
  asg_min_size     = 2
  asg_desired_size = 2
  asg_max_size     = 4

  enable_flow_logs                  = true
  enable_monitoring                 = true
  enable_firewall_delete_protection = false # dev: allow easy teardown
  enable_lb_deletion_protection     = false
  log_retention_days                = 14 # dev: shorter retention than prod
}
