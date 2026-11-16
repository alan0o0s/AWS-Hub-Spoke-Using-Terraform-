output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = aws_nat_gateway.this.id
}

output "elastic_ip" {
  description = "Public Elastic IP address associated with the NAT Gateway."
  value       = aws_eip.nat.public_ip
}
