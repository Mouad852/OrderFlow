resource "azurerm_container_registry" "staging" {
  name                = "acrorderflowmouad"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  sku                 = "Basic"
  admin_enabled       = false

  public_network_access_enabled = true

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

output "container_registry_login_server" {
  value = azurerm_container_registry.staging.login_server
}
