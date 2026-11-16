variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "route_table_name" {
  description = "Logical name of this route table (e.g. \"alb\", \"firewall\", \"nat\", \"spoke-app\")."
  type        = string
}

variable "vpc_id" {
  description = "VPC this route table belongs to."
  type        = string
}

variable "routes" {
  description = <<-EOT
    List of routes to create. Each entry:
      destination_cidr = "0.0.0.0/0"
      target_type       = one of "gateway" | "nat_gateway" | "transit_gateway" | "vpc_endpoint" | "instance"
      target_id         = the concrete resource ID for that target type
  EOT
  type = list(object({
    destination_cidr = string
    target_type      = string
    target_id        = string
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.routes : contains(
        ["gateway", "nat_gateway", "transit_gateway", "vpc_endpoint", "instance"],
        r.target_type
      )
    ])
    error_message = "target_type must be one of: gateway, nat_gateway, transit_gateway, vpc_endpoint, instance."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs to associate with this route table (normal subnet associations)."
  type        = list(string)
  default     = []
}

variable "edge_gateway_id" {
  description = "If set, associate this route table with an Internet Gateway for edge/ingress routing instead of (or in addition to) subnet associations."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
variable "create_edge_association" {
  description = "Whether to associate the route table with an edge gateway"
  type        = bool
  default     = false
}