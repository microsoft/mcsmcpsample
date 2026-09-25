output "resource_group_name" {
  description = "Resource group containing user-managed deployment resources."
  value       = azurerm_resource_group.deployment.name
}

output "container_registry_name" {
  description = "Azure Container Registry name used for application images."
  value       = azurerm_container_registry.deployment.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server used by image build and application layers."
  value       = azurerm_container_registry.deployment.login_server
}

output "container_registry_id" {
  description = "Resource identifier of the Azure Container Registry."
  value       = azurerm_container_registry.deployment.id
}

output "image_pusher_principal_id" {
  description = "Microsoft Entra principal granted AcrPush for image publication."
  value       = data.azurerm_client_config.current.object_id
}

output "container_apps_environment_id" {
  description = "Resource identifier of the private Container Apps environment."
  value       = azurerm_container_app_environment.deployment.id
}

output "container_apps_environment_default_domain" {
  description = "Default private DNS suffix of the Container Apps environment."
  value       = azurerm_container_app_environment.deployment.default_domain
}

output "container_apps_environment_static_ip" {
  description = "Internal static IP of the Container Apps environment."
  value       = azurerm_container_app_environment.deployment.static_ip_address
}

output "log_analytics_workspace_id" {
  description = "Resource identifier of the shared Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.deployment.id
}

output "virtual_network_id" {
  description = "Resource identifier of the deployment virtual network."
  value       = azurerm_virtual_network.deployment.id
}

output "container_apps_subnet_id" {
  description = "Resource identifier of the delegated Container Apps subnet."
  value       = azurerm_subnet.container_apps.id
}

output "api_management_id" {
  description = "Resource identifier of the shared Azure API Management service."
  value       = azurerm_api_management.deployment.id
}

output "api_management_name" {
  description = "Name of the shared Azure API Management service."
  value       = azurerm_api_management.deployment.name
}

output "api_management_gateway_url" {
  description = "Public gateway URL of the shared Azure API Management service."
  value       = azurerm_api_management.deployment.gateway_url
}

output "api_management_subnet_id" {
  description = "Resource identifier of the delegated API Management integration subnet."
  value       = azurerm_subnet.api_management.id
}

output "entra_tenant_id" {
  description = "Microsoft Entra tenant identifier used by the MCP API."
  value       = var.tenant_id
}

output "entra_mcp_api_client_id" {
  description = "Client identifier of the MCP API application registration."
  value       = azuread_application.mcp_api.client_id
}

output "entra_mcp_api_audience" {
  description = "Expected audience of MCP API access tokens."
  value       = one(azuread_application.mcp_api.identifier_uris)
}

output "entra_mcp_delegated_scope" {
  description = "Fully qualified delegated scope requested by native clients."
  value       = "${one(azuread_application.mcp_api.identifier_uris)}/access_as_user"
}

output "entra_mcp_cli_client_id" {
  description = "Client identifier of the native public CLI application registration."
  value       = azuread_application.mcp_cli.client_id
}

output "entra_demo_user_principal_names" {
  description = "User principal names of the disposable demonstration users."
  value       = { for name, user in azuread_user.demo : name => user.user_principal_name }
}

output "entra_demo_user_object_ids" {
  description = "Immutable object identifiers of the disposable demonstration users."
  value       = { for name, user in azuread_user.demo : name => user.object_id }
}

output "entra_oid_access" {
  description = "Customer access policy keyed by immutable Microsoft Entra object identifier."
  value = {
    for name, user in azuread_user.demo : user.object_id => local.demo_users[name].customers
  }
}