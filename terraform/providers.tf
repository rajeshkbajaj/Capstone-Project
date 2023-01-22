terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.40.0"
    }
  }
}

# intialising S3 bucket to use it for storing terraform statefile
# terraform {
#   backend "s3" {
#     bucket = "rajesh-capstone-project"
#     key    = "files/tfstatefile"
#     region = "us-east-1"
#    }
#  }

# Configuration the aws region option to be used
provider "aws" {
  region = var.region
}
