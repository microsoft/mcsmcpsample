locals {
  subscription_id = get_env("ARM_SUBSCRIPTION_ID")
  tenant_id       = get_env("ARM_TENANT_ID")
  location        = "swedencentral"
  name_suffix     = substr(local.subscription_id, 0, 8)

  common_tags = {
    disposable = "true"
    managed_by = "terraform"
    purpose    = "mcmc-copilot-studio-demo"
    ticket     = "MCMC001"
  }
}
