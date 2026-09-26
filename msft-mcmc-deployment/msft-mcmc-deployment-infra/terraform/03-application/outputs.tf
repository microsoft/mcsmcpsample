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

output "entra_container_app_id" {
  description = "Resource identifier of the Entra-mode Container App."
  value       = azurerm_container_app.entra.id
}

output "entra_container_app_name" {
  description = "Name of the Entra-mode Container App."
  value       = azurerm_container_app.entra.name
}

output "entra_container_app_fqdn" {
  description = "Private FQDN of the Entra-mode Container App."
  value       = azurerm_container_app.entra.ingress[0].fqdn
}

output "entra_mcp_url" {
  description = "Private Streamable HTTP endpoint of the Entra-mode Container App."
  value       = "https://${azurerm_container_app.entra.ingress[0].fqdn}/mcp"
}

output "container_image" {
  description = "Immutable ACR image deployed to both Container Apps."
  value       = local.container_image
}

output "application_identity_principal_id" {
  description = "Microsoft Entra principal used by the Container App."
  value       = azurerm_user_assigned_identity.application.principal_id
}

output "api_management_native_mcp_url" {
  description = "Public APIM MCP URL that passes bearer tokens to the Entra-mode backend."
  value       = local.native_mcp_url
}

output "api_management_gateway_mcp_url" {
  description = "Public APIM MCP URL that validates bearer tokens before invoking the trusted backend."
  value       = local.gateway_mcp_url
}

output "api_management_oauth_metadata_urls" {
  description = "Protected-resource metadata URLs for the governed MCP routes."
  value = {
    for route, metadata in local.protected_resource_metadata :
    route => "${local.gateway_url}/${metadata.path}"
  }
}
