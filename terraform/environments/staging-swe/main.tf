terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-orderflow-tfstate-neu"
    storage_account_name = "storderflowtfstategjkoua"
    container_name       = "tfstate"
    key                  = "staging-swe.tfstate"
    use_cli              = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for the Sweden Central staging environment."
  type        = string
  default     = "swedencentral"
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant that issues OrderFlow API access tokens."
  type        = string
  default     = "b0b08c91-f921-486d-9d9f-5aff2b86160a"
}

variable "entra_api_client_id" {
  description = "Application (client) ID of the OrderFlow Entra API registration."
  type        = string
  default     = "c098978c-a5c8-4864-8ad7-ec5b2a1f74b8"
}

locals {
  name_suffix = "swe"

  common_tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
    region      = "swedencentral"
  }
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-orderflow-staging-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

output "resource_group_name" {
  value = azurerm_resource_group.staging.name
}
