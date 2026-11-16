# Module: network-firewall

Deploys AWS Network Firewall in the Hub with one stateful rule group
(PASS 80/443/53-tcp/53-udp for internal sources, DROP everything else) and
CloudWatch flow/alert logging.

## Rule ordering (SID 5-9)

`rule_group.stateful_rule_options.rule_order = "STRICT_ORDER"` (rule-group
level) **and** `firewall_policy.stateful_engine_options.rule_order =
"STRICT_ORDER"` (policy level) are both set. AWS requires this pairing: the
policy-level setting controls evaluation order across rule groups attached
to the policy (only one here, but future rule groups would need this too),
and the rule-group-level setting controls evaluation order *within* this
specific group, guaranteeing SID 5-8 (explicit PASS) are evaluated before
SID 9 (default DROP) rather than relying on AWS's default
pass/drop/alert-precedence behavior, which does not respect rule position.

## HOME_NET as a rule variable, not per-SID duplication

The design calls each PASS rule's source "`10.0.0.0/16` **and**
`10.1.0.0/16`". Rather than writing two near-duplicate `stateful_rule` blocks
per SID (one per source CIDR - 8 blocks instead of 4), both networks are
defined once as a `HOME_NET` IP set variable and referenced as `$HOME_NET` in
each rule's `source`. Adding a future Spoke's CIDR to
`additional_internal_cidrs` extends every existing PASS rule automatically.

## What this module does *not* do

It does not create any route table entries. It only exposes
`endpoint_ids_by_az` so the root configuration's `route-table` module calls
can route `0.0.0.0/0` (from the Hub TGW subnet) and the Spoke CIDR (from the
NAT subnet) through the correct AZ's firewall endpoint. See
`ARCHITECTURE.md` for the full packet-path diagram.
