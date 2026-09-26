variable "subscription_id" {
  description = "Azure subscription that owns the deployment foundation."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant that owns demonstration identities."
  type        = string
}

variable "entra_verified_domain" {
  description = "Verified Microsoft Entra domain used for application identifiers and test users."
  type        = string
}

variable "local_env_file_path" {
  description = "Absolute path of the gitignored root environment file containing sensitive demonstration identity data."
  type        = string
}

variable "location" {
  description = "Azure region for the deployment foundation."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing user-managed deployment resources."
  type        = string
}

variable "container_registry_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the shared Log Analytics workspace."
  type        = string
}

variable "container_apps_environment_name" {
  description = "Name of the private Container Apps environment."
  type        = string
}

variable "container_apps_infrastructure_resource_group_name" {
  description = "Name of the Azure-managed Container Apps infrastructure resource group."
  type        = string
}

variable "api_management_name" {
  description = "Globally unique Azure API Management service name."
  type        = string
}

variable "api_management_publisher_name" {
  description = "Publisher name displayed by Azure API Management."
  type        = string
}

variable "api_management_publisher_email" {
  description = "Publisher contact email used by Azure API Management."
  type        = string
}

variable "tags" {
  description = "Tags applied to deployment foundation resources."
  type        = map(string)
}