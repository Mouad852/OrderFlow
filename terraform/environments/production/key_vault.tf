resource "azurerm_key_vault" "production" {
  name                = "kv-orderflow-prod-swe"
  location            = azurerm_resource_group.production.location
  resource_group_name = azurerm_resource_group.production.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = local.common_tags
}

resource "azurerm_role_assignment" "api_key_vault_secrets_user" {
  scope                            = azurerm_key_vault.production.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.api.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "deployer_key_vault_secrets_officer" {
  scope                = azurerm_key_vault.production.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
