locals {
  root_config = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  root_locals = local.root_config.locals
  image_manifest = jsondecode(file("${get_terragrunt_dir()}/../02-container/image.json"))
}

dependency "foundation" {
  config_path = "../01-foundation"
}

remote_state {
  backend = "local"

  config = {
    path = "${get_repo_root()}/.terraform-state/smoke-application.terraform.tfstate"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = {
  subscription_id                       = local.root_locals.subscription_id
  location                              = local.root_locals.location
  resource_group_name                   = dependency.foundation.outputs.resource_group_name
  container_app_environment_id          = dependency.foundation.outputs.container_apps_environment_id
  container_app_environment_default_domain = dependency.foundation.outputs.container_apps_environment_default_domain
  container_registry_id                 = dependency.foundation.outputs.container_registry_id
  container_registry_login_server       = dependency.foundation.outputs.container_registry_login_server
  container_image_repository            = local.image_manifest.repository
  container_image_digest                = local.image_manifest.digest
  container_app_name                    = "mcmc-mcp-trusted"
  api_management_name                   = dependency.foundation.outputs.api_management_name
  api_management_gateway_url            = dependency.foundation.outputs.api_management_gateway_url
  tags                                  = local.root_locals.common_tags
}
