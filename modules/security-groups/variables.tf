variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "hub_vpc_id" {
  description = "Hub VPC ID."
  type        = string
}

variable "hub_vpc_cidr" {
  description = "Hub VPC CIDR (used for cross-VPC rules that cannot use SG references)."
  type        = string
}

variable "spoke_vpc_id" {
  description = "Spoke VPC ID."
  type        = string
}

variable "spoke_vpc_cidr" {
  description = "Spoke VPC CIDR."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
