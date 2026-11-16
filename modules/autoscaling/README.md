# Module: autoscaling

Creates the Spoke Auto Scaling Group and attaches it to the internal NLB's
target group using ASG's native `target_group_arns` (works because the NLB
target group is same-VPC/instance-type).

This module has no relationship with the Hub ALB at all - the ALB targets
the NLB's two static private IPs (see `modules/nlb` and `modules/alb`), not
individual ASG instances, so the ASG never needs to know the ALB exists.
