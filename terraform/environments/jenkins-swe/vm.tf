resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "vm-orderflow-jenkins-${local.name_suffix}"
  computer_name       = "orderflow-jenkins"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true
  secure_boot_enabled             = true
  vtpm_enabled                    = true

  network_interface_ids = [
    azurerm_network_interface.jenkins.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.jenkins.id,
    ]
  }

  os_disk {
    name                 = "osdisk-orderflow-jenkins-${local.name_suffix}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(
    templatefile("${path.module}/cloud-init.tftpl", {
      admin_username   = var.admin_username
      jenkins_hostname = azurerm_public_ip.jenkins.fqdn
      jenkins_image    = "jenkins/jenkins:2.590-jdk21@sha256:1b8068fd8b82518be3bb2e89560efa44f67f5fbc1ab3a9b59826c7f8f70f2260"
      caddy_image      = "caddy:2.10.2-alpine@sha256:4c6e91c6ed0e2fa03efd5b44747b625fec79bc9cd06ac5235a779726618e530d"
    })
  )

  boot_diagnostics {}

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.jenkins,
  ]
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "jenkins" {
  virtual_machine_id    = azurerm_linux_virtual_machine.jenkins.id
  location              = azurerm_resource_group.jenkins.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = "Morocco Standard Time"
  tags                  = local.common_tags

  notification_settings {
    enabled = false
  }
}
