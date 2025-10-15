#############################################
# ============== LOCAL HELPERS =============
#############################################


#############################################
# ====== Private DNS for ACA Internal ======
#############################################
resource "azurerm_private_dns_zone" "aca" {
  name                = azurerm_container_app_environment.env.default_domain
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca_link" {
  name                  = "aca-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aca.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# نوجّه سجلات الـ FE/BE إلى IP الـ ILB الخاص ببيئة الـ ACA
# (متاح عندما internal_load_balancer_enabled = true)
resource "azurerm_private_dns_a_record" "fe_a" {
  name                = "brgr-asf-frontend"
  zone_name           = azurerm_private_dns_zone.aca.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 30
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

resource "azurerm_private_dns_a_record" "be_a" {
  name                = "brgr-asf-backend"
  zone_name           = azurerm_private_dns_zone.aca.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 30
  records             = [azurerm_container_app_environment.env.static_ip_address]
}

#############################################
# ============= Public IP (Std) ============
#############################################

resource "azurerm_public_ip" "pip_appgw" {
  name                = "${var.project_name}-appgw-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { project = var.project_name }
}

#############################################
# ============ WAF Policy (OWASP) ==========
#############################################



#############################################
# ======== Application Gateway (v2) ========
#############################################

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.project_name}-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  enable_http2        = true


  sku {
  name     = "Standard_v2"
  tier     = "Standard_v2"
  capacity = 1
 }

  # TLS policy حديثة
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  gateway_ip_configuration {
    name      = "gwipc"
    subnet_id = azurerm_subnet.snet_appgw.id
  }

  frontend_ip_configuration {
    name                 = "feip"
    public_ip_address_id = azurerm_public_ip.pip_appgw.id
  }

  frontend_port {
    name = "feport80"
    port = 80
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "feip"
    frontend_port_name             = "feport80"
    protocol                       = "Http"
  }

  # ===== Probes (معدّلة) =====
  # Frontend probe
 # ===== Probes =====
# Frontend (NGINX) — يشيّك على /health اللي ضفتيه في nginx.conf
probe {
  name                                      = "probe-fe"
  protocol                                  = "Http"
  path                                      = "/"
  interval                                  = 30
  timeout                                   = 60
  unhealthy_threshold                       = 3
  pick_host_name_from_backend_http_settings = true
}

# Backend (Spring) — يشيّك على /actuator/health
probe {
  name                                      = "probe-api"
  protocol                                  = "Http"
  path                                      = "/actuator/health"
  interval                                  = 30     # ممكن 60 لو كان بطيء
  timeout                                   = 90
  unhealthy_threshold                       = 3
  pick_host_name_from_backend_http_settings = true
}

backend_http_settings {
  name                                = "fe-http"
  cookie_based_affinity               = "Disabled"   # <— مطلوب
  port                                = 80
  protocol                            = "Http"
  request_timeout                     = 30
  pick_host_name_from_backend_address = true
  probe_name                          = "probe-fe"
}

backend_http_settings {
  name                                = "api-http"
  cookie_based_affinity               = "Disabled"   # <— مطلوب
  port                                = 80
  protocol                            = "Http"
  request_timeout                     = 90
  pick_host_name_from_backend_address = true
  probe_name                          = "probe-api"
}

  # ===== Backend Pools (FQDNs للـ ACA) =====
  backend_address_pool {
    name  = "pool-fe"
    fqdns = ["brgr-asf-frontend.${local.aca_private_zone}"]
  }


  backend_address_pool {
    name  = "pool-api"
    fqdns = ["brgr-asf-backend.${local.aca_private_zone}"]
  }

  # ===== Path-based routing =====
  request_routing_rule {
    name               = "path-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "http"
    url_path_map_name  = "api-map"
    priority           = 1
  }

  url_path_map {
    name                               = "api-map"
    default_backend_address_pool_name  = "pool-fe"
    default_backend_http_settings_name = "fe-http"

    path_rule {
      name                       = "api-to-backend"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "pool-api"
      backend_http_settings_name = "api-http"
    }
  }

  tags = { project = var.project_name }
}
