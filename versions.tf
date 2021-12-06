terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.25"
    }
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "~> 2.20"
    }
  }
}
