############################################################
# Spoke Auto Scaling Group.
#
# This ASG only ever attaches to the internal NLB's target group (same-VPC,
# native mechanism). It has no relationship at all with the Hub ALB - the
# ALB's targets are the NLB's two static private IPs (see modules/nlb
# "Static private IPs" and modules/alb), not individual ASG instances. This
# is what makes it possible for the ASG to remain completely unaware of the
# ALB's existence: it only needs to keep the NLB's target group correct,
# which AWS's native target_group_arns mechanism already does automatically.
############################################################

resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.name_prefix}-asg-"
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  # Same-VPC target group (the internal NLB) - ASG's native mechanism works
  # fine here because the NLB and the app instances share the Spoke VPC.
  target_group_arns = var.nlb_target_group_arn == null ? [] : [var.nlb_target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = var.launch_template_id
    version = var.launch_template_version
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name_prefix}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################################################
# CPU-based Target Tracking scaling policy.
#
# AWS manages this natively: it creates and owns two CloudWatch alarms
# (high/low) behind the scenes off the ASGAverageCPUUtilization predefined
# metric, continuously compares the ASG's actual average CPU against
# var.target_cpu_utilization, and adds/removes instances as needed to track
# that target - scale-out and scale-in are both handled by this single
# policy, there is no separate "scale up" / "scale down" policy to write.
# No custom CloudWatch alarms or Lambda are needed for this; the native
# metric and policy type are sufficient.
############################################################
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name_prefix}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.target_cpu_utilization
    disable_scale_in = false
  }

  # Grace period, in seconds, before a newly launched instance's metrics
  # count toward the aggregated group metric - keeps a fleet of instances
  # still warming up from being read as "CPU still high" and triggering an
  # unnecessary second scale-out on top of the first.
  estimated_instance_warmup = var.scaling_estimated_warmup
}
