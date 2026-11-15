resource "azurerm_log_analytics_workspace" "production" {
  name                = "law-orderflow-production-swe"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.common_tags
}

resource "azurerm_application_insights" "production" {
  name                                 = "appi-orderflow-production-swe"
  location                             = azurerm_resource_group.production.location
  resource_group_name                  = azurerm_resource_group.production.name
  application_type                     = "web"
  daily_data_cap_in_gb                 = 0.1
  daily_data_cap_notifications_enabled = true
  retention_in_days                    = 30
  workspace_id                         = azurerm_log_analytics_workspace.production.id
  tags                                 = local.common_tags
}
