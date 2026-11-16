# Changelog

## [1.1.0] - Simplified access & target registration

- **Removed the Bastion host entirely.** Administrative access is now via
  AWS Systems Manager Session Manager only - no public EC2 instance, no
  SSH port open anywhere in the platform. The Hub's `bastion` subnet is
  still created (matching the reference diagram) but nothing is deployed
  into it.
- **Replaced the Lambda-based dynamic ALB target registration with static
  IPs.** The Hub ALB now targets the Spoke internal NLB's two fixed private
  IPs (`modules/nlb`'s `subnet_mapping.private_ipv4_address`), registered
  once via plain `aws_lb_target_group_attachment` resources. The entire
  `alb-ip-target-sync` module (Lambda, EventBridge, ASG lifecycle hooks,
  its IAM role) has been removed - simpler, fewer moving parts, and
  removes the "ASG can't see ALB target health" limitation that existed in
  the Lambda-based design.
- **Updated the CIDR scheme** to match the reference diagram exactly:
  Hub TGW/NAT/Firewall/ALB subnets moved to a `/28` scheme
  (`10.0.1.0/28`-`10.0.7.0/28`); Spoke TGW subnets moved to
  `10.1.5.0/28`/`10.1.6.0/28`, freeing `10.1.3.0/24`/`10.1.4.0/24` for new
  (currently structural-only) RDS subnets.
- **Fixed a CIDR/VPC mismatch bug**: staging/prod previously used
  different VPC CIDRs (`10.10.0.0/16`, `10.20.0.0/16`) than the
  Hub/Spoke subnet CIDR defaults, which would have caused subnet creation
  to fail. All environments now use the same CIDR scheme (isolated by
  separate state/account, not by IP range).
- Removed the `hashicorp/archive` provider requirement (was only needed to
  zip the now-deleted Lambda source).

## [1.0.0] - Initial implementation

Enterprise implementation of the AWS Hub-and-Spoke reference architecture:

- Hub (`10.0.0.0/16`) + Spoke (`10.1.0.0/16`) VPCs across 2 AZs
- Transit Gateway with Appliance Mode on the Hub attachment
- AWS Network Firewall with a `STRICT_ORDER` stateful rule group
  (PASS 80/443/53-tcp/53-udp, default-deny)
- Centralized egress: Spoke -> TGW -> Hub -> Firewall -> NAT -> IGW
- IGW ingress edge-routing added (beyond the literal reference route-table
  list) to keep the firewall in the return-traffic path - see
  `ARCHITECTURE.md` "Symmetric Routing"
- Internet-facing ALB (Hub, cross-VPC IP targets) and internal NLB (Spoke,
  same-VPC instance targets) as two independent load-balancing paths
- Dynamic cross-VPC ALB target registration via ASG lifecycle hooks +
  EventBridge + Lambda (superseded in 1.1.0 - see above)
- Bastion as the platform's only public EC2 instance (removed in 1.1.0)
- VPC Flow Logs, Network Firewall logging, and 4 CloudWatch alarms
- `dev` / `staging` / `prod` environments as thin wrappers around one
  reusable root module
- GitHub Actions: `terraform fmt`/`validate` matrix, OIDC-based `plan`,
  `tflint` + `checkov` security scanning
