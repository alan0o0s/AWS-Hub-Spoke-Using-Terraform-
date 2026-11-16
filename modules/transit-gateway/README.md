# Module: transit-gateway

Creates one Transit Gateway, attaches the Hub and Spoke VPCs to it, and adds
the one static route (`0.0.0.0/0` -> Hub attachment) that VPC-CIDR
propagation cannot express on its own.

## Why Appliance Mode is enabled (Hub attachment only)

**The problem - asymmetric routing:** the Transit Gateway normally load-balances
flows across the Availability Zone subnets of a VPC attachment using a
per-flow hash. For a stateless resource that's fine. But the Hub contains a
**stateful** AWS Network Firewall endpoint per AZ. A firewall endpoint in
`us-east-2a` tracks connection state only for packets it has actually seen.
If the TGW sends a flow's outbound (SYN) packet through the `us-east-2a`
Hub subnet/firewall endpoint, but its return (SYN-ACK) packet through the
`us-east-2b` Hub subnet/firewall endpoint, the `us-east-2b` firewall endpoint
has no record of that connection and will drop the return packet as
unrecognized/invalid state - the flow silently fails, and it's timing- and
load-dependent, so it doesn't fail consistently (making it a nightmare to
debug without knowing to look for this).

**How Appliance Mode fixes it:** with `appliance_mode_support = "enable"` on
the Hub's TGW attachment, the TGW pins each flow (5-tuple hash) to a single
Availability Zone for the lifetime of that flow, in both directions. The
forward and return legs of a given connection are guaranteed to traverse the
same Hub AZ (and therefore the same Network Firewall endpoint), keeping
firewall state tracking consistent.

Appliance Mode is enabled **only** on the Hub attachment. The Spoke
attachment doesn't front a stateful appliance, so enabling it there would add
no benefit (and would reduce the TGW's ability to spread Spoke-side flows
across AZs for its own attachment).

## Routing model

- VPC CIDR routes (`10.0.0.0/16`, `10.1.0.0/16`) reach the TGW's default
  route table automatically via `transit_gateway_default_route_table_propagation = true`
  on each attachment - no manual route needed for these.
- `0.0.0.0/0 -> Hub attachment` is added as one explicit
  `aws_ec2_transit_gateway_route`, because attachment propagation can only
  ever propagate the attached VPC's own CIDR, never a default route.

## Inputs / Outputs

See `variables.tf` / `outputs.tf`.
