# =========================================================================================
# Author: Rob Satnarain
# Created: 2026-05-04
# Description: This file contains the Terraform configuration for the state management of the infrastructure.
#
# Updated By     Date       Version     Description
# Rob Satnarain 2026-05-04  1.0         Initial creation
# =========================================================================================

# =========================================================================================
# Configure the required Terraform version   
# =========================================================================================
terraform {
     required_version = ">= 1.7.0" # Required for native S3 locking

     backend "s3" {
          bucket = "rob_sre_server_bucket"
          key = "rob-sre-server-bucket/terraform.state"
          region = "us-east-1"
          use_lockfile = true # Enable native S3 locking for state management (no DynamoDB table required)
     } 
     required_providers {
          aws = {
               source  = "hashicorp/aws"
               version = "~> 5.0"
          }
     }
}