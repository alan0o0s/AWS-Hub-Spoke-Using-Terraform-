# Thin passthrough - only the region needs to exist here for the provider
# block above; every other variable is supplied via terraform.tfvars and
# forwarded straight into the root module below.
variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "key_name" {
  description = "Optional EC2 key pair name for Spoke instances (SSH fallback). Administrative access is via SSM Session Manager by default - see README.md \"SSM instead of Bastion\"."
  type        = string
  default     = null
}
