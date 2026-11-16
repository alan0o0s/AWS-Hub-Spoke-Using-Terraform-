# Module: security-groups

Creates three security groups: `alb_sg`, `nlb_sg`, `spoke_app_sg`. There is
no `bastion_sg` and no SSH rule anywhere in this platform - administrative
access is entirely via AWS Systems Manager Session Manager (see
`main.tf`'s Spoke application IAM role), which needs no inbound port.

## Cross-VPC security group references are not possible here

Security-group-by-reference rules only resolve within a single VPC (or
across VPC-peered VPCs with the specific referenced-SG feature enabled).
Hub and Spoke are connected via **Transit Gateway**, which does not support
this feature. `spoke_app_sg`'s rule for "traffic from the internal NLB"
uses a real SG-to-SG reference (same-VPC), but `nlb_sg`'s rule for
"traffic from the Hub ALB" uses a **CIDR** (the Hub VPC CIDR), because the
ALB's security group lives in a different VPC.
