# 1. العنوان العام (Public IP) لبوابة التطبيق
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "appgw-public-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 2. مورد بوابة التطبيق (Application Gateway)
resource "azurerm_application_gateway" "appgw" {
  depends_on = [
    azurerm_container_app.frontend,
    azurerm_container_app.backend
  ]
  name                = "burger-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  # تكوين الشبكة (Appgw Subnet) - يستخدم azurerm_subnet.appgw_subnet
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  # تكوين الواجهة الأمامية (Public IP)
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }
  
  # 3. Backend Pools (الوجهات الداخلية)
  
  # Pool 1: Frontend App - يستخدم FQDN الداخلي لـ azurerm_container_app.frontend
  backend_address_pool {
    name = "frontend-pool"
   #fqdns = [azurerm_container_app.frontend.name]
    fqdns = [azurerm_container_app.frontend.ingress[0].fqdn]
  }

  # Pool 2: Backend API - يستخدم FQDN الداخلي لـ azurerm_container_app.backend
  backend_address_pool {
    name = "backend-pool"
    #fqdns = [azurerm_container_app.backend.name]
    fqdns = [azurerm_container_app.backend.ingress[0].fqdn]
  }

  # 4. HTTP Settings (إعدادات الاتصال بالوجهات)
  
  # Settings 1: For Frontend (Port 80)
  backend_http_settings {
    name                  = "frontend-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }
  
  # Settings 2: For Backend (Port 8080)
  backend_http_settings {
    name                  = "backend-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 8080 
    protocol              = "Http"
    request_timeout       = 60
  }
  # === تحديث لسياسة SSL الأحدث والأكثر أماناً (20220101) ===
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }


  # 5. Routing Rule (قاعدة التوجيه بناءً على المسار)
  request_routing_rule {
    name                       = "path-based-routing"
    rule_type                  = "PathBasedRouting"
    http_listener_name         = "http-listener"
    url_path_map_name          = "burger-path-map"
    priority = 10
    # تمت إزالة الإعدادات الافتراضية من هنا
  }
  
  url_path_map {
    name = "burger-path-map"
    # الوجهة الافتراضية (Default) موجودة هنا
    default_backend_address_pool_name = "frontend-pool"
    default_backend_http_settings_name = "frontend-settings"
    
    # القاعدة 1: توجيه /api/* إلى Backend (المطلوب)
    path_rule {
      name                       = "api-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "backend-pool"
      backend_http_settings_name = "backend-settings"
    }
  }
}
