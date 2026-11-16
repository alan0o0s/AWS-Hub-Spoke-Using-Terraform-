variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "subnet_id" {
  description = "ID of the (Hub) public NAT subnet to place the NAT Gateway in."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
