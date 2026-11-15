resource "azurerm_log_analytics_workspace" "jenkins" {
  name                = "law-orderflow-jenkins-${local.name_suffix}"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.common_tags
}

resource "azurerm_monitor_data_collection_rule" "jenkins" {
  name                = "dcr-orderflow-jenkins-${local.name_suffix}"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  tags                = local.common_tags

  destinations {
    log_analytics {
      name                  = "jenkins-law"
      workspace_resource_id = azurerm_log_analytics_workspace.jenkins.id
    }
  }

  data_sources {
    performance_counter {
      name                          = "jenkins-performance"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]

      counter_specifiers = [
        "\\Processor Information(_Total)\\% Processor Time",
        "\\Memory\\Available Bytes",
        "\\LogicalDisk(_Total)\\% Free Space",
      ]
    }

    syslog {
      name           = "jenkins-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]

      log_levels = [
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency",
      ]
    }
  }

  data_flow {
    streams = [
      "Microsoft-Perf",
      "Microsoft-Syslog",
    ]

    destinations = ["jenkins-law"]
  }
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.jenkins.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = jsonencode({
    authentication = {
      managedIdentity = {
        "identifier-name"  = "mi_res_id"
        "identifier-value" = azurerm_user_assigned_identity.jenkins.id
      }
    }
  })

  tags = local.common_tags
}

resource "azurerm_monitor_data_collection_rule_association" "jenkins" {
  name                    = "dcra-orderflow-jenkins-${local.name_suffix}"
  target_resource_id      = azurerm_linux_virtual_machine.jenkins.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.jenkins.id
  description             = "Collect Jenkins VM performance counters and warning-level syslog."
}
