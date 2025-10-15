resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.project_name}-law"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "${var.project_name}-appi"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}

#############################################
# Action Group (يرسل تنبيه بالإيميل)
#############################################
resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "alerts"

  # عدّلي الإيميل هنا
  email_receiver {
    name                    = "email"
    email_address           = "brgr-asf-alerts@example.com"
    use_common_alert_schema = true
  }

  tags = { project = var.project_name }
}

#############################################
# 1) App Gateway: Backend Unhealthy (> 0)
#    (يعادل "backend health < 100%")
#############################################
resource "azurerm_monitor_metric_alert" "appgw_backend_unhealthy" {
  name                = "${var.project_name}-agw-backend-unhealthy"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_gateway.appgw.id]
  description         = "Alert when any backend becomes unhealthy in App Gateway"
  severity            = 2
  frequency           = "PT1M"   # افحص كل دقيقة
  window_size         = "PT5M"   # خلال آخر 5 دقائق
  auto_mitigate       = true
  enabled             = true

  # Namespace/Metric ثابتة للـ AppGW
  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
    # dimension {
    #   name     = "BackendPoolName"
    #   operator = "Include"
    #   values   = ["pool-api"]
    # }
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }

  tags = { project = var.project_name }
}

#############################################

#############################################
# ACA Backend - CPU %
resource "azurerm_monitor_metric_alert" "aca_backend_cpu" {
  name                = "${var.project_name}-aca-backend-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_app.be.id]
  description         = "ACA backend CPU > 70%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true
  auto_mitigate       = true

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "CpuPercentage"     # ← هذا الاسم الصحيح
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action { action_group_id = azurerm_monitor_action_group.alerts.id }
  tags = { project = var.project_name }
}

# (اختياري) ACA Backend - Memory %
resource "azurerm_monitor_metric_alert" "aca_backend_mem" {
  name                = "${var.project_name}-aca-backend-mem"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_container_app.be.id]
  description         = "ACA backend Memory > 80%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "MemoryPercentage"  # من نفس الجدول
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action { action_group_id = azurerm_monitor_action_group.alerts.id }
  tags = { project = var.project_name }
}

#############################################

#############################################
resource "azurerm_monitor_metric_alert" "sql_high_usage" {
  name                = "${var.project_name}-sql-usage-high"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_mssql_database.db.id]
  description         = "Alert when SQL DB utilization is high"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  enabled             = true

  # ------- اختر واحد من الكريتيريا التالية --------

  # vCore model: CPU %
  criteria {
  metric_namespace = "Microsoft.Sql/servers/databases"
  metric_name      = "dtu_consumption_percent"
  aggregation      = "Average"
  operator         = "GreaterThan"
  threshold        = 80
}

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }

  tags = { project = var.project_name }
}
