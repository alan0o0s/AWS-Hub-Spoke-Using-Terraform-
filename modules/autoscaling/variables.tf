variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "subnet_ids" {
  description = "Spoke application subnet IDs (one per AZ) - instances are distributed across both."
  type        = list(string)
}

variable "launch_template_id" {
  description = "Launch template ID."
  type        = string
}

variable "launch_template_version" {
  description = "Launch template version to use."
  type        = string
  default     = "$Latest"
}

variable "nlb_target_group_arn" {
  description = "ARN of the internal NLB's target group (same-VPC, uses native ASG attachment). Null to skip attachment."
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum ASG size."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired ASG capacity."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum ASG size."
  type        = number
  default     = 4

  validation {
    condition     = var.min_size <= var.desired_capacity && var.desired_capacity <= var.max_size
    error_message = "Must hold: min_size <= desired_capacity <= max_size."
  }
}

variable "health_check_grace_period" {
  description = "Seconds to wait before starting ELB health checks on a new instance."
  type        = number
  default     = 90
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization (%) for the CPU-based Target Tracking scaling policy."
  type        = number
  default     = 20

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "scaling_estimated_warmup" {
  description = "Seconds a newly launched instance is given to warm up before its metrics count toward the target tracking policy's aggregated CPU metric."
  type        = number
  default     = 180
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
