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
    key                  = "jenkins-swe.tfstate"
    use_cli              = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_container_registry" "staging" {
  name                = "acrorderflowmouadswe"
  resource_group_name = "rg-orderflow-staging-swe"
}

variable "location" {
  description = "Azure region for the Jenkins infrastructure."
  type        = string
  default     = "swedencentral"
}

locals {
  name_suffix = "swe"

  common_tags = {
    project     = "orderflow"
    application = "jenkins"
    environment = "ci"
    managed_by  = "terraform"
    owner       = var.owner
    expires_on  = var.expires_on
    region      = var.location
  }
}

resource "azurerm_resource_group" "jenkins" {
  name     = "rg-orderflow-jenkins-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}
