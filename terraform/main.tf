resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}
#terraform {
#  backend "azurerm" {
#    resource_group_name   = "rg-brgr-asf"
#    storage_account_name  = "brgr-asf-tfstateacct"
#    container_name        = "tfstate"
#    key                   = "infra-brgr-asf.tfstate"
#  }
#}

# نقرأ الـ Environment من Azure
