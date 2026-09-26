locals {
  root_config = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  root_locals = local.root_config.locals
}

remote_state {
  backend = "local"

  config = {
    path = "${get_repo_root()}/.terraform-state/foundation.terraform.tfstate"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = {
  subscription_id                          = local.root_locals.subscription_id
  tenant_id                                = local.root_locals.tenant_id
  entra_verified_domain                    = "example.onmicrosoft.com"
  entra_customer_admin_group_name          = "mcmc-customer-admins"
  entra_customer_admin_user_principal_name = "admin@example.onmicrosoft.com"
  entra_mcp_connector_redirect_uris = {
    public_native = [
      "https://global.consent.azure-apim.net/redirect/mcmc-5fmcmc-20public-20native-20mcp-202-5f5e91a8aaf86d61ed",
      "https://global.consent.azure-apim.net/redirect/crd78-5fmcmc-20public-20native-20mcp-5fdc637fe08ae6ec65",
    ]
    public_gateway = [
      "https://global.consent.azure-apim.net/redirect/mcmc-5fmcmc-20public-20gateway-20mcp-202-5f5e91a8aaf86d61ed",
      "https://global.consent.azure-apim.net/redirect/crd78-5fmcmc-20public-20gateway-20mcp-5fdc637fe08ae6ec65",
    ]
  }
  local_env_file_path                               = "${get_repo_root()}/.env"
  location                                          = local.root_locals.location
  resource_group_name                               = "mcmc-deployment-rg"
  container_registry_name                           = "mcmc${local.root_locals.name_suffix}"
  log_analytics_workspace_name                      = "mcmc-${local.root_locals.name_suffix}-logs"
  container_apps_environment_name                   = "mcmc-container-apps"
  container_apps_infrastructure_resource_group_name = "mcmc-container-apps-managed-rg"
  api_management_name                               = "mcmc-${local.root_locals.name_suffix}-apim"
  api_management_publisher_name                     = "Microsoft Copilot Studio MCP demo"
  api_management_publisher_email                    = "admin@example.onmicrosoft.com"
  tags                                              = local.root_locals.common_tags
}
