############################################################
# ROUTING LAYER.
#
# Every route in the platform is created here, and only here - no other
# module creates a route table entry (see design requirement 41 and
# modules/route-table/README.md). This file is the single place to audit
# "where does traffic actually go" for the entire platform.
#
# Expected packet path (outbound, Spoke -> Internet):
#   Spoke app instance
#     -> spoke-app route table (0.0.0.0/0 -> TGW)
#     -> Transit Gateway (Appliance Mode pins the flow to one Hub AZ)
#     -> Hub TGW subnet
#     -> hub-tgw route table (0.0.0.0/0 -> Firewall endpoint)
#     -> Network Firewall (stateful inspection, PASS/DROP per rule group)
#     -> firewall route table (0.0.0.0/0 -> NAT Gateway)
#     -> NAT Gateway
#     -> nat route table (0.0.0.0/0 -> IGW)
#     -> Internet Gateway -> Internet
#
# Return path symmetry is what the igw-ingress edge association below
# exists for for - see its comment.
############################################################

locals {
  tgw_id      = module.transit_gateway.transit_gateway_id
  hub_igw_id  = module.hub_vpc.internet_gateway_id
  nat_gw_id   = module.nat_gateway.nat_gateway_id
  fw_endpoint = local.firewall_endpoint_id
}

