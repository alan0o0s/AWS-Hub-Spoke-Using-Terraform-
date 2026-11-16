variable "name_prefix" {
  description = "Prefix used for naming resources (e.g. company-network-hub-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for this VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "subnets" {
  description = <<-EOT
    Map of subnets to create in this VPC. Key = logical subnet name (e.g.
    "firewall", "bastion", "alb_a"), value = { cidr, az }. Using a typed map
    instead of a variable per subnet keeps this module identical for the Hub,
    the Spoke, and any future Spoke VPC.
  EOT
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "create_internet_gateway" {
  description = "Whether to create and attach an Internet Gateway to this VPC. Only the Hub should set this to true - the Spoke must never have one."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
