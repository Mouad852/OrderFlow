resource "azurerm_container_registry" "staging" {
  name                = "acrorderflowmouadswe"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = local.common_tags
}

output "container_registry_login_server" {
  value = azurerm_container_registry.staging.login_server
}
