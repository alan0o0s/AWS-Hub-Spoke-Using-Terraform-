provider "aws" {
  region = var.aws_region

  # No hard-coded credentials - use an AWS CLI profile, environment
  # variables, an assumed role, or CI/CD OIDC. See README.md "AWS
  # Authentication".
  default_tags {
    tags = {
      ManagedBy = "Terraform"
    }
  }
}
