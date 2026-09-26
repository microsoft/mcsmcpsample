data "azuread_client_config" "current" {}

data "azuread_user" "customer_admin" {
  user_principal_name = var.entra_customer_admin_user_principal_name
}

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

  mcp_connector_clients = {
    public_native = {
      display_name  = "MCMC Public Native MCP Connector"
      redirect_uris = lookup(var.entra_mcp_connector_redirect_uris, "public_native", [])
    }
    public_gateway = {
      display_name  = "MCMC Public Gateway MCP Connector"
      redirect_uris = lookup(var.entra_mcp_connector_redirect_uris, "public_gateway", [])
    }
  }
}

resource "random_uuid" "mcp_access_scope" {}

resource "azuread_application" "mcp_api" {
  display_name            = "MCMC MCP API"
  description             = "Delegated API registration for the MCMC demonstration MCP server."
  sign_in_audience        = "AzureADMyOrg"
  identifier_uris         = ["api://${var.entra_verified_domain}/mcmc-mcp"]
  group_membership_claims = ["SecurityGroup"]
  owners                  = [data.azuread_client_config.current.object_id]

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

resource "azuread_group" "customer_admins" {
  display_name            = var.entra_customer_admin_group_name
  security_enabled        = true
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]
  members = [
    azuread_user.demo["james"].object_id,
    azuread_user.demo["jane"].object_id,
    data.azuread_user.customer_admin.object_id,
  ]
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

resource "azuread_application" "mcp_connector" {
  for_each = local.mcp_connector_clients

  display_name     = each.value.display_name
  description      = "Confidential client used by the corresponding Copilot Studio MCP connector."
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  required_resource_access {
    resource_app_id = azuread_application.mcp_api.client_id

    resource_access {
      id   = random_uuid.mcp_access_scope.result
      type = "Scope"
    }
  }

  dynamic "web" {
    for_each = length(each.value.redirect_uris) == 0 ? [] : [each.value.redirect_uris]

    content {
      redirect_uris = web.value
    }
  }
}

resource "azuread_service_principal" "mcp_connector" {
  for_each = azuread_application.mcp_connector

  client_id                    = each.value.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "mcp_connector" {
  for_each = azuread_application.mcp_connector

  application_id = each.value.id
  display_name   = "Copilot Studio connector credential"
  end_date       = timeadd(timestamp(), "17520h")

  lifecycle {
    ignore_changes = [end_date]
  }
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
    MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_ID=${azuread_application.mcp_connector["public_native"].client_id}
    MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_SECRET=${jsonencode(azuread_application_password.mcp_connector["public_native"].value)}
    MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_ID=${azuread_application.mcp_connector["public_gateway"].client_id}
    MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_SECRET=${jsonencode(azuread_application_password.mcp_connector["public_gateway"].value)}
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