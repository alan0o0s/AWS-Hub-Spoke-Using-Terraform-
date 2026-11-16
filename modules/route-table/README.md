# Module: route-table

Generic route table module: one route table, an explicit list of routes, and
subnet (or IGW-edge) associations. This is the platform's **routing
abstraction layer** - see `ARCHITECTURE.md` section "Routing Abstraction".

## Why routes live here and not inside the ALB/TGW/Firewall modules

Section 41 of the design requirements is explicit: the ALB module must not
create TGW routes, the TGW module must not create application subnet routes,
and the Firewall module should only *expose* its endpoint IDs. Centralizing
every route in one small, reusable module means:

- Every route in the platform is visible by grepping one module's callers in
  `main.tf`, instead of being scattered across a dozen modules.
- Circular module dependencies are avoided (e.g. the firewall module never
  needs to know about the NAT module or vice versa - the root module wires
  `network_firewall.endpoint_ids["nat"]` into a `route-table` call instead).

## Edge (IGW) associations

Set `edge_gateway_id` to associate a route table directly with an Internet
Gateway rather than a subnet. This implements "Internet Gateway ingress
routing", required so return traffic from the internet is routed through the
Network Firewall endpoint instead of going directly to the NAT Gateway.

## Inputs / Outputs

See `variables.tf` / `outputs.tf` for the full, documented interface.
