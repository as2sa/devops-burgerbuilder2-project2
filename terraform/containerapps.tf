resource "azurerm_container_app_environment" "env" {
  name                           = "${var.project_name}-aca-env"
  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id       = azurerm_subnet.snet_aca.id
  internal_load_balancer_enabled = true
}



locals {
  aca_private_zone = azurerm_container_app_environment.env.default_domain
  acr_pw_secret_name = "acr-pw"
  sql_pw_secret_name = "sql-pw"
}

# ===============================
# Backend (Spring)
# ===============================
resource "azurerm_container_app" "be" {
  name                         = "${var.project_name}-backend"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  # Secrets
  secret {
    name  = local.acr_pw_secret_name
    value = azurerm_container_registry.acr.admin_password
  }

  secret {
    name  = local.sql_pw_secret_name
    value = var.sql_admin_password
    
  }

  # ACR
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = local.acr_pw_secret_name
  }

  template {
    # السكيل الصحيح داخل template
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "backend"
#     image  = "${azurerm_container_registry.acr.login_server}/ih-backend:v4"
      image = "${azurerm_container_registry.acr.login_server}/ih-backend:latest"

      cpu    = 0.5
      memory = "1Gi"

      # Spring datasource (Azure SQL)
      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "azure"
      }

      env {
        name  = "DB_HOST"
        value = "brgr-asf-sqlsrv.database.windows.net"
      }

      env {
        name  = "DB_NAME"
        value = "brgr-asf-db"
      }

      env {
        name  = "DB_USERNAME"
        value = var.sql_admin_user
      }

      env {
        name        = "DB_PASSWORD"
        secret_name     = local.sql_pw_secret_name
      }

      env {
        name        = "DB_PORT"
        value = "1433"
      }

      env {
        name        = "DB_DRIVER"
        value = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
      }
      env { 
        name = "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE" 
        value = "health,info" 
        }
      env { 
        name = "MANAGEMENT_HEALTH_DB_ENABLED" 
              value = "false" 
                }

    env {
       name  = "CORS_ALLOWED_ORIGINS"
      value = "http://52.163.112.54"
    }
 
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    allow_insecure_connections = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# ===============================
# Frontend (NGINX / Static)
# ===============================
resource "azurerm_container_app" "fe" {
  name                         = "${var.project_name}-frontend"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  secret {
    name  = local.acr_pw_secret_name
    value = azurerm_container_registry.acr.admin_password
  }

  # ACR
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = local.acr_pw_secret_name
  }

  template {
    min_replicas = 1
    max_replicas = 4

    container {
      name   = "frontend"
     #image  = "${azurerm_container_registry.acr.login_server}/ih-frontend:v10"
      image = "${azurerm_container_registry.acr.login_server}/ih-frontend:latest"

      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "VITE_API_BASE_URL"
       # value = "http://52.163.112.54"
       value = "https://brgr-asf-backend.purplesand-778ee4a5.southeastasia.azurecontainerapps.io"

      }

      readiness_probe {
        transport = "HTTP"
        port      = 80
        path      = "/"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 80
        path      = "/"
      }
    }
  }
  #"/index.html"
  ingress {
    external_enabled = true
    target_port      = 80
    allow_insecure_connections = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
