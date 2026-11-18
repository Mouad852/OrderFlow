variable "postgres_administrator_password" {
  description = "Password for the PostgreSQL administrator."
  type        = string
  sensitive   = true
}

resource "random_string" "postgresql_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_postgresql_flexible_server" "staging" {
  name                = "psqlorderflow${random_string.postgresql_suffix.result}"
  resource_group_name = azurerm_resource_group.staging.name
  location            = azurerm_resource_group.staging.location

  version                           = "17"
  administrator_login               = "orderflowowner"
  administrator_password_wo         = var.postgres_administrator_password
  administrator_password_wo_version = 1

  sku_name     = "GP_Standard_D2s_v3"
  storage_mb   = 32768
  storage_tier = "P4"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  delegated_subnet_id = azurerm_subnet.postgresql.id
  private_dns_zone_id = azurerm_private_dns_zone.postgresql.id

  public_network_access_enabled = false

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgresql,
  ]

  tags = {
    application = "orderflow"
    environment = "staging"
    managed_by  = "terraform"
  }
}

resource "azurerm_postgresql_flexible_server_database" "orderflow" {
  name      = "orderflow"
  server_id = azurerm_postgresql_flexible_server.staging.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "postgresql_fqdn" {
  value = azurerm_postgresql_flexible_server.staging.fqdn
}
