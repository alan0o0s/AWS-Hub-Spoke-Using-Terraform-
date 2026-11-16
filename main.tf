############################################################
# PHASE 3: Foundational networking - Hub and Spoke VPCs.
############################################################

module "hub_vpc" {
  source = "./modules/vpc"

  name_prefix             = "${local.name_prefix}-hub"
  vpc_cidr                = var.hub_vpc_cidr
  subnets                 = local.hub_subnets
  create_internet_gateway = true # ONLY the Hub gets an IGW
  tags                    = local.common_tags
}

module "spoke_vpc" {
  source = "./modules/vpc"

  name_prefix             = "${local.name_prefix}-spoke"
  vpc_cidr                = var.spoke_vpc_cidr
  subnets                 = local.spoke_subnets
  create_internet_gateway = false # the Spoke MUST NOT have an IGW
  tags                    = local.common_tags
}

module "nat_gateway" {
  source = "./modules/nat-gateway"

  name_prefix = local.name_prefix
  subnet_id   = module.hub_vpc.subnet_ids["nat"]
  tags        = local.common_tags
}

############################################################
# PHASE 4: Transit Gateway (Appliance Mode enabled on the Hub attachment).
############################################################

module "transit_gateway" {
  source = "./modules/transit-gateway"

  name_prefix          = local.name_prefix
  amazon_side_asn      = var.tgw_asn
  hub_vpc_id           = module.hub_vpc.vpc_id
  hub_tgw_subnet_ids   = [module.hub_vpc.subnet_ids["tgw_a"], module.hub_vpc.subnet_ids["tgw_b"]]
  spoke_vpc_id         = module.spoke_vpc.vpc_id
  spoke_tgw_subnet_ids = [module.spoke_vpc.subnet_ids["tgw_a"], module.spoke_vpc.subnet_ids["tgw_b"]]
  tags                 = local.common_tags
}

############################################################
# PHASE 5: AWS Network Firewall.
############################################################

module "network_firewall" {
  source = "./modules/network-firewall"

  name_prefix         = local.name_prefix
  hub_vpc_id          = module.hub_vpc.vpc_id
  hub_vpc_cidr        = var.hub_vpc_cidr
  spoke_vpc_cidr      = var.spoke_vpc_cidr
  firewall_subnet_ids = [module.hub_vpc.subnet_ids["firewall"]]
  delete_protection   = var.enable_firewall_delete_protection
  log_retention_days  = var.log_retention_days
  tags                = local.common_tags
}

############################################################
# PHASE 6: Security groups (no Bastion - see note below).
############################################################

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix    = local.name_prefix
  hub_vpc_id     = module.hub_vpc.vpc_id
  hub_vpc_cidr   = var.hub_vpc_cidr
  spoke_vpc_id   = module.spoke_vpc.vpc_id
  spoke_vpc_cidr = var.spoke_vpc_cidr
  tags           = local.common_tags
}

############################################################
# NOTE: no Bastion module. Administrative access to Spoke instances is
# entirely via AWS Systems Manager Session Manager - the Spoke application
# IAM role below already carries AmazonSSMManagedInstanceCore, which is all
# that's needed. See README.md "SSM instead of Bastion" for the full
# rationale and the exact `aws ssm start-session` command to use.
#
# The Hub's "bastion" subnet (10.0.7.0/28 by default) is still created -
# see modules/vpc call above - purely to match the reference diagram's
# layout; nothing is deployed into it.
############################################################

############################################################
# Spoke application IAM role - least privilege, SSM only. This is also the
# platform's ONLY administrative access mechanism (see the "no Bastion"
# note above) - `AmazonSSMManagedInstanceCore` is all that's needed for
# `aws ssm start-session --target <instance-id>` to work, with no inbound
# port required at all. Kept as inline resources rather than a dedicated
# module: three small, tightly related resources with no reuse case beyond
# this one launch template, so a full module would add indirection without
# benefit. See README.md "Repository Structure - Deviation" for this and
# the other structural decisions.
############################################################

