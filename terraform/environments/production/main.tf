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
    key                  = "production.tfstate"
    use_cli              = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region for the production environment."
  type        = string
  default     = "swedencentral"
}

variable "jenkins_identity_principal_id" {
  description = "Principal ID of the Jenkins user-assigned managed identity."
  type        = string
  default     = "475cfe8e-49ed-4400-b1b8-c43632f4e163"
}

locals {
  name_suffix = "prod-swe"

  shared_resource_group_name = "rg-orderflow-staging-swe"

  common_tags = {
    application = "orderflow"
    environment = "production"
    managed_by  = "terraform"
    region      = "swedencentral"
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_container_app_environment" "shared" {
  name                = "cae-orderflow-staging-swe"
  resource_group_name = local.shared_resource_group_name
}

data "azurerm_container_registry" "shared" {
  name                = "acrorderflowmouadswe"
  resource_group_name = local.shared_resource_group_name
}

data "azurerm_virtual_network" "shared" {
  name                = "vnet-orderflow-staging-swe"
  resource_group_name = local.shared_resource_group_name
}

data "azurerm_private_dns_zone" "postgresql" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = local.shared_resource_group_name
}

resource "azurerm_resource_group" "production" {
  name     = "rg-orderflow-production-swe"
  location = var.location
  tags     = local.common_tags
}

output "resource_group_name" {
  value = azurerm_resource_group.production.name
}

output "shared_container_app_environment_id" {
  value = data.azurerm_container_app_environment.shared.id
}
