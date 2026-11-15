resource "azurerm_virtual_network" "staging" {
  name                = "vnet-orderflow-staging-${local.name_suffix}"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  address_space       = ["10.52.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.52.0.0/27"]

  delegation {
    name = "container-apps"

    service_delegation {
      name = "Microsoft.App/environments"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "postgresql" {
  name                 = "snet-postgresql"
  resource_group_name  = azurerm_resource_group.staging.name
  virtual_network_name = azurerm_virtual_network.staging.name
  address_prefixes     = ["10.52.1.0/28"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgresql-flexible-server"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.staging.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "link-orderflow-staging-postgresql-${local.name_suffix}"
  resource_group_name   = azurerm_resource_group.staging.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = azurerm_virtual_network.staging.id
  registration_enabled  = false
}
