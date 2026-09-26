output "gateway_container_app_id" {
  description = "Resource identifier of the gateway Container App running in trusted mode."
  value       = azurerm_container_app.gateway.id
}

output "gateway_container_app_name" {
  description = "Name of the gateway Container App running in trusted mode."
  value       = azurerm_container_app.gateway.name
}

output "gateway_container_app_fqdn" {
  description = "Private FQDN of the gateway Container App running in trusted mode."
  value       = azurerm_container_app.gateway.ingress[0].fqdn
}

output "native_container_app_id" {
  description = "Resource identifier of the native Container App running in Entra mode."
  value       = azurerm_container_app.native.id
}

output "native_container_app_name" {
  description = "Name of the native Container App running in Entra mode."
  value       = azurerm_container_app.native.name
}

output "native_container_app_fqdn" {
  description = "Private FQDN of the native Container App running in Entra mode."
  value       = azurerm_container_app.native.ingress[0].fqdn
}

output "native_mcp_url" {
  description = "Private Streamable HTTP endpoint of the native Container App."
  value       = "https://${azurerm_container_app.native.ingress[0].fqdn}/mcp"
}

output "container_image" {
  description = "Immutable ACR image deployed to both Container Apps."
  value       = local.container_image
}

output "apps_identity_principal_id" {
  description = "Microsoft Entra principal shared by both Container Apps."
  value       = azurerm_user_assigned_identity.apps_identity.principal_id
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
