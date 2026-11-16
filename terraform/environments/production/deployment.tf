variable "api_image_digest" {
  description = "Immutable sha256 digest of the staging-verified API image."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.api_image_digest))
    error_message = "api_image_digest must use the format sha256 followed by 64 lowercase hexadecimal characters."
  }
}

locals {
  api_image = "${data.azurerm_container_registry.shared.login_server}/orderflow-api@${var.api_image_digest}"

  database_url = format(
    "postgresql+psycopg://orderflowowner:%s@%s:5432/orderflow?sslmode=require",
    urlencode(var.postgres_administrator_password),
    azurerm_postgresql_flexible_server.production.fqdn,
  )
}

resource "azurerm_key_vault_secret" "database_url" {
  name             = "database-url"
  value_wo         = local.database_url
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.production.id
  tags             = local.common_tags

  depends_on = [
    azurerm_role_assignment.deployer_key_vault_secrets_officer,
  ]
}

resource "azurerm_key_vault_secret" "application_insights_connection_string" {
  name             = "applicationinsights-connection-string"
  value_wo         = azurerm_application_insights.production.connection_string
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.production.id
  tags             = local.common_tags

  depends_on = [
    azurerm_role_assignment.deployer_key_vault_secrets_officer,
  ]
}

resource "azurerm_container_app_job" "migrate" {
  name                         = "caj-orderflow-migrate-prod-swe"
  location                     = azurerm_resource_group.production.location
  resource_group_name          = azurerm_resource_group.production.name
  container_app_environment_id = data.azurerm_container_app_environment.shared.id
  workload_profile_name        = "Consumption"

  replica_timeout_in_seconds = 600
  replica_retry_limit        = 1

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.api.id,
    ]
  }

  registry {
    server   = data.azurerm_container_registry.shared.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  template {
    container {
      name   = "migrate"
      image  = local.api_image
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["alembic"]
      args    = ["upgrade", "head"]

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }

      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.api_acr_pull,
    azurerm_role_assignment.api_key_vault_secrets_user,
  ]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}

resource "azurerm_container_app" "api" {
  name                         = "ca-orderflow-api-production-swe"
  container_app_environment_id = data.azurerm_container_app_environment.shared.id
  resource_group_name          = azurerm_resource_group.production.name
  revision_mode                = "Multiple"
  max_inactive_revisions       = 5
  workload_profile_name        = "Consumption"

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.api.id,
    ]
  }

  registry {
    server   = data.azurerm_container_registry.shared.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  secret {
    name                = "applicationinsights-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.application_insights_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.api.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8000
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    revision_suffix = substr(var.api_image_digest, 7, 12)
    min_replicas    = 0
    max_replicas    = 1

    container {
      name   = "api"
      image  = local.api_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }

      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "applicationinsights-connection-string"
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8000
        initial_delay           = 10
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/ready"
        port                    = 8000
        initial_delay           = 5
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 6
        success_count_threshold = 1
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.api_acr_pull,
    azurerm_role_assignment.api_key_vault_secrets_user,
  ]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      ingress[0].traffic_weight,
      template[0].container[0].image,
      template[0].revision_suffix,
    ]
  }
}

resource "azurerm_role_assignment" "jenkins_api" {
  scope                            = azurerm_container_app.api.id
  role_definition_name             = "Container Apps Contributor"
  principal_id                     = var.jenkins_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "jenkins_monitoring_reader" {
  scope                            = azurerm_container_app.api.id
  role_definition_name             = "Monitoring Reader"
  principal_id                     = var.jenkins_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "jenkins_migration_job" {
  scope                            = azurerm_container_app_job.migrate.id
  role_definition_name             = "Container Apps Jobs Contributor"
  principal_id                     = var.jenkins_identity_principal_id
  skip_service_principal_aad_check = true
}

output "api_url" {
  value = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}

output "api_image" {
  value = local.api_image
}
