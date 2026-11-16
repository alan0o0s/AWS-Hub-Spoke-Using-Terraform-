############################################################
# Internal Network Load Balancer - Spoke VPC, private clients only.
#
# STATIC IP DESIGN: this NLB is given a fixed, known private IP in each AZ's
# subnet (via subnet_mapping.private_ipv4_address). NLBs keep the same IP(s)
# for their entire lifetime - they don't get replaced/rotated the way an
# ALB's IPs can. That fixed-IP property is exactly what makes it possible
# for the Hub ALB (modules/alb) to register these 2 IPs as STATIC IP-type
# targets and never need to update them again, no matter how the Spoke ASG
# behind this NLB scales or replaces instances - the NLB always routes to
# whatever instance is currently healthy using its own native, same-VPC ASG
# attachment. This is what eliminates the need for any dynamic
# registration mechanism (Lambda, etc.) on the ALB side entirely.
############################################################

resource "aws_lb" "nlb" {
  name               = var.nlb_name
  internal           = true # MUST remain internal - never expose the NLB publicly
  load_balancer_type = "network"
  security_groups    = [var.nlb_sg_id]

  dynamic "subnet_mapping" {
    for_each = var.subnet_ids
    content {
      subnet_id            = subnet_mapping.value
      private_ipv4_address = var.static_ips[subnet_mapping.key]
    }
  }

  # Both AZs' targets share load evenly rather than each AZ only serving its
  # own local ENI's share of traffic - matters here since instance count can
  # be uneven across AZs during ASG scaling events.
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.enable_deletion_protection

  tags = merge(var.tags, { Name = var.nlb_name })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.nlb_name}-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id

  # Same-VPC target model: the NLB and the ASG instances are both in the
  # Spoke, so instance-type targets (native ASG attachment) are correct here
  # - unlike the cross-VPC ALB, which must use IP targets.
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(var.tags, { Name = "${var.nlb_name}-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "tcp80" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
