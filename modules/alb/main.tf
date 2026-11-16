############################################################
# Internet-facing Application Load Balancer - Hub VPC, public entry point.
#
# CRITICAL cross-VPC design: the ALB lives in the Hub, but its target (the
# Spoke's internal NLB) lives in the Spoke. This requires target_type = "ip"
# rather than "instance" - AWS does not allow instance-type targets outside
# the ALB's own VPC, but IP-type targets may be any address routable from
# the load balancer, which the NLB's private IPs are, via the Transit
# Gateway.
#
# WHY THIS NEEDS NO DYNAMIC REGISTRATION: the ALB's targets here are the
# Spoke NLB's two static, permanent private IPs (see modules/nlb "Static
# private IPs") - NOT the individual, ever-changing ASG instance IPs. Since
# an NLB's IP addresses never change for its lifetime, these two
# aws_lb_target_group_attachment resources below are registered ONCE and
# never need to be touched again, regardless of how the ASG behind the NLB
# scales or replaces instances. The NLB's own native, same-VPC ASG
# attachment (modules/autoscaling) handles routing to whichever instances
# are currently healthy - this module doesn't need to know anything about
# individual instances at all.
############################################################

resource "aws_lb" "alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  subnets            = var.subnet_ids
  security_groups    = [var.alb_sg_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, { Name = var.alb_name })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.alb_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.hub_vpc_id # the ALB's own VPC, per AWS's cross-VPC IP-target model
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.alb_name}-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# The two permanent, static NLB IPs - registered once, never re-touched.
resource "aws_lb_target_group_attachment" "nlb_static_targets" {
  for_each = toset(var.nlb_static_ips)

  target_group_arn  = aws_lb_target_group.app.arn
  target_id         = each.value
  port              = 80
  availability_zone = "all"
}
