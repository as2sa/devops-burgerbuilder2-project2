output "appgw_public_ip" { value = azurerm_public_ip.pip_appgw.ip_address }
output "fe_internal_fqdn" { value = azurerm_container_app.fe.latest_revision_fqdn }
output "be_internal_fqdn" { value = azurerm_container_app.be.latest_revision_fqdn }
output "sql_server" { value = azurerm_mssql_server.sql.fully_qualified_domain_name }
