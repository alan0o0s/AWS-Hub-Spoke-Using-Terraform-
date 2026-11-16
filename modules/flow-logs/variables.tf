variable "name_prefix" {
  description = "Naming prefix (should include which VPC this is for, e.g. company-network-hub-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC to enable flow logs for."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
