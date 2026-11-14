resource "azurerm_log_analytics_workspace" "staging" {
  name                = "law-orderflow-staging-neu"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

resource "azurerm_application_insights" "staging" {
  name                                 = "appi-orderflow-staging-neu"
  location                             = azurerm_resource_group.staging.location
  resource_group_name                  = azurerm_resource_group.staging.name
  application_type                     = "web"
  daily_data_cap_in_gb                 = 0.1
  daily_data_cap_notifications_enabled = true
  retention_in_days                    = 30
  workspace_id                         = azurerm_log_analytics_workspace.staging.id

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}
