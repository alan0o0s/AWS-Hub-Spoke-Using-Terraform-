# Security

## Network Segmentation

- **Spoke has no Internet Gateway, ever.** Enforced structurally:
  `modules/vpc` only creates an IGW when `create_internet_gateway = true`,
  and the root module passes `false` for the Spoke call.
- **No Spoke EC2 instance has a public IP.** Enforced in
  `modules/launch-template`: the launch template's `network_interfaces`
  block hard-codes `associate_public_ip_address = false`.
- **There is no Bastion, and no SSH port open anywhere in the platform.**
  Administrative access is entirely via AWS Systems Manager Session
  Manager - see "SSM Instead of a Bastion" below.

## SSM Instead of a Bastion

Earlier designs for this kind of platform typically include a Bastion host
as the single public EC2 instance for administrative SSH access. This
platform has **no such host at all**:

- The Spoke application IAM role (`main.tf`) carries
  `AmazonSSMManagedInstanceCore` and nothing else.
- `aws ssm start-session --target <instance-id>` opens a fully audited
  (CloudTrail-logged) shell session using only an **outbound** HTTPS
  connection the instance itself initiates to SSM's regional endpoints -
  no inbound port, no public IP, and no separate host to patch, monitor,
  or lose track of.
- This outbound path is already permitted by the Network Firewall's PASS
  rule for port 443 and the Spoke's normal egress path
  (`TGW -> Hub -> Firewall -> NAT -> IGW`), so no additional firewall rule
  or route was needed to enable it.

Removing the Bastion also removes an entire class of findings a generic
security scanner would otherwise flag (a public EC2 instance, an SSH
security group rule, a key pair to rotate/manage) - see "Scan Results"
below for the before/after.

## Least Privilege

- Every security group rule is scoped to the narrowest source that still
  functions - see `modules/security-groups/README.md` for the one place a
  CIDR is used instead of an SG reference (a TGW connectivity limitation,
  not a shortcut).
- The Spoke application EC2 role has exactly one managed policy attached,
  `AmazonSSMManagedInstanceCore` - no `AdministratorAccess` anywhere in the
  platform, and (with no Bastion) no second IAM role to reason about either.

## Security Groups

| SG | VPC | Inbound | Notes |
|---|---|---|---|
| `alb_sg` | Hub | `0.0.0.0/0:80` | Deliberately public - this is the platform's public entry point |
| `nlb_sg` | Spoke | Hub + Spoke CIDR `:80` | Internal-only, never public |
| `spoke_app_sg` | Spoke | NLB SG-ref `:80` only | **No SSH rule at all** - SSM needs no inbound port |

Three security groups total - down from four in earlier designs, since
there is no `bastion_sg`.

## AWS Network Firewall

Default-deny stateful rule group (see `modules/network-firewall/README.md`
for the full SID 5-9 rule set and why `STRICT_ORDER` is required at both the
rule-group and firewall-policy level). Only HTTP, HTTPS, and DNS (TCP+UDP)
originating from the platform's own CIDRs (`HOME_NET` = Hub + Spoke) are
permitted outbound; everything else is dropped by the SID 9 catch-all. This
same PASS-443 rule is what SSM Session Manager traffic relies on to reach
its regional endpoints.

Firewall flow and alert logs are shipped to a dedicated CloudWatch log
group (`modules/network-firewall` -> `log_group_name` output).

## Private Workloads

The Spoke ASG is the only compute fleet handling application traffic, and
it is 100% private: no public IPs, no SSH, security group ingress limited
to the internal NLB (same-VPC SG reference) - the Hub ALB never talks to
Spoke instances directly at all (it targets the NLB's static IPs - see
`ARCHITECTURE.md` "ALB vs NLB"), which further narrows what `spoke_app_sg`
needs to permit.

## Logging

- **VPC Flow Logs** (`ALL` traffic) enabled for both the Hub and Spoke VPCs
  by default (`var.enable_flow_logs = true`), each to its own CloudWatch
  log group with a purpose-built IAM role scoped to only that log group.
- **Network Firewall** flow and alert logs, as above.
- **SSM Session Manager sessions** are automatically logged to CloudTrail
  (who connected to which instance, when) with no additional
  configuration required in this Terraform - a byproduct of using SSM
  instead of SSH, which has no equivalent built-in audit trail.

## IAM

Two IAM roles exist in this platform:

1. Spoke application instance role - `AmazonSSMManagedInstanceCore` only.
2. VPC Flow Logs role (one per VPC) - write access to that VPC's own flow
   log group only.

No role in this platform has `AdministratorAccess`, `iam:*`, or any
wildcard resource on a mutating action. (An earlier design also included a
Bastion instance role and a Lambda execution role for dynamic ALB target
registration - both are gone entirely now that there's no Bastion and no
Lambda-based registration mechanism.)

## Secrets

No AWS access keys, secret keys, passwords, private keys, or tokens appear
anywhere in this Terraform source. Authentication is entirely via the AWS
provider's standard credential chain. The one optional
"credential-adjacent" value in the codebase is `var.key_name` (an EC2 key
pair *name*, not the key material itself) - and it now defaults to `null`
(disabled), since SSM is the primary and expected access path.

## Scan Results (Checkov)

`checkov 3.3.16` was run against this repository during authoring. Removing
the Bastion and the Lambda-based ALB sync mechanism eliminated an entire
category of findings from an earlier iteration of this design (public EC2
instance findings, Lambda VPC/DLQ/concurrency findings, an extra IAM role
to scope correctly). See `TROUBLESHOOTING.md` "Static Analysis Findings"
for the complete, current, honest list of what remains and why.
