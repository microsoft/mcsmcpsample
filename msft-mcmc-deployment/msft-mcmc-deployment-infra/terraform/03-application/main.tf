locals {
  container_image  = "${var.container_registry_login_server}/${var.container_image_repository}@${var.container_image_digest}"
  application_fqdn = "${var.container_app_name}.${var.container_app_environment_default_domain}"
  api_operations = {
    mcp_get = {
      display_name = "Open MCP stream"
      method       = "GET"
      url_template = "/mcp"
    }
    mcp_post = {
      display_name = "Send MCP request"
      method       = "POST"
      url_template = "/mcp"
    }
    mcp_delete = {
      display_name = "Close MCP session"
      method       = "DELETE"
      url_template = "/mcp"
    }
    health_get = {
      display_name = "Check MCP service health"
      method       = "GET"
      url_template = "/health"
    }
  }
}

resource "azurerm_user_assigned_identity" "application" {
  name                = "${var.container_app_name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "image_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.application.principal_id
}

resource "azurerm_container_app" "trusted" {
  name                         = var.container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = azurerm_user_assigned_identity.application.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8000
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "mcp-service"
      image  = local.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AUTH_MODE"
        value = "trusted"
      }

      env {
        name  = "MCP_ALLOWED_HOSTS"
        value = local.application_fqdn
      }

      startup_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8000
        initial_delay           = 1
        interval_seconds        = 3
        timeout                 = 2
        failure_count_threshold = 30
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8000
        interval_seconds        = 5
        timeout                 = 2
        failure_count_threshold = 6
        success_count_threshold = 1
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8000
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 2
        failure_count_threshold = 3
      }
    }
  }

  depends_on = [azurerm_role_assignment.image_pull]
}

resource "azurerm_api_management_api" "trusted_mcp" {
  name                  = "mcmc-trusted-mcp"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.api_management_name
  revision              = "1"
  display_name          = "MCMC Trusted MCP"
  path                  = ""
  protocols             = ["https"]
  service_url           = "https://${azurerm_container_app.trusted.ingress[0].fqdn}"
  subscription_required = true
}

resource "azurerm_api_management_subscription" "trusted_mcp" {
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCMC trusted MCP client"
  api_id              = trimsuffix(azurerm_api_management_api.trusted_mcp.id, ";rev=${azurerm_api_management_api.trusted_mcp.revision}")
  state               = "active"
  allow_tracing       = false
}

resource "azurerm_api_management_api_operation" "trusted_mcp" {
  for_each = local.api_operations

  operation_id        = replace(each.key, "_", "-")
  api_name            = azurerm_api_management_api.trusted_mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = each.value.display_name
  method              = each.value.method
  url_template        = each.value.url_template
}

resource "azurerm_api_management_api_policy" "trusted_mcp" {
  api_name            = azurerm_api_management_api.trusted_mcp.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
      </inbound>
      <backend>
        <forward-request timeout="300" buffer-request-body="false" buffer-response="false" />
      </backend>
      <outbound>
        <base />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
  XML
}
