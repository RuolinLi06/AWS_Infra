terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  required_version = ">= 1.2.0"
}
provider "aws" {
  region  = var.vpc_region
  profile = var.profile
}



