############################################################
# This file intentionally contains ONLY required_providers - no `provider`
# blocks and no `backend` block. That configuration lives in each
# environments/<env>/ directory instead, so this repository root can be
# invoked as a reusable module from every environment without duplicating
# Terraform logic (see design requirement 5 and README.md "Repository
# Structure - Deviation from the Requested Layout").
############################################################

terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}
