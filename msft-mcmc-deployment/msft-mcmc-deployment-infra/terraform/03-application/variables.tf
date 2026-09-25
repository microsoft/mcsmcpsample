variable "subscription_id" {
  description = "Azure subscription that owns the application resources."
  type        = string
}

variable "location" {
  description = "Azure region for the application resources."
  type        = string
}

variable "resource_group_name" {
  description = "Foundation resource group containing the application resources."
  type        = string
}

variable "container_app_environment_id" {
  description = "Foundation Container Apps environment resource identifier."
  type        = string
}

variable "container_app_environment_default_domain" {
  description = "Private DNS suffix of the foundation Container Apps environment."
  type        = string
}

variable "container_registry_id" {
  description = "Foundation Azure Container Registry resource identifier."
  type        = string
}

variable "container_registry_login_server" {
  description = "Foundation Azure Container Registry login server."
  type        = string
}

variable "container_image_repository" {
  description = "Fully qualified component repository in ACR."
  type        = string
}

variable "container_image_digest" {
  description = "Immutable sha256 manifest digest produced by Layer 2."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-f]{64}$", var.container_image_digest))
    error_message = "container_image_digest must be a sha256 manifest digest."
  }
}

variable "container_app_name" {
  description = "Name of the trusted-mode Container App."
  type        = string
}

variable "api_management_name" {
  description = "Foundation Azure API Management service name."
  type        = string
}

variable "api_management_gateway_url" {
  description = "Public gateway URL of the foundation Azure API Management service."
  type        = string
}

variable "tags" {
  description = "Tags applied to application resources."
  type        = map(string)
}
