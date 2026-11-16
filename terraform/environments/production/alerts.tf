variable "alert_email" {
  description = "Email address that receives production Azure Monitor alerts."
  type        = string
  sensitive   = true
}

resource "azurerm_monitor_action_group" "production" {
  name                = "ag-orderflow-production-prod-swe"
  resource_group_name = azurerm_resource_group.production.name
  short_name          = "of-prod"
  tags                = local.common_tags

  email_receiver {
    name                    = "production-owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_application_insights_standard_web_test" "production_health" {
  name                    = "wt-orderflow-production-health"
  location                = azurerm_resource_group.production.location
  resource_group_name     = azurerm_resource_group.production.name
  application_insights_id = azurerm_application_insights.production.id

  # One location, every five minutes: keeps monitoring cost low.
  geo_locations = ["emea-nl-ams-azr"]
  frequency     = 300
  timeout       = 30
  retry_enabled = true
  enabled       = true

  request {
    url                              = "https://${azurerm_container_app.api.ingress[0].fqdn}/health"
    http_verb                        = "GET"
    parse_dependent_requests_enabled = false
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 14

    content {
      content_match      = "\"status\":\"ok\""
      ignore_case        = false
      pass_if_text_found = true
    }
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "production_availability" {
  name                = "alert-orderflow-production-health"
  resource_group_name = azurerm_resource_group.production.name

  # Azure requires the web test scope before the Application Insights scope.
  scopes = [
    azurerm_application_insights_standard_web_test.production_health.id,
    azurerm_application_insights.production.id,
  ]

  description   = "The production OrderFlow health endpoint failed from the configured test location."
  severity      = 0
  frequency     = "PT1M"
  window_size   = "PT5M"
  auto_mitigate = true
  tags          = local.common_tags

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.production_health.id
    component_id          = azurerm_application_insights.production.id
    failed_location_count = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.production.id
  }
}

resource "azurerm_monitor_metric_alert" "production_server_errors" {
  name                = "alert-orderflow-production-5xx"
  resource_group_name = azurerm_resource_group.production.name
  scopes              = [azurerm_container_app.api.id]

  description   = "The production OrderFlow API returned one or more 5xx responses in five minutes."
  severity      = 2
  frequency     = "PT1M"
  window_size   = "PT5M"
  auto_mitigate = true
  tags          = local.common_tags

  criteria {
    metric_namespace = "Microsoft.App/containerapps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.production.id
  }
}