# ---------------------------------------------------------------------------
# HUB: ALB route table (alb_a, alb_b).
# ---------------------------------------------------------------------------
module "rt_hub_alb" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "alb"
  vpc_id           = module.hub_vpc.vpc_id
  subnet_ids       = [module.hub_vpc.subnet_ids["alb_a"], module.hub_vpc.subnet_ids["alb_b"]]
  routes = [
    { destination_cidr = var.spoke_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
    { destination_cidr = "0.0.0.0/0", target_type = "gateway", target_id = local.hub_igw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# HUB: Bastion subnet route table.
#
# The subnet itself is still created (matching the reference diagram's
# layout), but no EC2 instance is deployed into it - see main.tf's "no
# Bastion module" note and README.md "SSM instead of Bastion". This route
# table is kept for subnet validity and in case a future public Hub
# resource is ever placed here; it carries no operational significance
# today.
# ---------------------------------------------------------------------------
module "rt_hub_bastion" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "bastion"
  vpc_id           = module.hub_vpc.vpc_id
  subnet_ids       = [module.hub_vpc.subnet_ids["bastion"]]
  routes = [
    { destination_cidr = var.spoke_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
    { destination_cidr = "0.0.0.0/0", target_type = "gateway", target_id = local.hub_igw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# HUB: TGW subnet route table (tgw_a, tgw_b).
#
# NOTE ON THE 10.1.0.0/16 -> TGW ROUTE: preserved exactly as specified in the
# reference design. In practice, traffic destined for the Spoke that reaches
# this route table's ENIs almost always arrived FROM the TGW attachment in
# the first place (the TGW subnet IS the attachment's home), so this
# specific entry has limited additional effect versus the 0.0.0.0/0 ->
# Firewall-endpoint route below. It is kept for fidelity to the provided
# architecture and does no harm (see requirement: "do not simplify the
# architecture" / ARCHITECTURE.md "Preserved-as-specified routes").
# ---------------------------------------------------------------------------
module "rt_hub_tgw" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "tgw"
  vpc_id           = module.hub_vpc.vpc_id
  subnet_ids       = [module.hub_vpc.subnet_ids["tgw_a"], module.hub_vpc.subnet_ids["tgw_b"]]
  routes = [
    { destination_cidr = var.spoke_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
    { destination_cidr = "0.0.0.0/0", target_type = "vpc_endpoint", target_id = local.fw_endpoint },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# HUB: Firewall subnet route table.
# ---------------------------------------------------------------------------
module "rt_hub_firewall" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "firewall"
  vpc_id           = module.hub_vpc.vpc_id
  subnet_ids       = [module.hub_vpc.subnet_ids["firewall"]]
  routes = [
    { destination_cidr = var.spoke_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
    { destination_cidr = "0.0.0.0/0", target_type = "nat_gateway", target_id = local.nat_gw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# HUB: NAT subnet route table.
# ---------------------------------------------------------------------------
module "rt_hub_nat" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "nat"
  vpc_id           = module.hub_vpc.vpc_id
  subnet_ids       = [module.hub_vpc.subnet_ids["nat"]]
  routes = [
    { destination_cidr = var.spoke_vpc_cidr, target_type = "vpc_endpoint", target_id = local.fw_endpoint },
    { destination_cidr = "0.0.0.0/0", target_type = "gateway", target_id = local.hub_igw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# HUB: Internet Gateway INGRESS routing (edge association) - the "technically
# correct adjustment" required by AWS that the reference route-table list
# (section 15) did not explicitly include.
#
# WHY THIS IS NEEDED: response traffic from the internet, addressed to the
# NAT Gateway's public Elastic IP, arrives at the Hub's Internet Gateway and
# would - by default - be routed directly to the NAT Gateway's subnet using
# the IGW's own implicit local routing, COMPLETELY BYPASSING the Network
# Firewall on the return leg. That breaks both the "centralized inspection"
# principle and firewall connection-state tracking (the stateful firewall
# would see only the outbound leg of every connection, never the return).
#
# THE FIX: associate a route table with the Internet Gateway itself (an
# "edge association"), routing traffic destined for the NAT subnet's CIDR
# back through the Network Firewall endpoint first. This is the standard
# AWS reference pattern for centralized-egress architectures using Network
# Firewall, and is documented in ARCHITECTURE.md "Symmetric Routing".
# ---------------------------------------------------------------------------
module "rt_hub_igw_ingress" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "igw-ingress"
  vpc_id           = module.hub_vpc.vpc_id
  edge_gateway_id  = local.hub_igw_id
  routes = [
    { destination_cidr = var.hub_subnet_cidrs["nat"], target_type = "vpc_endpoint", target_id = local.fw_endpoint },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SPOKE: Application route table (app_a, app_b).
# ---------------------------------------------------------------------------
module "rt_spoke_app" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "spoke-app"
  vpc_id           = module.spoke_vpc.vpc_id
  subnet_ids       = [module.spoke_vpc.subnet_ids["app_a"], module.spoke_vpc.subnet_ids["app_b"]]
  routes = [
    { destination_cidr = var.hub_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
    { destination_cidr = "0.0.0.0/0", target_type = "transit_gateway", target_id = local.tgw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SPOKE: RDS subnet route table.
#
# Structural only for now - no RDS instance is created yet (see README.md
# "Reference Diagram Additions Not Yet Implemented"). Deliberately has NO
# 0.0.0.0/0 route at all: a database subnet should never have an internet
# path, only reachability to the rest of the private network (Hub) if a
# future need arises (e.g. cross-VPC replication tooling, DB admin access
# via SSM port-forwarding through a Spoke instance).
# ---------------------------------------------------------------------------
module "rt_spoke_rds" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "spoke-rds"
  vpc_id           = module.spoke_vpc.vpc_id
  subnet_ids       = [module.spoke_vpc.subnet_ids["rds_a"], module.spoke_vpc.subnet_ids["rds_b"]]
  routes = [
    { destination_cidr = var.hub_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
  ]
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SPOKE: TGW subnet route table (tgw_a, tgw_b).
# Same fidelity note as rt_hub_tgw above applies here.
# ---------------------------------------------------------------------------
module "rt_spoke_tgw" {
  source = "./modules/route-table"

  name_prefix      = local.name_prefix
  route_table_name = "spoke-tgw"
  vpc_id           = module.spoke_vpc.vpc_id
  subnet_ids       = [module.spoke_vpc.subnet_ids["tgw_a"], module.spoke_vpc.subnet_ids["tgw_b"]]
  routes = [
    { destination_cidr = var.hub_vpc_cidr, target_type = "transit_gateway", target_id = local.tgw_id },
  ]
  tags = local.common_tags
}
