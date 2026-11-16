############################################################
# AWS Network Firewall module - centralized inspection point in the Hub.
#
# Exposes only what other modules need: the firewall's VPC endpoint ID per
# Availability Zone (so the route-table module can route traffic to it). It
# does NOT create any routes itself - see modules/route-table and
# ARCHITECTURE.md "Routing Abstraction".
############################################################

# ip_sets variable so PASS rules cover both the Hub and Spoke CIDR (and any
# future Spoke CIDR added later) from a single rule definition per SID,
# rather than duplicating each SID once per source network.
locals {
  internal_networks = concat([var.hub_vpc_cidr, var.spoke_vpc_cidr], var.additional_internal_cidrs)
}

resource "aws_networkfirewall_rule_group" "stateful" {
  name     = "${var.name_prefix}-stateful-rules"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = local.internal_networks
        }
      }
    }

    # Deterministic, top-to-bottom rule evaluation within this rule group -
    # required so the catch-all DROP (SID 9) is guaranteed to be evaluated
    # only after the explicit PASS rules (SID 5-8), never before.
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      # SID 5 - HTTP
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "TCP"
          source           = "$HOME_NET"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "80"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["5"]
        }
      }

      # SID 6 - HTTPS
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "TCP"
          source           = "$HOME_NET"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "443"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["6"]
        }
      }

      # SID 7 - DNS over TCP
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "TCP"
          source           = "$HOME_NET"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "53"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["7"]
        }
      }

      # SID 8 - DNS over UDP
      stateful_rule {
        action = "PASS"
        header {
          protocol         = "UDP"
          source           = "$HOME_NET"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "53"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["8"]
        }
      }

      # SID 9 - default-deny catch-all. STRICT_ORDER above guarantees this is
      # evaluated last, after SID 5-8 have had a chance to PASS matching traffic.
      stateful_rule {
        action = "DROP"
        header {
          protocol         = "IP"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
        }
        rule_option {
          keyword  = "sid"
          settings = ["9"]
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name_prefix}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful.arn
      priority     = 1
    }

    # Policy-level strict ordering + explicit default action. Required
    # pairing when STRICT_ORDER is used: AWS requires stateful_default_actions
    # to be set explicitly rather than relying on an implicit default.
    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
    stateful_default_actions = ["aws:drop_strict"]
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.hub_vpc_id
  delete_protection   = var.delete_protection

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-firewall"
  })
}

############################################################
# Firewall logging - flow + alert logs to CloudWatch (see requirement 27/28).
############################################################

resource "aws_cloudwatch_log_group" "firewall" {
  name              = "/aws/network-firewall/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

############################################################
# Per-AZ VPC endpoint IDs, extracted from firewall_status. Consumed by the
# route-table module calls in the root configuration to route traffic to the
# firewall endpoint in each specific AZ.
############################################################

locals {
  endpoint_by_az = {
    for s in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    s.availability_zone => s.attachment[0].endpoint_id
  }
}
