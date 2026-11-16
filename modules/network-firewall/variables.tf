variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "hub_vpc_id" {
  description = "Hub VPC ID."
  type        = string
}

variable "hub_vpc_cidr" {
  description = "Hub VPC CIDR, added to the firewall's HOME_NET IP set."
  type        = string
}

variable "spoke_vpc_cidr" {
  description = "Spoke VPC CIDR, added to the firewall's HOME_NET IP set."
  type        = string
}

variable "additional_internal_cidrs" {
  description = "CIDRs of any additional (future) Spoke VPCs to include in HOME_NET without redefining the rule group."
  type        = list(string)
  default     = []
}

variable "firewall_subnet_ids" {
  description = "Hub firewall-dedicated subnet IDs (one per AZ)."
  type        = list(string)
}

variable "delete_protection" {
  description = "Whether to enable delete protection on the firewall (recommend true for prod)."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for firewall flow/alert logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
