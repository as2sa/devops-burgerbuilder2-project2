variable "location" {
  description = "Azure region (location) to deploy resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Resource Group"
  type        = string
  default     = "BurgerBuilderRG-ACA"
}

variable "acr_name_prefix" {
  description = "Prefix for the ACR name; a random suffix will be appended to ensure uniqueness"
  type        = string
  default     = "bbrgacr"
}

variable "db_server_name" {
  description = "PostgreSQL flexible server name"
  type        = string
  default     = "burger-db-server"
}

variable "db_admin_login" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password (sensitive). Set via terraform.tfvars or TF_VAR_db_admin_password env var."
  type        = string
  sensitive   = true
}
