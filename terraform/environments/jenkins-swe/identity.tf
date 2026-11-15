resource "azurerm_user_assigned_identity" "jenkins" {
  name                = "id-orderflow-jenkins-${local.name_suffix}"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  tags                = local.common_tags
}

locals {
  subscription_id = data.azurerm_client_config.current.subscription_id

  staging_api_id = "/subscriptions/${local.subscription_id}/resourceGroups/rg-orderflow-staging-swe/providers/Microsoft.App/containerApps/ca-orderflow-api-staging-swe"

  staging_migration_job_id = "/subscriptions/${local.subscription_id}/resourceGroups/rg-orderflow-staging-swe/providers/Microsoft.App/jobs/caj-orderflow-migrate-swe"

  acr_push_role_id = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec"

  container_apps_contributor_role_id = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/358470bc-b998-42bd-ab17-a7e34c199c0f"

  container_apps_jobs_contributor_role_id = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4e3d2b60-56ae-4dc6-a233-09c8e5a82e68"
}

resource "azurerm_role_assignment" "jenkins_acr_push" {
  scope                            = data.azurerm_container_registry.staging.id
  role_definition_id               = local.acr_push_role_id
  principal_id                     = azurerm_user_assigned_identity.jenkins.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "jenkins_staging_api" {
  scope                            = local.staging_api_id
  role_definition_id               = local.container_apps_contributor_role_id
  principal_id                     = azurerm_user_assigned_identity.jenkins.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "jenkins_staging_migration_job" {
  scope                            = local.staging_migration_job_id
  role_definition_id               = local.container_apps_jobs_contributor_role_id
  principal_id                     = azurerm_user_assigned_identity.jenkins.principal_id
  skip_service_principal_aad_check = true
}
