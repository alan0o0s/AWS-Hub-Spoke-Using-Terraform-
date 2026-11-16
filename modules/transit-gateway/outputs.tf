output "transit_gateway_id" {
  description = "ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "default_route_table_id" {
  description = "ID of the TGW's default (association + propagation) route table."
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

output "hub_attachment_id" {
  description = "ID of the Hub VPC's TGW attachment (Appliance Mode enabled)."
  value       = aws_ec2_transit_gateway_vpc_attachment.hub.id
}

output "spoke_attachment_id" {
  description = "ID of the Spoke VPC's TGW attachment."
  value       = aws_ec2_transit_gateway_vpc_attachment.spoke.id
}
