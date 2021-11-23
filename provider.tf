provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}

provider "aviatrix" {
}
