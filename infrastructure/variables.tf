# =========================================================================================
# Author: Rob Satnarain
# Created: 2026-05-04
# Description: This file contains the variables for the Terraform configuration of the infrastructure.
#
# Updated By     Date       Version     Description
# Rob Satnarain 2026-05-04  1.0         Initial creation - variable definitions
# =========================================================================================

# AWS region for the infrastructure
variable "aws_region" {
     description = "The default region is N Virginia."
     type = string
     default = "us-east-1"
     validation {
          condition     = can(regex("^([a-z]{2}-[a-z]+-[0-9])$", var.aws_region))
          error_message = "The aws_region must be in the format 'xx-xxxxx-x' (e.g., us-east-1)."
     }
}
