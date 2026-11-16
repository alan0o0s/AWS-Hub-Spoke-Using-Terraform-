# Module: flow-logs

Enables VPC Flow Logs (`ALL` traffic) to a dedicated CloudWatch log group,
with a purpose-built IAM role scoped only to that log group. Called once per
VPC from the root configuration (Hub and Spoke both get their own call, and
their own log group).
