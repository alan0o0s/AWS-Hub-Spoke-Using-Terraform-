terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # See README.md "State Management". Bootstrap the S3 bucket + DynamoDB
  # table (or use S3-native locking on a sufficiently recent AWS/Terraform
  # combination) BEFORE running `terraform init` here - Terraform cannot
  # create its own backend ahead of time.
  backend "s3" {
    bucket         = "REPLACE-ME-aws-hub-spoke-tfstate"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "REPLACE-ME-aws-hub-spoke-tf-locks"
    encrypt        = true
  }
}
