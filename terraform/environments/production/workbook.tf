resource "azurerm_application_insights_workbook" "production_operations" {
  # Keep this fixed UUID. Changing it would create a new workbook.
  name                = "2a4b7d8c-42f6-4d15-9a3c-1db8df4d127e"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location

  display_name = "OrderFlow Production Operations"
  description  = "Operational dashboard for the OrderFlow production API."
  source_id    = lower(azurerm_application_insights.production.id)
  category     = "workbook"

  data_json = jsonencode({
    "version" = "Notebook/1.0"
    "items" = [
      {
        "type" = 1
        "name" = "overview"
        "content" = {
          "json" = <<-MARKDOWN
            # OrderFlow Production Operations

            This workbook shows production availability, API request health, PostgreSQL dependency health, and application exceptions.

            **Default time range:** last 24 hours.
          MARKDOWN
        }
      },
      {
        "type" = 3
        "name" = "availability"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            availabilityResults
            | where timestamp > ago(24h)
            | where name == "wt-orderflow-production-health"
            | project timestamp, success, duration, location, message
            | order by timestamp desc
          KQL
        }
      },
      {
        "type" = 3
        "name" = "request-summary"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            requests
            | where timestamp > ago(24h)
            | summarize
                Requests = count(),
                Failed = countif(success == false),
                P95DurationMs = round(percentile(duration, 95), 2)
            | extend FailureRatePercent = iff(
                Requests == 0,
                0.0,
                round(100.0 * Failed / Requests, 2)
              )
            | project Requests, Failed, FailureRatePercent, P95DurationMs
          KQL
        }
      },
      {
        "type" = 3
        "name" = "requests-over-time"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "timechart"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            requests
            | where timestamp > ago(24h)
            | summarize Requests = count() by bin(timestamp, 5m)
            | order by timestamp asc
          KQL
        }
      },
      {
        "type" = 3
        "name" = "endpoints"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            requests
            | where timestamp > ago(24h)
            | summarize
                Requests = count(),
                Failed = countif(success == false),
                P95DurationMs = round(percentile(duration, 95), 2)
              by name
            | extend FailureRatePercent = iff(
                Requests == 0,
                0.0,
                round(100.0 * Failed / Requests, 2)
              )
            | project name, Requests, Failed, FailureRatePercent, P95DurationMs
            | order by Failed desc, Requests desc
          KQL
        }
      },
      {
        "type" = 3
        "name" = "failed-requests"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            requests
            | where timestamp > ago(24h)
            | where success == false
            | project timestamp, name, resultCode, duration, operation_Id
            | order by timestamp desc
            | take 100
          KQL
        }
      },
      {
        "type" = 3
        "name" = "postgresql-dependencies"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            dependencies
            | where timestamp > ago(24h)
            | where target has "postgres.database.azure.com"
            | summarize
                Calls = count(),
                Failed = countif(success == false),
                P95DurationMs = round(percentile(duration, 95), 2)
              by name, target
            | project name, target, Calls, Failed, P95DurationMs
            | order by Failed desc, Calls desc
          KQL
        }
      },
      {
        "type" = 3
        "name" = "exceptions"
        "content" = {
          "version"       = "KqlItem/1.0"
          "queryType"     = 0
          "resourceType"  = "microsoft.insights/components"
          "visualization" = "table"
          "size"          = 0
          "timeContext" = {
            "durationMs" = 86400000
          }
          "query" = <<-KQL
            exceptions
            | where timestamp > ago(24h)
            | project timestamp, type, problemId, outerMessage, operation_Id
            | order by timestamp desc
            | take 100
          KQL
        }
      }
    ]

    "isLocked" = false

    "defaultResourceIds" = [
      lower(azurerm_application_insights.production.id)
    ]

    "fallbackResourceIds" = [
      lower(azurerm_application_insights.production.id)
    ]
  })

  tags = local.common_tags
}

output "operations_workbook_id" {
  description = "Azure resource ID of the OrderFlow production operations workbook."
  value       = azurerm_application_insights_workbook.production_operations.id
}
