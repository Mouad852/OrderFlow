resource "azurerm_container_app_environment" "staging" {
  name                           = "cae-orderflow-staging-neu"
  location                       = azurerm_resource_group.staging.location
  resource_group_name            = azurerm_resource_group.staging.name
  infrastructure_subnet_id       = azurerm_subnet.container_apps.id
  internal_load_balancer_enabled = false
  public_network_access          = "Enabled"
  logs_destination               = "log-analytics"
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.staging.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.staging.id
}
