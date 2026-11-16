output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Map of logical subnet name to subnet ID."
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "subnet_arns" {
  description = "Map of logical subnet name to subnet ARN."
  value       = { for k, v in aws_subnet.this : k => v.arn }
}

output "subnet_azs" {
  description = "Map of logical subnet name to its Availability Zone."
  value       = { for k, v in aws_subnet.this : k => v.availability_zone }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway, if created (null otherwise)."
  value       = try(aws_internet_gateway.this[0].id, null)
}
