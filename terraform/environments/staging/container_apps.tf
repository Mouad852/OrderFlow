resource "azurerm_container_app_environment" "staging" {
  name                       = "cae-orderflow-staging-neu"
  location                   = azurerm_resource_group.staging.location
  resource_group_name        = azurerm_resource_group.staging.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.staging.id

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.staging.id
}
