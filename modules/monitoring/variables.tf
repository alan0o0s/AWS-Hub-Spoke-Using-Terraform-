variable "name_prefix" {
  description = "Naming prefix."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Hub ALB (aws_lb.alb.arn_suffix), required by CloudWatch dimensions."
  type        = string
}

variable "alb_target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group (aws_lb_target_group.app.arn_suffix)."
  type        = string
}

variable "nlb_arn_suffix" {
  description = "ARN suffix of the internal NLB."
  type        = string
}

variable "nlb_target_group_arn_suffix" {
  description = "ARN suffix of the NLB target group."
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Spoke ASG."
  type        = string
}

variable "asg_desired_capacity" {
  description = "The ASG's configured desired capacity, used as the alarm threshold for GroupInServiceInstances."
  type        = number
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
