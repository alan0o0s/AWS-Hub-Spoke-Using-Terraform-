# Operations

## Deployment

See `README.md` "Deployment" for the standard `init` -> `fmt` -> `validate`
-> `plan` -> `apply` sequence, run from `environments/<env>/`.

## Upgrade

1. Change the relevant module or root variable.
2. `terraform fmt -recursive && terraform validate` from the environment
   directory.
3. `terraform plan` and review the diff carefully, paying particular
   attention to any plan involving:
   - `aws_ec2_transit_gateway_vpc_attachment` (recreating this is
     disruptive - it drops the attachment)
   - `aws_networkfirewall_firewall` (recreating drops inspection entirely
     for the duration)
   - Any `route-table` module call (a route table replacement briefly
     removes that route)
4. Apply during a maintenance window for anything touching the above.

## Rollback Considerations

Terraform has no built-in "rollback" - reverting to a previous known-good
state means reverting the `.tf` source to that commit and re-applying. Keep
`terraform plan` output from every apply (e.g. as a CI artifact) so you can
compare exactly what changed if a rollback is needed.

## Monitoring

Four CloudWatch alarms exist by default (`modules/monitoring`, gated by
`var.enable_monitoring`): ALB unhealthy targets, NLB unhealthy targets, ASG
below desired capacity, EC2 status check failures. None are wired to an SNS
topic by default - `module.monitoring[0].alarm_arns` exposes all four ARNs
for you to subscribe a topic/on-call tool of your choice.

## Troubleshooting

See `TROUBLESHOOTING.md` for specific symptoms. General principle: every
"black box" component in this platform (Network Firewall, VPC Flow Logs)
ships its logs to a CloudWatch log group whose name is a Terraform output -
check the relevant log group before assuming a routing or IAM problem.
Administrative access issues (can't connect via SSM) are also covered in
`TROUBLESHOOTING.md` "Cannot connect via SSM Session Manager".

## Incident Investigation

Useful commands during an incident:

```bash
# Is the firewall passing/dropping what you expect?
aws logs tail <network_firewall_log_group_output> --follow

# What does the ALB currently think its target (the NLB's static IPs) is,
# and is it healthy?
aws elbv2 describe-target-health --target-group-arn <alb target group arn>

# What does the NLB currently think its targets (the ASG instances) are,
# and are they healthy? (Check this FIRST if the ALB path is failing - see
# TROUBLESHOOTING.md "The public ALB path returns nothing / times out".)
aws elbv2 describe-target-health --target-group-arn <nlb target group arn>

# Is the ASG at desired capacity?
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <name>

# Is a specific 5-tuple actually being evaluated by the firewall as expected?
# (Check the firewall's alert log stream for DROP/PASS decisions matching
# the SIDs in modules/network-firewall/main.tf.)

# Connect to an instance for direct investigation (no Bastion needed):
aws ssm start-session --target <instance-id>
```

## Destroy Procedure

```bash
cd environments/<env>
terraform destroy
```

Ordering notes:

1. If `enable_firewall_delete_protection = true` (staging/prod default),
   set it to `false` and `terraform apply` **before** attempting `destroy`
   - AWS will refuse to delete a protected firewall.
2. `terraform destroy` handles dependency ordering automatically via the
   Terraform graph (this is exactly why the routing layer uses real
   resource references rather than hard-coded IDs) - you should not need to
   manually target-destroy individual resources in a specific order.
3. If a destroy fails partway on the Network Firewall or its policy/rule
   group (AWS eventual-consistency on firewall deletion is occasionally
   slow), re-run `terraform destroy` - it is safe to re-run.
4. The flow-logs and firewall log groups are not protected and will be
   deleted along with everything else - export anything you need to retain
   before destroying an environment you care about the audit trail for
   (including SSM session history, which lives in CloudTrail, not in this
   Terraform's resources at all, and is unaffected by `destroy`).

## Future Improvements

Documented here rather than silently implemented, since the brief calls for
preserving the given reference architecture rather than embellishing it:

- **Dual-AZ Network Firewall + NAT Gateway.** The current single-AZ
  placement (both in `us-east-2a`) is a single point of failure for all
  Spoke egress and ALB-path ingress - see `ARCHITECTURE.md` "Single-AZ
  Firewall/NAT". Extending to one firewall endpoint + one NAT Gateway per
  AZ, with each AZ's Hub subnets routing to its own local endpoint/gateway,
  would remove this SPOF and make Appliance Mode's benefit unambiguous
  rather than "still useful but not strictly necessary."
- **Additional Spokes.** `modules/vpc`, `modules/transit-gateway`, and
  `modules/network-firewall` (`additional_internal_cidrs`) were all
  designed with this in mind - see `README.md`/design brief section 40. Not
  implemented here to match the single-Spoke reference architecture
  exactly.
- **HTTPS on the ALB/NLB listeners.** Both currently listen on plain HTTP,
  matching the reference architecture's firewall rules (SID 6 permits 443
  outbound, but no listener terminates TLS anywhere in this implementation).
  Adding an ACM certificate + HTTPS listener would be a natural next step
  for a real production deployment.
- **SNS notification wiring** for the CloudWatch alarms in
  `modules/monitoring` - deliberately left to the consuming environment
  rather than hard-coding a notification preference into the module.
- **An actual RDS instance in the reserved Spoke `rds-a`/`rds-b`
  subnets.** Currently structural only (subnets + a private-only route
  table) - see `README.md` "Reference Diagram Additions Not Yet
  Implemented".
- **A dedicated NLB-only subnet**, to eliminate (not just reduce) the
  static-IP collision risk described in `locals.tf`'s `nlb_static_ips`
  comment and `ARCHITECTURE.md` "Static ALB Target Registration". The
  current shared-subnet approach matches the reference diagram exactly
  (NLB and ASG instances in the same `Spoke-App` subnets); a stricter
  production setup might isolate the NLB into its own small `/28`.
