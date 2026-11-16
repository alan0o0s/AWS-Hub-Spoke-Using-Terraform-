variable "alb_name" {
  description = "Name of the ALB (e.g. Peter-ALB, or an enterprise-neutral equivalent)."
  type        = string
}

variable "hub_vpc_id" {
  description = "Hub VPC ID (the ALB's own VPC)."
  type        = string
}

variable "subnet_ids" {
  description = "Hub ALB subnet IDs (one per AZ)."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "enable_deletion_protection" {
  description = "Whether to enable ALB deletion protection. Recommend true for staging/prod."
  type        = bool
  default     = false
}

variable "nlb_static_ips" {
  description = "The Spoke internal NLB's two static, permanent private IPs (see modules/nlb). Registered once as the ALB's targets and never updated again."
  type        = list(string)
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
