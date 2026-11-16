# AWS Hub-and-Spoke Platform (Terraform)

Enterprise-grade Infrastructure-as-Code implementation of a centralized AWS
networking platform: one **Hub** VPC providing shared security/egress
services (Transit Gateway, AWS Network Firewall, NAT, a Bastion, and a
public ALB), and one **Spoke** VPC containing private application workloads
behind an internal NLB, with room to add more Spokes without redesigning the
Hub.

## Project Overview

| | |
|---|---|
| Hub VPC | `10.0.0.0/16` - centralized networking, security, egress |
| Spoke VPC | `10.1.0.0/16` - private application workloads |
| Region | `us-east-2`, 2 Availability Zones |
| Public entry | Internet-facing ALB in the Hub, targeting the Spoke NLB's two static private IPs across TGW |
| Internal entry | Internal NLB in the Spoke, same-VPC ASG targets |
| Egress | Spoke -> TGW -> Hub -> Network Firewall -> NAT -> IGW -> Internet |
| Admin access | AWS Systems Manager Session Manager directly to Spoke instances - **no Bastion, no open SSH port anywhere** |

See `ARCHITECTURE.md` for the full diagrammed packet paths and design
rationale, the [Eraser architecture diagram](https://app.eraser.io/workspace/vG3q7xlhT93XHHtfCIyb?diagram=BWvohDuJOcJ1sfmN9Xdl) for the visual design,
`SECURITY.md` for the security model, and `OPERATIONS.md` for day-2 procedures.

## Repository Structure

```text
terraform-aws-hub-spoke-platform/
├── README.md  ARCHITECTURE.md  SECURITY.md  OPERATIONS.md
├── TROUBLESHOOTING.md  CHANGELOG.md
├── .gitignore
│
├── versions.tf       # required_providers ONLY - see "Deviation" below
├── main.tf           # module wiring (VPCs, TGW, Firewall, SGs, compute, LBs)
├── routing.tf         # the routing abstraction layer - every route lives here
├── variables.tf  locals.tf  outputs.tf
├── terraform.tfvars.example
│
├── modules/
│   ├── vpc/                   # generic VPC+subnets (Hub AND Spoke)
│   ├── nat-gateway/
│   ├── route-table/            # generic route table + routes + associations
│   ├── transit-gateway/         # TGW + attachments, Appliance Mode on Hub
│   ├── network-firewall/        # policy, stateful rules, logging
│   ├── security-groups/         # alb_sg, spoke_app_sg, nlb_sg (no bastion_sg, no SSH)
│   ├── launch-template/
│   ├── autoscaling/
│   ├── alb/                    # internet-facing, Hub, IP targets = NLB's static IPs
│   ├── nlb/                    # internal, Spoke, instance targets, static private IPs
│   ├── flow-logs/
│   └── monitoring/
│
├── environments/
│   ├── dev/       staging/       prod/      # thin wrappers, see below
│
└── .github/workflows/
    ├── terraform-validate.yml
    ├── terraform-plan.yml
    └── terraform-security.yml
```

### Deviation from the requested layout (and why)

The original design brief listed `providers.tf` and `backend.tf` at the
repository root, a separate `subnet`/`internet-gateway`/`bastion` module,
and a Bastion host for administrative access. Several deliberate changes
were made after review:

1. **Provider/backend configuration lives in `environments/<env>/`, not at
   the repo root.** The repo root is a *reusable root module* with no
   `provider` or `backend` block of its own (`versions.tf` only declares
   `required_providers`). Each environment calls it via
   `module "platform" { source = "../../" }` with its own AWS provider
   region/credentials and its own S3 backend key. This is what makes "do
   not duplicate Terraform logic between environments" (a hard requirement)
   actually achievable - one copy of every resource definition, three sets
   of variable values.
2. **Subnets and the Internet Gateway are part of the `vpc` module**, not
   separate `subnet`/`internet-gateway` modules. A VPC's subnets and its own
   IGW are structurally inseparable from the VPC itself in this design, so
   splitting them into their own modules would have added indirection
   without a corresponding reuse benefit. `nat-gateway` **was** kept
   separate, since it's a routing/egress concern rather than VPC structure.
3. **No Bastion host - SSM Session Manager instead.** See "SSM instead of
   Bastion" below.
4. **The ALB targets the Spoke NLB's two static private IPs, not
   individual ASG instances - no Lambda-based dynamic registration.** See
   "Dynamic vs. Static ALB Target Registration" below.

Every other module in the requested list exists as its own directory.

### SSM instead of Bastion

This platform has **no Bastion host and no SSH port open anywhere**.
Administrative access to Spoke instances is entirely via **AWS Systems
Manager Session Manager**:

```bash
# Find an instance ID
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-hub-spoke-dev-app" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text

# Connect - no bastion hop, no open port, full session audit trail in CloudTrail
aws ssm start-session --target <instance-id>
```

This works because the Spoke application IAM role already carries
`AmazonSSMManagedInstanceCore` (see `main.tf`), and SSM only needs
**outbound** HTTPS from the instance to SSM's regional endpoints - already
permitted by the Network Firewall's PASS-443 rule and the Spoke's normal
`TGW -> Hub -> Firewall -> NAT -> IGW` egress path. No inbound port, no
public IP, and no separate host to patch/monitor/secure.

The Hub's "bastion" subnet (`10.0.7.0/28` by default) still exists,
matching the reference diagram's layout, but nothing is deployed into it.

### Dynamic vs. Static ALB Target Registration

An earlier version of this design pointed the Hub ALB directly at
individual Spoke ASG instance IPs, which required a Lambda-based dynamic
registration mechanism (ASG lifecycle hooks + EventBridge) because instance
IPs constantly change as the ASG scales. **This version instead points the
ALB at the Spoke NLB's two static private IPs** (`modules/nlb` assigns
fixed IPs via `subnet_mapping.private_ipv4_address`). Since an NLB's IP
addresses never change for its lifetime, the ALB's target registration
(`modules/alb`'s `aws_lb_target_group_attachment` resources) happens once,
in Terraform, and never needs to change again - the NLB's own native,
same-VPC ASG attachment handles all the actual instance-level routing.
**No Lambda, no EventBridge, no lifecycle hooks.** See
`ARCHITECTURE.md` "ALB vs NLB" and `modules/nlb/README.md` "Static private
IPs" for the full explanation, including the one residual trade-off (a
small IP-collision risk, mitigated but not eliminated - documented in
`locals.tf`).

