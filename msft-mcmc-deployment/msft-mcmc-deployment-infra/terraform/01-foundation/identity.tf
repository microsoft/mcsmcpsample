data "azuread_client_config" "current" {}

locals {
  demo_users = {
    james = {
      display_name  = "James MCMC Demo"
      given_name    = "James"
      surname       = "Demo"
      mail_nickname = "mcmc-james"
      customers     = ["CUST-1001", "CUST-1002"]
    }
    jane = {
      display_name  = "Jane MCMC Demo"
      given_name    = "Jane"
      surname       = "Demo"
      mail_nickname = "mcmc-jane"
      customers     = ["CUST-1003", "CUST-1004"]
    }
    bill = {
      display_name  = "Bill MCMC Demo"
      given_name    = "Bill"
      surname       = "Demo"
      mail_nickname = "mcmc-bill"
      customers     = []
    }
  }
}

resource "random_uuid" "mcp_access_scope" {}

resource "azuread_application" "mcp_api" {
  display_name     = "MCMC MCP API"
  description      = "Delegated API registration for the MCMC demonstration MCP server."
  sign_in_audience = "AzureADMyOrg"
  identifier_uris  = ["api://${var.entra_verified_domain}/mcmc-mcp"]
  owners           = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Access the MCMC demonstration MCP server as the signed-in user."
      admin_consent_display_name = "Access the MCMC MCP server"
      enabled                    = true
      id                         = random_uuid.mcp_access_scope.result
      type                       = "User"
      user_consent_description   = "Allow this application to access the MCMC demonstration MCP server on your behalf."
      user_consent_display_name  = "Access the MCMC MCP server"
      value                      = "access_as_user"
    }
  }
}

resource "azuread_service_principal" "mcp_api" {
  client_id                    = azuread_application.mcp_api.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application" "mcp_cli" {
  display_name                   = "MCMC MCP CLI"
  description                    = "Native public client for the MCMC demonstration device-code flow."
  sign_in_audience               = "AzureADMyOrg"
  fallback_public_client_enabled = true
  owners                         = [data.azuread_client_config.current.object_id]

  public_client {
    redirect_uris = ["http://localhost"]
  }

  required_resource_access {
    resource_app_id = azuread_application.mcp_api.client_id

    resource_access {
      id   = random_uuid.mcp_access_scope.result
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "mcp_cli" {
  client_id                    = azuread_application.mcp_cli.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "random_password" "demo_user" {
  for_each = local.demo_users

  length           = 24
  min_lower        = 4
  min_numeric      = 4
  min_special      = 4
  min_upper        = 4
  override_special = "!@%_-"
}

resource "azuread_user" "demo" {
  for_each = local.demo_users

  user_principal_name   = "${each.value.mail_nickname}@${var.entra_verified_domain}"
  display_name          = each.value.display_name
  given_name            = each.value.given_name
  surname               = each.value.surname
  mail_nickname         = each.value.mail_nickname
  password              = random_password.demo_user[each.key].result
  force_password_change = true
  usage_location        = "SE"
}

resource "local_sensitive_file" "environment" {
  filename             = var.local_env_file_path
  file_permission      = "0600"
  directory_permission = "0700"
  content              = <<-ENV
    MCMC_ENTRA_TENANT_ID=${var.tenant_id}
    MCMC_ENTRA_API_CLIENT_ID=${azuread_application.mcp_api.client_id}
    MCMC_ENTRA_API_AUDIENCE=${azuread_application.mcp_api.client_id}
    MCMC_ENTRA_SCOPE=${one(azuread_application.mcp_api.identifier_uris)}/access_as_user
    MCMC_ENTRA_CLI_CLIENT_ID=${azuread_application.mcp_cli.client_id}
    MCMC_JAMES_UPN=${azuread_user.demo["james"].user_principal_name}
    MCMC_JAMES_OID=${azuread_user.demo["james"].object_id}
    MCMC_JAMES_INITIAL_PASSWORD=${jsonencode(random_password.demo_user["james"].result)}
    MCMC_JANE_UPN=${azuread_user.demo["jane"].user_principal_name}
    MCMC_JANE_OID=${azuread_user.demo["jane"].object_id}
    MCMC_JANE_INITIAL_PASSWORD=${jsonencode(random_password.demo_user["jane"].result)}
    MCMC_BILL_UPN=${azuread_user.demo["bill"].user_principal_name}
    MCMC_BILL_OID=${azuread_user.demo["bill"].object_id}
    MCMC_BILL_INITIAL_PASSWORD=${jsonencode(random_password.demo_user["bill"].result)}
  ENV
}