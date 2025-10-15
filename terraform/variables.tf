# -------------------------------
# Project-wide variables
# -------------------------------
variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "brgr-asf"
}

variable "rg_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-brgr-asf"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southeastasia"
}

variable "sql_admin_user" {
  description = "SQL server admin username"
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "SQL server admin password"
  type        = string
  sensitive   = true
  default     = ""
  
}
