############################################################
# Root module variables. Every environment (dev/staging/prod) supplies its
# own values for these via terraform.tfvars - the module logic itself never
# changes between environments.
############################################################

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name, used in the naming prefix and tags."
  type        = string
  default     = "aws-hub-spoke"
}

variable "owner" {
  description = "Team or individual responsible for this infrastructure."
  type        = string
  default     = "Platform-Team"
}

variable "cost_center" {
  description = "Cost center tag value."
  type        = string
  default     = "unassigned"
}

############################
# Networking
############################

variable "availability_zones" {
  description = "Exactly two Availability Zones used throughout the platform."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two Availability Zones are required by this architecture."
  }
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the Hub VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.hub_vpc_cidr, 0))
    error_message = "hub_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "spoke_vpc_cidr" {
  description = "CIDR block for the Spoke VPC."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.spoke_vpc_cidr, 0))
    error_message = "spoke_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "hub_subnet_cidrs" {
  description = "Hub subnet CIDRs by logical name. Defaults match the reference architecture diagram exactly."
  type        = map(string)
  default = {
    tgw_a    = "10.0.1.0/28"
    tgw_b    = "10.0.2.0/28"
    nat      = "10.0.3.0/28"
    firewall = "10.0.4.0/28"
    alb_a    = "10.0.5.0/28"
    alb_b    = "10.0.6.0/28"
    bastion  = "10.0.7.0/28" # reserved subnet slot - no instance is deployed here (see README "SSM instead of Bastion")
  }
}

variable "spoke_subnet_cidrs" {
  description = "Spoke subnet CIDRs by logical name. Defaults match the reference architecture diagram exactly."
  type        = map(string)
  default = {
    app_a = "10.1.1.0/24"
    app_b = "10.1.2.0/24"
    rds_a = "10.1.3.0/24" # reserved subnet slot - no RDS instance is created yet, structural only
    rds_b = "10.1.4.0/24" # reserved subnet slot - no RDS instance is created yet, structural only
    tgw_a = "10.1.5.0/28"
    tgw_b = "10.1.6.0/28"
  }
}

variable "tgw_asn" {
  description = "Amazon-side ASN for the Transit Gateway."
  type        = number
  default     = 64512
}

############################
# Compute
############################

variable "key_name" {
  description = "Optional EC2 key pair name for Spoke application instances. Administrative access is via SSM Session Manager by default (see README \"SSM instead of Bastion\") - this is only needed if you want an SSH fallback in addition to SSM."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Instance type for Spoke application instances."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for Spoke application instances. Leave null to dynamically discover the latest Amazon Linux 2023 AMI."
  type        = string
  default     = null
}

variable "alb_name" {
  description = "Name of the Hub ALB."
  type        = string
  default     = "hub-spoke-alb"
}

variable "nlb_name" {
  description = "Name of the internal Spoke NLB."
  type        = string
  default     = "hub-spoke-nlb"
}

variable "asg_min_size" {
  description = "Minimum Spoke ASG size."
  type        = number
  default     = 2
}

variable "asg_desired_size" {
  description = "Desired Spoke ASG capacity."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum Spoke ASG size."
  type        = number
  default     = 4

  validation {
    condition     = var.asg_min_size <= var.asg_desired_size && var.asg_desired_size <= var.asg_max_size
    error_message = "Must hold: asg_min_size <= asg_desired_size <= asg_max_size."
  }
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization (%) for the Spoke ASG's Target Tracking scaling policy."
  type        = number
  default     = 50

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "scaling_estimated_warmup" {
  description = "Seconds a newly launched Spoke instance is given to warm up before counting toward the CPU target tracking policy's aggregated metric."
  type        = number
  default     = 180
}

variable "manage_ssm_agent" {
  description = "Whether to prepend an idempotent SSM Agent verify/install/enable/start step to Spoke instance user_data. Recommended true; safe even on AMIs that already include the agent."
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable 1-minute detailed CloudWatch monitoring on Spoke instances. Recommended true when using CPU-based Target Tracking scaling, since it lets the ASG react to CPU changes roughly 4x faster than the default 5-minute metric."
  type        = bool
  default     = false
}

############################
# Observability
############################

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs for the Hub and Spoke VPCs."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to create the CloudWatch alarms in modules/monitoring."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention (days) applied to flow logs, firewall logs, and Lambda logs."
  type        = number
  default     = 30
}

variable "enable_firewall_delete_protection" {
  description = "Whether to enable delete protection on the AWS Network Firewall. Recommended true for prod."
  type        = bool
  default     = false
}

variable "enable_lb_deletion_protection" {
  description = "Whether to enable deletion protection on the ALB and NLB. Recommended true for staging/prod."
  type        = bool
  default     = false
}

############################
# Tagging
############################

variable "tags" {
  description = "Additional free-form tags merged into every resource's tag set."
  type        = map(string)
  default     = {}
}

variable "admin_cidr" {
  description = "CIDR block allowed for administrative access"
  type        = string
}

