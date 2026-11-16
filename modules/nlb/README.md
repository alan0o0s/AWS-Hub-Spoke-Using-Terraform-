# Module: nlb

Internal (`internal = true`) Network Load Balancer in the Spoke VPC, fronting
the Spoke ASG with same-VPC instance targets. Never internet-facing.

## Static private IPs - the key design decision

This NLB is assigned a **fixed** private IP address in each AZ's subnet via
`subnet_mapping.private_ipv4_address`, rather than letting AWS pick one
dynamically. NLBs (unlike ALBs) keep the same IP address(es) for their
entire lifetime - AWS's own documentation guarantees this. That stability
is what makes it possible for `modules/alb` to register these two IPs as
**permanent** static IP-type targets, and never need to touch that
registration again regardless of how the Spoke ASG behind this NLB scales,
replaces, or reschedules instances - the NLB's own native, same-VPC ASG
attachment (`modules/autoscaling`) handles all of that automatically.

This is what eliminates the need for any dynamic/event-driven registration
mechanism on the cross-VPC ALB side - see `modules/alb/README.md` and
`ARCHITECTURE.md` "Dynamic Cross-VPC ALB Target Registration" for the full
before/after comparison.

Consumed by `modules/autoscaling` via `target_group_arn`, which the ASG
attaches to using its native `target_group_arns` mechanism.
