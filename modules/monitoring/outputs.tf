output "alarm_arns" {
  description = "ARNs of all alarms created by this module, useful for wiring to an SNS topic later."
  value = [
    aws_cloudwatch_metric_alarm.alb_unhealthy_targets.arn,
    aws_cloudwatch_metric_alarm.nlb_unhealthy_targets.arn,
    aws_cloudwatch_metric_alarm.asg_capacity.arn,
    aws_cloudwatch_metric_alarm.ec2_status_check_failed.arn,
  ]
}
