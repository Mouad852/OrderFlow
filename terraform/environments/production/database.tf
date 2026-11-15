variable "postgres_administrator_password" {
  description = "Password for the production PostgreSQL administrator."
  type        = string
  sensitive   = true
}

resource "random_string" "postgresql_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_postgresql_flexible_server" "production" {
  name                = "psqlorderflowprodswe${random_string.postgresql_suffix.result}"
  resource_group_name = azurerm_resource_group.production.name
  location            = azurerm_resource_group.production.location

  version                           = "17"
  administrator_login               = "orderflowowner"
  administrator_password_wo         = var.postgres_administrator_password
  administrator_password_wo_version = 1

  sku_name     = "GP_Standard_D2s_v3"
  storage_mb   = 32768
  storage_tier = "P4"
  zone         = "1"

  backup_retention_days        = 14
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  delegated_subnet_id = azurerm_subnet.postgresql.id
  private_dns_zone_id = data.azurerm_private_dns_zone.postgresql.id

  public_network_access_enabled = false

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server_database" "orderflow" {
  name      = "orderflow"
  server_id = azurerm_postgresql_flexible_server.production.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "postgresql_fqdn" {
  value = azurerm_postgresql_flexible_server.production.fqdn
}