data "aws_iam_policy_document" "spoke_app_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "spoke_app" {
  name_prefix        = "${local.name_prefix}-spoke-app-"
  assume_role_policy = data.aws_iam_policy_document.spoke_app_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "spoke_app_ssm" {
  role       = aws_iam_role.spoke_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "spoke_app" {
  name_prefix = "${local.name_prefix}-spoke-app-"
  role        = aws_iam_role.spoke_app.name
}

############################################################
# PHASE 7: Launch Template + ASG.
############################################################

module "launch_template" {
  source = "./modules/launch-template"

  name_prefix                = local.name_prefix
  ami_id                     = var.ami_id
  instance_type              = var.instance_type
  key_name                   = var.key_name
  security_group_id          = module.security_groups.spoke_app_sg_id
  instance_profile_name      = aws_iam_instance_profile.spoke_app.name
  manage_ssm_agent           = var.manage_ssm_agent
  enable_detailed_monitoring = var.enable_detailed_monitoring
  tags                       = local.common_tags
}

module "autoscaling" {
  source = "./modules/autoscaling"

  name_prefix              = local.name_prefix
  subnet_ids               = [module.spoke_vpc.subnet_ids["app_a"], module.spoke_vpc.subnet_ids["app_b"]]
  launch_template_id       = module.launch_template.launch_template_id
  nlb_target_group_arn     = module.nlb.target_group_arn
  min_size                 = var.asg_min_size
  desired_capacity         = var.asg_desired_size
  max_size                 = var.asg_max_size
  target_cpu_utilization   = var.target_cpu_utilization
  scaling_estimated_warmup = var.scaling_estimated_warmup
  tags                     = local.common_tags
}

############################################################
# PHASE 8: Internal NLB (Spoke, same-VPC targets).
############################################################

module "nlb" {
  source = "./modules/nlb"

  nlb_name                   = var.nlb_name
  vpc_id                     = module.spoke_vpc.vpc_id
  subnet_ids                 = [module.spoke_vpc.subnet_ids["app_a"], module.spoke_vpc.subnet_ids["app_b"]]
  static_ips                 = local.nlb_static_ips
  nlb_sg_id                  = module.security_groups.nlb_sg_id
  enable_deletion_protection = var.enable_lb_deletion_protection
  tags                       = local.common_tags
}

############################################################
# PHASE 9: Internet-facing ALB (Hub, cross-VPC IP targets pointed at the
# Spoke NLB's static IPs - no dynamic registration mechanism needed, see
# modules/alb/README.md and modules/nlb/README.md "Static private IPs").
############################################################

module "alb" {
  source = "./modules/alb"

  alb_name                   = var.alb_name
  hub_vpc_id                 = module.hub_vpc.vpc_id
  subnet_ids                 = [module.hub_vpc.subnet_ids["alb_a"], module.hub_vpc.subnet_ids["alb_b"]]
  alb_sg_id                  = module.security_groups.alb_sg_id
  nlb_static_ips             = local.nlb_static_ips
  enable_deletion_protection = var.enable_lb_deletion_protection
  tags                       = local.common_tags
}

############################################################
# PHASE 10: Observability - Flow Logs + Monitoring.
############################################################

module "flow_logs_hub" {
  count  = var.enable_flow_logs ? 1 : 0
  source = "./modules/flow-logs"

  name_prefix        = "${local.name_prefix}-hub"
  vpc_id             = module.hub_vpc.vpc_id
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

module "flow_logs_spoke" {
  count  = var.enable_flow_logs ? 1 : 0
  source = "./modules/flow-logs"

  name_prefix        = "${local.name_prefix}-spoke"
  vpc_id             = module.spoke_vpc.vpc_id
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  name_prefix                 = local.name_prefix
  alb_arn_suffix              = module.alb.alb_arn_suffix
  alb_target_group_arn_suffix = module.alb.target_group_arn_suffix
  nlb_arn_suffix              = module.nlb.nlb_arn_suffix
  nlb_target_group_arn_suffix = module.nlb.target_group_arn_suffix
  autoscaling_group_name      = module.autoscaling.autoscaling_group_name
  asg_desired_capacity        = var.asg_desired_size
  tags                        = local.common_tags
}
