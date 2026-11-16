############################################################
# Transit Gateway module - central connectivity hub between Hub and Spoke(s).
#
# CRITICAL: Appliance Mode is enabled on the HUB attachment only. This is
# mandatory because the Hub contains a stateful AWS Network Firewall.
# See README.md "Why Appliance Mode" for the full explanation - in short,
# without it, the TGW can send a flow's forward and return packets through
# different Hub Availability Zones, and a stateful firewall in one AZ will
# silently drop return traffic it never saw the forward leg of.
############################################################

resource "aws_ec2_transit_gateway" "this" {
  description = "${var.name_prefix} Transit Gateway"

  amazon_side_asn = var.amazon_side_asn

  dns_support                     = "enable"
  multicast_support               = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw"
  })
}

############################################################
# Hub attachment - Appliance Mode ENABLED.
############################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.hub_vpc_id
  subnet_ids         = var.hub_tgw_subnet_ids

  dns_support            = "enable"
  appliance_mode_support = "enable" # <-- CRITICAL, see module README

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-attach-hub"
  })
}

############################################################
# Spoke attachment - normal mode (only one VPC on this side, so no
# asymmetric-routing risk; Appliance Mode is unnecessary here).
############################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.spoke_vpc_id
  subnet_ids         = var.spoke_tgw_subnet_ids

  dns_support = "enable"

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-attach-spoke"
  })
}

############################################################
# Explicit default-route: Spoke-originated internet-bound traffic must
# resolve to the Hub attachment inside the TGW route table. VPC CIDR routes
# (10.0.0.0/16, 10.1.0.0/16) reach the default route table automatically via
# propagation above - a 0.0.0.0/0 route can NOT be propagated from a VPC
# attachment, so this one static route is the necessary exception referenced
# in the design principles ("avoid unnecessary static routes... when AWS
# propagation is more appropriate" implies: use propagation for what it can
# do, and a static route for the one thing it structurally cannot).
############################################################

resource "aws_ec2_transit_gateway_route" "default_to_hub" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway.this.association_default_route_table_id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
}
