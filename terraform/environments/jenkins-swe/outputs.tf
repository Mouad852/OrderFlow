output "resource_group_name" {
  value = azurerm_resource_group.jenkins.name
}

output "jenkins_fqdn" {
  value = azurerm_public_ip.jenkins.fqdn
}

output "jenkins_url" {
  value = "https://${azurerm_public_ip.jenkins.fqdn}"
}

output "jenkins_public_ip" {
  value = azurerm_public_ip.jenkins.ip_address
}

output "jenkins_identity_client_id" {
  value = azurerm_user_assigned_identity.jenkins.client_id
}

output "jenkins_identity_principal_id" {
  value = azurerm_user_assigned_identity.jenkins.principal_id
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.jenkins.fqdn}"
}
