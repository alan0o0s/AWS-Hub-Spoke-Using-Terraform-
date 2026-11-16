############################################################
# Meaningful operational alarms only - deliberately not "hundreds of
# alarms" (per design principle 27), just the handful of signals that
# actually indicate a problem an operator needs to act on.
############################################################

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "The Hub ALB's target (the Spoke NLB's static IPs) is unhealthy - this generally means the NLB itself has zero healthy backend instances, since the ALB health check is effectively checking NLB reachability."

  dimensions = {
    TargetGroup  = var.alb_target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_targets" {
  alarm_name          = "${var.name_prefix}-nlb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more internal NLB targets are unhealthy."

  dimensions = {
    TargetGroup  = var.nlb_target_group_arn_suffix
    LoadBalancer = var.nlb_arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "asg_capacity" {
  alarm_name          = "${var.name_prefix}-asg-below-desired-capacity"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.asg_desired_capacity
  alarm_description   = "Spoke ASG has fewer in-service instances than desired capacity."

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name          = "${var.name_prefix}-ec2-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "One or more Spoke ASG instances are failing EC2 status checks."

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  tags = var.tags
}
