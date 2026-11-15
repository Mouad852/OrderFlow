resource "azurerm_recovery_services_vault" "jenkins" {
  name                          = "rsv-orderflow-jenkins-${local.name_suffix}"
  location                      = azurerm_resource_group.jenkins.location
  resource_group_name           = azurerm_resource_group.jenkins.name
  sku                           = "Standard"
  storage_mode_type             = "LocallyRedundant"
  public_network_access_enabled = true
  tags                          = local.common_tags
}

resource "azurerm_backup_policy_vm" "jenkins" {
  name                = "bp-orderflow-jenkins-daily"
  resource_group_name = azurerm_resource_group.jenkins.name
  recovery_vault_name = azurerm_recovery_services_vault.jenkins.name
  policy_type         = "V2"
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "21:00"
  }

  retention_daily {
    count = 7
  }

  instant_restore_retention_days = 2
}

resource "azurerm_backup_protected_vm" "jenkins" {
  resource_group_name = azurerm_resource_group.jenkins.name
  recovery_vault_name = azurerm_recovery_services_vault.jenkins.name
  source_vm_id        = azurerm_linux_virtual_machine.jenkins.id
  backup_policy_id    = azurerm_backup_policy_vm.jenkins.id
}
