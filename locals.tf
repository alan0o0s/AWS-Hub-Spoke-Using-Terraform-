locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    Application = "hub-spoke-platform"
  })

  # Explicit subnet -> AZ-index mapping, matching the reference architecture
  # exactly (e.g. "firewall" is AZ-a, "bastion" is AZ-b - not a uniform
  # _a/_b naming pattern, so this is spelled out rather than inferred).
  hub_subnet_az_index = {
    firewall = 0
    bastion  = 1
    alb_a    = 0
    alb_b    = 1
    tgw_a    = 0
    tgw_b    = 1
    nat      = 0
  }

  spoke_subnet_az_index = {
    app_a = 0
    app_b = 1
    rds_a = 0
    rds_b = 1
    tgw_a = 0
    tgw_b = 1
  }

  hub_subnets = {
    for name, cidr in var.hub_subnet_cidrs : name => {
      cidr = cidr
      az   = var.availability_zones[local.hub_subnet_az_index[name]]
    }
  }

  spoke_subnets = {
    for name, cidr in var.spoke_subnet_cidrs : name => {
      cidr = cidr
      az   = var.availability_zones[local.spoke_subnet_az_index[name]]
    }
  }

  # Single Network Firewall endpoint in this reference architecture (the
  # firewall subnet exists only in AZ-a) - see ARCHITECTURE.md "Single-AZ
  # Firewall/NAT" for the HA trade-off this implies and how Appliance Mode
  # still matters even with one AZ.
  firewall_endpoint_id = values(module.network_firewall.endpoint_ids_by_az)[0]

  # Fixed private IPs for the internal NLB, one per app subnet - computed
  # here (not read from any module output) so that BOTH modules.nlb and
  # modules.alb can consume the same two addresses without either module
  # depending on the other's output (avoids a dependency cycle).
  #
  # IP COLLISION RISK - read this before relying on it in production:
  # cidrhost(cidr, -10) picks an address near the TOP of each /24 (e.g.
  # .246), deliberately far from the low end of the range where AWS's DHCP
  # tends to hand out addresses to EC2 ENIs first (including this
  # platform's own ASG instances, which share this same subnet with the
  # NLB per the reference diagram). This significantly reduces collision
  # probability at the ASG sizes this platform uses (max 4-8 instances),
  # but does NOT eliminate it - AWS does not provide a way to formally
  # reserve a specific IP for a Terraform-managed subnet_mapping ahead of
  # time. If `terraform apply` for modules.nlb ever fails with an
  # "IP address already in use" error, either (a) re-run apply after an ASG
  # instance cycles and releases the address, or (b) for a more robust
  # production fix, move the NLB into its own small dedicated subnet with
  # no other resources - the AWS-recommended pattern to eliminate this risk
  # entirely - rather than sharing the app subnets as the reference
  # diagram depicts.
  nlb_static_ips = [
    cidrhost(var.spoke_subnet_cidrs["app_a"], -10),
    cidrhost(var.spoke_subnet_cidrs["app_b"], -10),
  ]
}
