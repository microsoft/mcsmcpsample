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
  subscription_id                                   = local.root_locals.subscription_id
  tenant_id                                         = local.root_locals.tenant_id
  entra_verified_domain                             = "example.onmicrosoft.com"
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
