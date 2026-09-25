output "container_app_id" {
  description = "Resource identifier of the trusted-mode Container App."
  value       = azurerm_container_app.trusted.id
}

output "container_app_name" {
  description = "Name of the trusted-mode Container App."
  value       = azurerm_container_app.trusted.name
}

output "container_app_fqdn" {
  description = "Private FQDN of the trusted-mode Container App."
  value       = azurerm_container_app.trusted.ingress[0].fqdn
}

output "container_image" {
  description = "Immutable ACR image deployed to the Container App."
  value       = local.container_image
}

output "application_identity_principal_id" {
  description = "Microsoft Entra principal used by the Container App."
  value       = azurerm_user_assigned_identity.application.principal_id
}

output "api_management_mcp_url" {
  description = "Public API Management URL for the trusted MCP endpoint."
  value       = "${trimsuffix(var.api_management_gateway_url, "/")}/mcp"
}

output "api_management_health_url" {
  description = "Public API Management URL for the trusted MCP health endpoint."
  value       = "${trimsuffix(var.api_management_gateway_url, "/")}/health"
}

output "api_management_subscription_primary_key" {
  description = "Primary APIM subscription key for the trusted MCP API."
  value       = azurerm_api_management_subscription.trusted_mcp.primary_key
  sensitive   = true
}
