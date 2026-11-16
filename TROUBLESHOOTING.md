# Troubleshooting

## Common Issues

### Cannot connect via SSM Session Manager

1. Confirm the instance shows as "Managed" in Systems Manager -> Fleet
   Manager (or `aws ssm describe-instance-information`). If it doesn't
   appear within a few minutes of launch, the SSM agent likely couldn't
   reach its regional endpoint - check the instance can actually reach the
   internet via the normal egress path (`TGW -> Hub -> Firewall -> NAT ->
   IGW`); a broken route table anywhere in that chain will prevent SSM from
   ever registering, not just application traffic.
2. Confirm the instance profile actually has `AmazonSSMManagedInstanceCore`
   attached (`aws iam list-attached-role-policies --role-name <role>`) -
   check `main.tf`'s `aws_iam_role_policy_attachment.spoke_app_ssm`.
3. `aws ssm start-session --target <instance-id>` failing with a
   permissions error is almost always about **your own** IAM permissions
   (`ssm:StartSession`), not the target instance's role - check your own
   caller identity's policy first.

### The public ALB path returns nothing / times out

Since the ALB now targets the **NLB's static IPs** rather than individual
instances (see `ARCHITECTURE.md` "Static ALB Target Registration"), a
failure here almost always means one of exactly two things:

