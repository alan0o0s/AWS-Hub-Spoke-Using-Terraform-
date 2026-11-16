variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for application instances. Leave null to dynamically discover the latest Amazon Linux 2023 AMI."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Instance type for application instances."
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access via the Bastion. Optional - null disables key-based SSH."
  type        = string
  default     = null
}

variable "security_group_id" {
  description = "Security group ID to attach (spoke_app_sg)."
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name to attach."
  type        = string
}

variable "user_data" {
  description = <<-EOT
    Raw (not base64-encoded) user-data script. Defaults to a minimal Apache
    bootstrap matching the reference architecture, but is fully overridable
    so the bootstrap logic isn't hard-coded into the module.
  EOT
  type        = string
  default     = <<-USERDATA
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl enable httpd
    systemctl start httpd
    echo "Application Server - Spoke ASG - $(hostname -f)" > /var/www/html/index.html
  USERDATA
}

variable "manage_ssm_agent" {
  description = <<-EOT
    Whether to prepend an idempotent SSM Agent verify/install/enable/start
    step to user_data. Safe to leave true even on AMIs (like the default
    Amazon Linux 2023 AMI) that already ship the agent pre-installed and
    enabled - the bootstrap detects that and skips straight to a no-op
    verification instead of reinstalling anything.
  EOT
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB)."
  type        = number
  default     = 10
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed (1-minute) CloudWatch monitoring."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
