# Module: monitoring

Four CloudWatch alarms, chosen deliberately for operational signal rather
than coverage-for-its-own-sake:

1. **ALB unhealthy targets** - since the ALB's target is the internal
   NLB's static IPs (see `modules/nlb`/`modules/alb`), this alarm
   effectively tracks "is the NLB reachable and does it have at least one
   healthy backend" - a simpler and more direct signal than the earlier
   Lambda-based design's per-instance ALB target health ever provided.
2. **NLB unhealthy targets**
3. **ASG below desired capacity**
4. **EC2 status check failures**

No SNS topic/notification is wired up by default - `alarm_arns` is exposed
so the root configuration (or an environment) can attach one without this
module needing to know about your notification preferences.
