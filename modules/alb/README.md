# Module: alb

Internet-facing ALB in the Hub VPC with an **IP-type** target group pointing
across the Transit Gateway at the Spoke's **internal NLB's two static
private IPs** (not the individual ASG instances - see `modules/nlb` "Static
private IPs").

## Why `target_type = "ip"` and not `"instance"`

`instance`-type targets must be EC2 instances in the same VPC as the load
balancer. The NLB's ENIs live in the Spoke, connected via Transit Gateway,
which `instance`-type targets don't support across VPCs at all. `ip`-type
targets have no such restriction - any IP routable from the ALB's VPC
(which the NLB's private IPs are, via the TGW route in the Hub ALB subnet's
route table) can be registered.

## Why this needs no dynamic registration mechanism

Earlier versions of this design pointed the ALB directly at individual ASG
instance IPs, which required a Lambda-based dynamic registration mechanism
(ASG lifecycle hooks + EventBridge) because instance IPs constantly change
as the ASG scales/replaces instances. Pointing the ALB at the **NLB's**
IPs instead sidesteps that problem entirely: an NLB's private IP addresses
are permanent for the life of the load balancer (AWS guarantees this), so
the two `aws_lb_target_group_attachment` resources in this module are
created once and never need to change. The NLB's own native, same-VPC ASG
attachment handles all the actual instance-level routing and health
tracking - this module doesn't need any visibility into individual
instances at all.

See `ARCHITECTURE.md` "Dynamic Cross-VPC ALB Target Registration" for the
full before/after comparison and why this is the simpler, more standard
pattern.