## AWS Services Used

VPC & subnets, Internet Gateway, NAT Gateway, Transit Gateway (Appliance
Mode), AWS Network Firewall, Application Load Balancer (static IP targets),
Network Load Balancer (static private IPs), Auto Scaling Group + Launch
Template, EC2 (Spoke app instances only - no Bastion), IAM, AWS Systems
Manager (Session Manager for admin access), VPC Flow Logs, CloudWatch
Logs/Alarms.

## Prerequisites

- An AWS account with permissions to create VPC, EC2, ELBv2, Transit
  Gateway, Network Firewall, Lambda, IAM, and CloudWatch resources
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.7.0
- AWS CLI configured, or equivalent credentials (see "AWS Authentication")
- Git
- (Optional) An existing EC2 key pair if you want an SSH fallback in
  addition to SSM (`var.key_name`, defaults to `null`/disabled)

## AWS Authentication

Terraform uses the standard AWS credential chain - no credentials are ever
stored in this repository. For local use: `aws configure` (a named profile)
or environment variables. For CI/CD: OIDC federation (see
`.github/workflows/terraform-plan.yml` and "CI/CD" below) - no long-lived
AWS access keys in GitHub Secrets.

## Terraform Architecture

The repository root is a single reusable root module composed of the 14
child modules listed above. `main.tf` wires resource creation in the same
order as the design's implementation phases (networking -> TGW -> firewall
-> security -> compute -> load balancers -> observability); `routing.tf` is
kept separate and contains **every** route table and route in the platform
(see `modules/route-table/README.md` "Routing Abstraction").

## Environment Strategy

`environments/dev`, `environments/staging`, `environments/prod` each:

- Declare their own `provider "aws" {}` and S3 `backend {}` (different
  state file key per environment - never shared state)
- Call `module "platform" { source = "../../" }` with environment-specific
  CIDRs, instance sizes, ASG limits, and log retention
- Keep real values in a gitignored `terraform.tfvars` (copy from the
  provided `terraform.tfvars.example` in each environment directory)

No Terraform *logic* differs between environments - only variable values.

## State Management

Each environment uses an **S3 backend** with **DynamoDB locking**
(`backend "s3" { ... dynamodb_table = ... }` in
`environments/<env>/versions.tf`). Terraform cannot create its own backend
before it has a backend to store state in, so you must bootstrap the S3
bucket (versioning + SSE enabled) and DynamoDB table (partition key
`LockID`, type String) once per environment, outside this repository,
before running `terraform init`. A minimal bootstrap could be a tiny
separate Terraform config or a couple of `aws s3api` / `aws dynamodb`
CLI commands - either way, do it once and record the bucket/table names in
`environments/<env>/versions.tf` (replacing the `REPLACE-ME-...`
placeholders committed there).

