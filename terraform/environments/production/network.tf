resource "azurerm_subnet" "postgresql" {
  name                 = "snet-postgresql-production"
  resource_group_name  = local.shared_resource_group_name
  virtual_network_name = data.azurerm_virtual_network.shared.name
  address_prefixes     = ["10.52.2.0/28"]
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
