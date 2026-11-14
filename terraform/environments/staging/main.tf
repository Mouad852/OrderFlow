terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-orderflow-tfstate-neu"
    storage_account_name = "storderflowtfstategjkoua"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
    use_cli              = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for staging resources."
  type        = string
  default     = "northeurope"
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-orderflow-staging-neu"
  location = var.location

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.staging.name
}
