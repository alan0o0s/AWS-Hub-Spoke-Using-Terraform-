############################################################
# Generic VPC module.
#
# Used for BOTH the Hub and Spoke VPCs. The caller supplies a map of subnets
# (name => { cidr, az, public }) so the same module works for every VPC in
# the platform, and for future Spokes, without duplicating VPC/subnet logic.
############################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false # never auto-assign public IPs; ALB/NAT get EIPs explicitly where needed

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}"
    Tier = each.key
  })
}

# Internet Gateway is optional per-VPC: the Hub gets one, the Spoke never does.
resource "aws_internet_gateway" "this" {
  count = var.create_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Every VPC gets an implicit default security group that nothing in this
# platform is meant to use (every resource has its own purpose-built SG from
# modules/security-groups). Lock it down to deny all traffic so it can't be
# accidentally attached to something and provide unintended broad access.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress, no egress - intentionally empty.

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-default-sg-locked-down"
  })
}
