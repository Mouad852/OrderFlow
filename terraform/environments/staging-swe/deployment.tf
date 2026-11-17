variable "api_image_tag" {
  description = "Immutable Git commit SHA used as the API image tag."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.api_image_tag))
    error_message = "api_image_tag must be a full 40-character Git commit SHA."
  }
}

locals {
  api_image = "${azurerm_container_registry.staging.login_server}/orderflow-api:${var.api_image_tag}"

  database_url = format(
    "postgresql+psycopg://orderflowowner:%s@%s:5432/orderflow?sslmode=require",
    urlencode(var.postgres_administrator_password),
    azurerm_postgresql_flexible_server.staging.fqdn,
  )
}

resource "azurerm_key_vault_secret" "database_url" {
  name             = "database-url"
  value_wo         = local.database_url
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.staging.id
  tags             = local.common_tags

  depends_on = [
    azurerm_role_assignment.deployer_key_vault_secrets_officer,
  ]
}

resource "azurerm_key_vault_secret" "application_insights_connection_string" {
  name             = "applicationinsights-connection-string"
  value_wo         = azurerm_application_insights.staging.connection_string
  value_wo_version = 1
  key_vault_id     = azurerm_key_vault.staging.id
  tags             = local.common_tags

  depends_on = [
    azurerm_role_assignment.deployer_key_vault_secrets_officer,
  ]
}

resource "azurerm_container_app_job" "migrate" {
  name                         = "caj-orderflow-migrate-${local.name_suffix}"
  location                     = azurerm_resource_group.staging.location
  resource_group_name          = azurerm_resource_group.staging.name
  container_app_environment_id = azurerm_container_app_environment.staging.id
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
    server   = azurerm_container_registry.staging.login_server
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
        value = "staging"
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

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }

  tags = local.common_tags
}

resource "azurerm_container_app" "api" {
  name                         = "ca-orderflow-api-staging-${local.name_suffix}"
  container_app_environment_id = azurerm_container_app_environment.staging.id
  resource_group_name          = azurerm_resource_group.staging.name
  revision_mode                = "Multiple"
  max_inactive_revisions       = 3
  workload_profile_name        = "Consumption"

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.api.id,
    ]
  }

  registry {
    server   = azurerm_container_registry.staging.login_server
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
    revision_suffix = substr(var.api_image_tag, 0, 12)
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
        value = "staging"
      }

      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }

      env {
        name  = "AUTH_ENABLED"
        value = "true"
      }

      env {
        name  = "ENTRA_TENANT_ID"
        value = var.entra_tenant_id
      }

      env {
        name  = "ENTRA_API_CLIENT_ID"
        value = var.entra_api_client_id
      }

      env {
        name  = "ENTRA_REQUIRED_ROLE"
        value = "OrderFlow.Orders.ReadWrite"
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

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      template[0].revision_suffix,
    ]
  }

  tags = local.common_tags
}

output "api_url" {
  value = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}
