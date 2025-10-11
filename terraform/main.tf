terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -------------------------
# Resource Group
# -------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# -------------------------
# Azure Container Registry
# -------------------------
resource "azurerm_container_registry" "acr" {
  name                = "bbrgacrnpxttzhb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# -------------------------
# Virtual Network + Subnets
# -------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "burger-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "aca_subnet" {
  name                 = "aca-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]

  delegation {
    name = "delegation-aca"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]

  delegation {
    name = "delegation-postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.3.0/24"]
}

# -------------------------
# Log Analytics Workspace
# -------------------------
resource "azurerm_log_analytics_workspace" "la" {
  name                = "burgerlogs"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# -------------------------
# Container App Environment
# -------------------------
resource "azurerm_container_app_environment" "env" {
  name                           = "burgerbuilder-env"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.la.id
  infrastructure_subnet_id       = azurerm_subnet.aca_subnet.id
  internal_load_balancer_enabled = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

# -------------------------
# PostgreSQL Flexible Server + Database
# -------------------------
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_postgresql_flexible_server" "db_server" {
  name                          = var.db_server_name
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  sku_name                      = "GP_Standard_D2ds_v4"
  version                       = "14"
  administrator_login           = var.db_admin_login
  administrator_password        = var.db_admin_password
  storage_mb                    = 32768
  backup_retention_days         = 7
  public_network_access_enabled = false
  delegated_subnet_id           = azurerm_subnet.db_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  zone = "1"
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "burgerbuilder"
  server_id = azurerm_postgresql_flexible_server.db_server.id
  collation = "C"
  charset   = "UTF8"
}

# -------------------------
# Backend Container App (Private)
# -------------------------
resource "azurerm_container_app" "backend" {
  name                         = "backend-api"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  template {
    container {
      name   = "backend-container"
      image  = "${azurerm_container_registry.acr.login_server}/burger-backend:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.db_server.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.db.name
      }
      env {
        name  = "DB_USERNAME"
        value = var.db_admin_login
      }
      env {
        name  = "DB_PASSWORD"
        value = var.db_admin_password
      }
    }
  }

  ingress {
    external_enabled = true  # private
    target_port      = 8080
    traffic_weight {
    latest_revision = true
    percentage      = 100
  }
  }
}

# -------------------------
# Frontend Container App (Private)
# -------------------------
resource "azurerm_container_app" "frontend" {
  name                         = "frontend-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  secret {
    name  = "acr-password-fe"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password-fe"
  }

  template {
    container {
      name   = "frontend-container"
      image  = "${azurerm_container_registry.acr.login_server}/burger-frontend:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "VITE_API_BASE_URL"
        value = "http://${azurerm_container_app.backend.ingress[0].fqdn}:8080/api"
      }
    }
  }

  ingress {
    external_enabled = true  # private
    target_port      = 80
    traffic_weight {
    latest_revision = true
    percentage      = 100
  }
  }
}
