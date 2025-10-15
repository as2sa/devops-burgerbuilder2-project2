# SQL Server
resource "azurerm_mssql_server" "sql" {
  name                          = "${var.project_name}-sqlsrv"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_user
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
}

# Database (DTU Basic)
resource "azurerm_mssql_database" "db" {
  name           = "${var.project_name}-db"
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "Basic"
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 2
  zone_redundant = false
}

# Private DNS Zone for SQL PE
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link VNet to the zone
resource "azurerm_private_dns_zone_virtual_network_link" "sql_link" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# Private Endpoint (in your data subnet)
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "${var.project_name}-sql-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_data_v2.id

  private_service_connection {
    name                           = "sql-psc"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  # ⬇️ خلي Azure ينشئ ال A-record تلقائياً
  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
