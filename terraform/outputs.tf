#output "resource_group_name" {
# value = azurerm_resource_group.rg.name
#}

#output "acr_login_server" {
# value = azurerm_container_registry.acr.login_server
#}

#output "acr_admin_username" {
# value = azurerm_container_registry.acr.admin_username
#}

# -------------------------
# Outputs
# -------------------------
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}
