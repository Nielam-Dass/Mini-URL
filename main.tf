terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.84"
        }   
    }

    required_version = ">= 1.2.0"
}

provider "aws" {
    profile = "default"
    region = "us-east-2"
}
