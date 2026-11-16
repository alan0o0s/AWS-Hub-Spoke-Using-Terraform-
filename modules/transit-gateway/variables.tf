variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "amazon_side_asn" {
  description = "Amazon-side ASN for the Transit Gateway."
  type        = number
  default     = 64512
}

variable "hub_vpc_id" {
  description = "Hub VPC ID."
  type        = string
}

variable "hub_tgw_subnet_ids" {
  description = "Hub TGW-dedicated subnet IDs (one per AZ)."
  type        = list(string)
}

variable "spoke_vpc_id" {
  description = "Spoke VPC ID."
  type        = string
}

variable "spoke_tgw_subnet_ids" {
  description = "Spoke TGW-dedicated subnet IDs (one per AZ)."
  type        = list(string)
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
