############################################################
# Generic route table module.
#
# This is the "routing abstraction" layer (see ARCHITECTURE.md): no other
# module creates routes for a route table it doesn't own. The root
# configuration wires concrete target IDs (NAT GW, TGW, Firewall endpoint,
# IGW) from other modules' outputs into this module's `routes` variable,
# keeping route intent visible and auditable in one place per logical table.
############################################################

resource "aws_route_table" "this" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.route_table_name}-rt"
  })
}

resource "aws_route" "this" {
  for_each = { for idx, r in var.routes : tostring(idx) => r }

  route_table_id         = aws_route_table.this.id
  destination_cidr_block = each.value.destination_cidr

  gateway_id         = each.value.target_type == "gateway" ? each.value.target_id : null
  nat_gateway_id     = each.value.target_type == "nat_gateway" ? each.value.target_id : null
  transit_gateway_id = each.value.target_type == "transit_gateway" ? each.value.target_id : null
  vpc_endpoint_id    = each.value.target_type == "vpc_endpoint" ? each.value.target_id : null
}

resource "aws_route_table_association" "subnet" {
  for_each = {
    for idx, subnet_id in var.subnet_ids :
    idx => subnet_id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.this.id
}

# Edge association: attaches this route table to an Internet Gateway itself
# (ingress routing) rather than to a subnet. Required so that return traffic
# entering the Hub through the IGW (destined for the NAT Gateway's public IP)
# is redirected to the Network Firewall endpoint first, instead of going
# straight to the NAT Gateway and bypassing inspection on the return path.
# See ARCHITECTURE.md "Symmetric Routing / IGW Ingress Routing".
resource "aws_route_table_association" "edge" {
  count = var.create_edge_association ? 1 : 0

  gateway_id     = var.edge_gateway_id
  route_table_id = aws_route_table.this.id
}
