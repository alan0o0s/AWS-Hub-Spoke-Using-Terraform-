variable "nlb_name" {
  description = "Name of the internal NLB."
  type        = string
}

variable "vpc_id" {
  description = "Spoke VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Spoke application subnet IDs (one per AZ), in the SAME order as static_ips."
  type        = list(string)
}

variable "static_ips" {
  description = <<-EOT
    Fixed private IPv4 address for the NLB in each subnet, same order as
    subnet_ids. These are computed in the root module (cidrhost() on each
    app subnet's CIDR) and passed to both this module AND modules/alb, so
    the ALB can register them as permanent static targets without either
    module depending on the other's outputs (avoids a dependency cycle).
  EOT
  type        = list(string)
}

variable "nlb_sg_id" {
  description = "Security group ID for the NLB."
  type        = string
}

variable "enable_deletion_protection" {
  description = "Whether to enable NLB deletion protection. Recommend true for staging/prod."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