State files, `.terraform/`, and `*.tfvars` (except the `.example` files) are
all gitignored - never commit state or secrets.

## Deployment

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars   # optionally set key_name for SSH fallback
# edit environments/dev/versions.tf: replace the REPLACE-ME backend bucket/table

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

Repeat under `environments/staging` / `environments/prod` for those
environments (each has its own state, so applies are fully independent).

## Validation

This repository was validated in the environment it was authored in using:

- `python3-hcl2` syntax parsing of every `.tf` file (63 files - all parse
  cleanly)
- A custom cross-check confirming every module call's arguments match that
  module's declared variables exactly (no unknown arguments, no missing
  required ones)
- `checkov` static security analysis (see `SECURITY.md` "Scan Results" for
  the actual findings and how each was resolved or explicitly accepted)

**`terraform init` / `validate` / `plan` against real AWS were not run** -
the authoring environment has no AWS credentials and no network path to
`releases.hashicorp.com` to install the Terraform binary itself. See
`TROUBLESHOOTING.md` "What Was and Wasn't Validated" for the complete,
honest list, and run the commands under "Deployment" above yourself before
trusting this in production.

## Testing

See `OPERATIONS.md` "Validation Checklist" for the full 20-point test list
(Hub/Spoke existence, no Spoke IGW, no public Spoke IPs, Appliance Mode
enabled, ALB/NLB health, firewall PASS/DROP behavior, etc.) and the `curl`/
`ssh`/`traceroute` commands to exercise each traffic path end-to-end after
deployment.

## Security

See `SECURITY.md` for the full model. Summary: Spoke is entirely private (no
IGW, no public IPs), **there is no Bastion and no SSH port open anywhere** -
administrative access is via SSM Session Manager only, all inter-tier
traffic is least-privilege by security group (or CIDR where TGW prevents SG
references - see `modules/security-groups/README.md`), egress is centrally
inspected by AWS Network Firewall with a default-deny stateful rule group,
and no secrets are ever stored in Terraform source or state beyond what AWS
itself requires.

## Monitoring

`modules/monitoring` creates four CloudWatch alarms (ALB/NLB unhealthy
targets, ASG below desired capacity, EC2 status check failures) - see that
module's README for why these four and not "one alarm per metric AWS
exposes." `modules/flow-logs` enables VPC Flow Logs for both VPCs.
`modules/network-firewall` enables firewall flow/alert logging.

## Troubleshooting

See `TROUBLESHOOTING.md` for common issues (targets not appearing on the
ALB, asymmetric routing symptoms, firewall unexpectedly dropping traffic,
lifecycle hooks timing out) and where to look first for each (mostly: the
specific CloudWatch log group named in the relevant module's outputs).

## Cleanup

```bash
cd environments/dev   # or staging / prod
terraform destroy
```

If `enable_firewall_delete_protection = true` (the default for
staging/prod), the Network Firewall resource must have delete protection
disabled (set the variable to `false` and `terraform apply` first) before
`destroy` will succeed. See `OPERATIONS.md` "Destroy Procedure" for the full
ordered checklist.

## Cost Considerations

This architecture includes several genuinely expensive-at-scale services:
**AWS Network Firewall** (hourly + per-GB processing charge), **Transit
Gateway** (per-attachment-hour + per-GB), **NAT Gateway** (hourly +
per-GB), and **two load balancers**. Destroy environments you aren't
actively using. `environments/dev` defaults to `enable_firewall_delete_protection = false`
specifically to make teardown friction-free during development.

## Reference Diagram Additions Not Yet Implemented

The current reference diagram also shows two elements not yet built out
beyond their subnet/routing structure:

- **Spoke RDS subnets** (`rds_a`/`rds_b`, `10.1.3.0/24`/`10.1.4.0/24`) -
  the subnets and a private-only route table (`routing.tf`'s
  `rt_spoke_rds`) exist, but no actual RDS instance is created. Ask if
  you'd like an RDS module added (PostgreSQL/MySQL, private-only, similar
  pattern to a standard 3-tier database tier).
- **S3 log archive** - the diagram shows a central S3 log destination.
  Currently, VPC Flow Logs, Network Firewall logs, and CloudWatch alarms
  all go to CloudWatch Logs (see `modules/flow-logs`,
  `modules/network-firewall`). Redirecting some or all of these to a
  dedicated, lifecycle-managed S3 bucket instead (or in addition) is a
  reasonable next step if centralized long-term log archival is wanted.
