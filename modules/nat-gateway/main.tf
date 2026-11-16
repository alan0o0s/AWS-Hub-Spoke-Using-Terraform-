############################################################
# NAT Gateway module - centralized Hub egress point.
#
# Kept separate from the vpc module: unlike subnets/IGW (structural, created
# once per VPC), a NAT Gateway is a routing/egress concern tied to a specific
# subnet and AZ, and conceptually sits alongside transit-gateway and
# network-firewall as "traffic infrastructure" rather than "VPC structure".
############################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.subnet_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat"
  })
}