1. **The NLB itself has zero healthy targets** - check
   `aws elbv2 describe-target-health` against the NLB's own target group
   (not the ALB's). If empty/unhealthy, this is an ASG/application issue,
   not a networking one - use SSM to log into an instance and check
   `systemctl status httpd` / `curl localhost:80` directly.
2. **The ALB's target group shows the NLB's IPs as unhealthy** - check
   `aws elbv2 describe-target-health` against the **ALB's** target group.
   If the NLB itself is healthy (per #1) but the ALB can't reach it,
   suspect routing: verify the Hub ALB subnet's route table has
   `10.1.0.0/16 -> TGW`, the TGW's default route table has both VPC
   attachments propagated, and the Spoke TGW subnet's route table can reach
   the app subnets.

A third, rarer possibility: an IP collision on the NLB's static address
(see `locals.tf`'s `nlb_static_ips` comment) - if `terraform apply` for
`modules.nlb` ever failed with an "address already in use" error and you
worked around it in the AWS console rather than via Terraform, the ALB's
statically-registered IP may no longer match the NLB's actual current IP.
Compare `terraform output nlb_static_ips` against the NLB's actual
`subnet_mapping` in the console.

### Traffic seems to bypass the Network Firewall

Check `routing.tf`'s `rt_hub_igw_ingress` module actually applied - look
for a route table with a `GatewayId` association (not a `SubnetId`
association) pointing at the Hub's IGW. If it's missing, return traffic
from the internet to the NAT Gateway's public IP will bypass firewall
inspection entirely on the way back in.

### Asymmetric routing symptoms (connections work outbound but hang / intermittently)

This is the exact failure mode Appliance Mode exists to prevent - see
`modules/transit-gateway/README.md`. Confirm
`appliance_mode_support = "enable"` is actually set on the **Hub**
attachment specifically.

## Static Analysis Findings

`checkov 3.3.16` was run against this repository during authoring. Removing
the Bastion and the Lambda-based ALB sync mechanism eliminated an entire
category of findings that existed in an earlier iteration of this design
(a public-EC2-instance finding, Lambda VPC/DLQ/concurrency findings, and a
second IAM role to scope correctly) - the list below is shorter as a
direct result of that simplification.

### Fixed (see CHANGELOG.md for the earlier round of fixes too)

| Finding | Fix applied |
|---|---|
| ALB missing `drop_invalid_header_fields` | Added, `= true` |
| ALB/NLB deletion protection not enabled | Added `enable_lb_deletion_protection` variable (default `false` for dev, `true` for staging/prod) |
| NLB missing cross-zone load balancing | Added `enable_cross_zone_load_balancing = true` |
| VPC default security group not locked down | Added `aws_default_security_group` per VPC with no ingress/egress rules |

### Accepted, intentional (matches the reference architecture)

| Finding | Why it's intentional |
|---|---|
| ALB security group allows `0.0.0.0/0:80` (`CKV_AWS_260`) | This is the platform's only intended public entry point. |
| ALB/NLB listener uses HTTP, not HTTPS (`CKV_AWS_2`, `CKV_AWS_103`, `CKV_AWS_378`, `CKV2_AWS_20`) | The reference design specifies `Listener: HTTP:80` explicitly. Adding TLS would require an ACM certificate and a hostname, both outside the given reference architecture - noted as a "Future Improvement" in `OPERATIONS.md`. |
| Public ALB not behind WAF (`CKV2_AWS_28`) | Not part of the given reference architecture; noted as a future improvement. |
| CloudWatch log groups (flow logs, firewall) not KMS-CMK-encrypted (`CKV_AWS_158`) | All are still encrypted at rest under AWS's default CloudWatch Logs encryption; a customer-managed key is a real hardening option that adds a KMS key + key policy this reference implementation scopes out. |
| Log retention under 1 year (`CKV_AWS_338`) | `log_retention_days` defaults to 14 (dev) / 30 (staging) / 90 (prod) - all configurable per-environment; set to `365` if your compliance regime requires it. |
| Network Firewall / policy / rule group not CMK-encrypted (`CKV_AWS_345`, `CKV_AWS_346`) | Same rationale as the log group KMS finding above. |
| Network Firewall deletion protection off by default (`CKV_AWS_344`) | Already configurable - `var.enable_firewall_delete_protection`, `true` by default in staging/prod, `false` in dev specifically so teardown stays friction-free during development. |
| ALB/NLB access logging not enabled (`CKV_AWS_91`) | Requires a dedicated S3 bucket + bucket policy, scoped out of this reference implementation; noted as a future improvement. |

### Confirmed false positives (checkov's cross-module analysis limitations)

| Finding | Why it's a false positive |
|---|---|
| `app_http_from_nlb` ingress rule flagged as `0.0.0.0/0:80` (`CKV_AWS_260`) | Manually verified in `modules/security-groups/main.tf`: this rule uses `referenced_security_group_id = aws_security_group.nlb.id`, not a CIDR at all. |
| All three security groups "not attached to another resource" (`CKV2_AWS_5`) | Each SG's ID is passed as a variable into a *different* module (`alb`, `nlb`, `launch-template`) where it's actually attached. checkov's dependency graph does not fully trace SG usage passed as a plain string variable across a module boundary. |
| Both VPCs flagged as "flow logging not enabled" (`CKV2_AWS_11`) | Flow logs **are** enabled - via a separate `module "flow_logs_hub"` / `"flow_logs_spoke"` call in root `main.tf` referencing the same `vpc_id`, not a resource inside the `vpc` module itself. |

If you re-run `checkov` yourself and see different results, treat this
table as a snapshot from the checkov/provider versions available during
authoring, not a permanent guarantee.

## What Was and Wasn't Validated

Being explicit per the "do not fake success" requirement:

**Was validated in the authoring environment:**
- Every `.tf` file (57 total, after removing the Bastion and Lambda-sync
  modules) parses as syntactically valid HCL (`python3-hcl2`).
- Every `module` block's arguments were cross-checked against that module's
  declared `variables.tf` - no unknown arguments, no missing required ones
  - re-verified after this refactor with an automated grep-and-parse check
    for stale references to the removed modules/variables.
- All three GitHub Actions workflow YAML files parse as valid YAML.
- `checkov` static analysis was actually run (see above table), before and
  after the Bastion/Lambda removal, confirming the finding count dropped as
  expected.

**Was NOT validated, and you must do this yourself before trusting this in
production:**
- `terraform init` / `validate` / `plan` / `apply` against real AWS - the
  authoring environment has no AWS credentials and cannot install the
  Terraform binary itself (no network path to `releases.hashicorp.com`).
  The highest-risk areas for a provider-version-specific surprise remain
  the AWS Network Firewall `stateful_rule_options`/`stateful_engine_options`
  strict-ordering blocks and the NLB's `subnet_mapping.private_ipv4_address`
  argument (confirm your pinned `aws` provider version supports static IP
  assignment on NLBs - this has been supported for several major versions
  but verify against `terraform validate` regardless).
- The NLB static-IP collision risk described in `locals.tf` is a
  probabilistic mitigation, not a guarantee - test `terraform apply`
  against a real environment and watch for an "IP address already in use"
  error on the NLB resource specifically.
- No `tflint` run (not installed in the authoring environment).

**Commands to run yourself, exactly as given in `README.md` "Deployment"**:

```bash
cd environments/dev
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Review the plan output carefully before `terraform apply`.
