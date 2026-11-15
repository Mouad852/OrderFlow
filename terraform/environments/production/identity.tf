resource "azurerm_user_assigned_identity" "api" {
  name                = "id-orderflow-api-production-swe"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "api_acr_pull" {
  scope                            = data.azurerm_container_registry.shared.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.api.principal_id
  skip_service_principal_aad_check = true
}
