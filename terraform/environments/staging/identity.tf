resource "azurerm_user_assigned_identity" "api" {
  name                = "id-orderflow-api-staging"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                = azurerm_container_registry.staging.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}
