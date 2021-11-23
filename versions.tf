terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.25"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.72"
    }
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "~> 2.20"
    }
  }
}
