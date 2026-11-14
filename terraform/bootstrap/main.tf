terraform {
    backend "azurerm" {
        resource_group_name  = "rg-orderflow-tfstate-neu"
        storage_account_name = "storderflowtfstategjkoua"
        container_name       = "tfstate"
        key                  = "bootstrap.tfstate"
        use_cli              = true
        use_azuread_auth     = true
    }

    required_version = "~> 1.16"
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~> 4.0"
        }

        random = {
            source = "hashicorp/random"
            version = "~> 3.0"
        }
    }
}

provider "azurerm" {
    features {}
}

variable "location" {
    type        = string
    description = "The Azure region to deploy resources in."
    default    = "northeurope"
}

resource "random_string" "suffix" {
    length  = 6
    upper   = false
    special = false
}

resource "azurerm_resource_group" "state" {
    name     = "rg-orderflow-tfstate-neu"
    location = var.location

    tags = {
        application = "orderflow"
        managed_by  = "terraform"
        purpose     = "terraform_state"
    }
}

resource "azurerm_storage_account" "state" {
    name                     = "storderflowtfstate${random_string.suffix.result}"
    resource_group_name      = azurerm_resource_group.state.name
    location                 = azurerm_resource_group.state.location
    account_tier             = "Standard"
    account_replication_type = "LRS"

    min_tls_version = "TLS1_2"
    public_network_access_enabled = true
    allow_nested_items_to_be_public = false

    tags = azurerm_resource_group.state.tags
}

resource "azurerm_storage_container" "state" {
    name                  = "tfstate"
    storage_account_id  = azurerm_storage_account.state.id
    container_access_type = "private"
}

output "storage_account_name" {
    value = azurerm_storage_account.state.name
}

output "container_name" {
    value = azurerm_storage_container.state.name
}
