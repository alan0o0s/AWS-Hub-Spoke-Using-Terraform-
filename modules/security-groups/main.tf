############################################################
# Security group architecture.
#
# No SSH port is opened anywhere in this platform. Administrative access is
# entirely via AWS Systems Manager Session Manager. The Spoke application
# IAM role carries AmazonSSMManagedInstanceCore.
#
# Session Manager requires no inbound port. It only requires outbound HTTPS
# access to the regional SSM endpoints.
#
# IMPORTANT cross-VPC limitation:
# Security-group-by-reference works only for security groups in the same VPC,
# or across VPC Peering when the referenced security groups feature is enabled.
#
# Hub and Spoke are connected through Transit Gateway, which does not support
# cross-VPC security group references. Therefore, cross-VPC rules use CIDR
# ranges instead of security group references.
############################################################


# ---------------------------------------------------------------------------
# ALB security group - Hub VPC public entry point.
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Internet facing Hub ALB allows public HTTP"
  vpc_id      = var.hub_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from Internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ---------------------------------------------------------------------------
# Internal NLB security group - Spoke VPC.
# ---------------------------------------------------------------------------

resource "aws_security_group" "nlb" {
  name_prefix = "${var.name_prefix}-nlb-"
  description = "Internal NLB allows private sources only"
  vpc_id      = var.spoke_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_http_from_hub" {
  security_group_id = aws_security_group.nlb.id
  description       = "Allow HTTP from Hub VPC"
  cidr_ipv4         = var.hub_vpc_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nlb_http_from_spoke" {
  security_group_id = aws_security_group.nlb.id
  description       = "Allow HTTP from Spoke VPC"
  cidr_ipv4         = var.spoke_vpc_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nlb_all_out" {
  security_group_id = aws_security_group.nlb.id
  description       = "Allow all outbound traffic to targets"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ---------------------------------------------------------------------------
# Spoke application security group - Spoke VPC.
# ---------------------------------------------------------------------------

resource "aws_security_group" "spoke_app" {
  name_prefix = "${var.name_prefix}-spoke-app-"
  description = "Spoke application instances use SSM without SSH"
  vpc_id      = var.spoke_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Same VPC reference:
# The NLB and application instances are both in the Spoke VPC.
# Therefore, a security group reference is supported here.

resource "aws_vpc_security_group_ingress_rule" "app_http_from_nlb" {
  security_group_id            = aws_security_group.spoke_app.id
  description                  = "Allow HTTP from internal NLB"
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.spoke_app.id
  description       = "Allow application outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}