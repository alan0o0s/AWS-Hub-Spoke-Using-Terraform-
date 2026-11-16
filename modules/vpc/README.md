# Module: vpc

Generic VPC + subnets module, reused for the Hub, the Spoke, and any future
Spoke VPC. This module deliberately knows nothing about routing, TGW,
firewalls, or load balancers - it only creates the VPC, its subnets, and
(optionally) an Internet Gateway.

## Why one generic module instead of `hub-vpc` / `spoke-vpc`

The Hub and Spoke differ only in their subnet layout and whether they have an
Internet Gateway - both expressible as input variables. Keeping one module
means a third Spoke VPC in the future is just another `module "vpc"` call
with a different `subnets` map, not new Terraform code.

## Inputs

| Name | Type | Description |
|---|---|---|
| `name_prefix` | string | Naming prefix for all resources |
| `vpc_cidr` | string | VPC CIDR block |
| `subnets` | map(object) | `{ name => { cidr, az } }` |
| `create_internet_gateway` | bool | `true` for the Hub, `false` for every Spoke |
| `tags` | map(string) | Common tags |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `subnet_ids` | Map of subnet name to subnet ID |
| `subnet_arns` | Map of subnet name to subnet ARN |
| `subnet_azs` | Map of subnet name to AZ |
| `internet_gateway_id` | IGW ID, or `null` if not created |

## Non-goals

This module does **not** create route tables, NAT gateways, or security
groups - those are separate modules so that routing changes never require
touching VPC/subnet definitions.
