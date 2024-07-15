terraform {
  backend "s3" {
    region = "eu-west-1"
    acl    = "bucket-owner-full-control"
  }
  required_version = "~>1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.22.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "aws" {
  region  = "us-east-1"
  alias   = "use1"
  profile = var.profile
}
