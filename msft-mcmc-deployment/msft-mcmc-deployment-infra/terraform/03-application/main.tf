locals {
  container_image          = "${var.container_registry_login_server}/${var.container_image_repository}@${var.container_image_digest}"
  gateway_application_fqdn = "${var.gateway_container_app_name}.${var.container_app_environment_default_domain}"
  native_application_fqdn  = "${var.native_container_app_name}.${var.container_app_environment_default_domain}"
  entra_required_scope     = element(reverse(split("/", var.entra_delegated_scope)), 0)
  gateway_url              = trimsuffix(var.api_management_gateway_url, "/")
  native_mcp_url           = "${local.gateway_url}/native/mcp"
  gateway_mcp_url          = "${local.gateway_url}/gateway/mcp"
  entra_issuer             = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
  openid_configuration     = "${local.entra_issuer}/.well-known/openid-configuration"
  correlation_id           = "@(System.Text.RegularExpressions.Regex.IsMatch(context.Request.Headers.GetValueOrDefault(\"x-correlation-id\", \"\"), \"^[A-Za-z0-9._-]{1,128}$\") ? context.Request.Headers.GetValueOrDefault(\"x-correlation-id\", \"\") : context.RequestId.ToString())"
  response_correlation_id  = "@(context.Request.Headers.GetValueOrDefault(\"x-correlation-id\", context.RequestId.ToString()))"
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
  }
  protected_resource_metadata = {
    native = {
      resource = local.native_mcp_url
      path     = ".well-known/oauth-protected-resource/native/mcp"
    }
    gateway = {
      resource = local.gateway_mcp_url
      path     = ".well-known/oauth-protected-resource/gateway/mcp"
    }
  }
  common_inbound_policy = <<-XML
    <set-header name="x-correlation-id" exists-action="override">
      <value>${local.correlation_id}</value>
    </set-header>
    <choose>
      <when condition="@(context.Request.OriginalUrl.Scheme != &quot;https&quot;)">
        <return-response>
          <set-status code="400" reason="HTTPS Required" />
          <set-header name="x-correlation-id" exists-action="override"><value>${local.response_correlation_id}</value></set-header>
        </return-response>
      </when>
      <when condition="@(context.Request.Headers.ContainsKey(&quot;Content-Length&quot;) &amp;&amp; long.Parse(context.Request.Headers.GetValueOrDefault(&quot;Content-Length&quot;, &quot;0&quot;)) &gt; 1048576)">
        <return-response>
          <set-status code="413" reason="Payload Too Large" />
          <set-header name="x-correlation-id" exists-action="override"><value>${local.response_correlation_id}</value></set-header>
        </return-response>
      </when>
    </choose>
    <rate-limit-by-key calls="120" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
  XML
  common_backend_policy = <<-XML
    <forward-request timeout="300" buffer-request-body="false" buffer-response="false" />
  XML
}

resource "azurerm_user_assigned_identity" "apps_identity" {
  name                = var.apps_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "image_pull" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.apps_identity.principal_id
}

resource "azurerm_container_app" "gateway" {
  name                         = var.gateway_container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps_identity.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = azurerm_user_assigned_identity.apps_identity.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8000
    transport                  = "auto"

    ip_security_restriction {
      name             = "allow-api-management"
      action           = "Allow"
      ip_address_range = var.api_management_subnet_address_prefix
      description      = "Only the delegated API Management subnet may invoke this backend."
    }

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
        value = local.gateway_application_fqdn
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

resource "azurerm_container_app" "native" {
  name                         = var.native_container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps_identity.id]
  }

  registry {
    server   = var.container_registry_login_server
    identity = azurerm_user_assigned_identity.apps_identity.id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8000
    transport                  = "auto"

    ip_security_restriction {
      name             = "allow-api-management"
      action           = "Allow"
      ip_address_range = var.api_management_subnet_address_prefix
      description      = "Only the delegated API Management subnet may invoke this backend."
    }

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
        value = "entra"
      }

      env {
        name  = "MCP_ALLOWED_HOSTS"
        value = local.native_application_fqdn
      }

      env {
        name  = "ENTRA_TENANT_ID"
        value = var.entra_tenant_id
      }

      env {
        name  = "ENTRA_AUDIENCE"
        value = var.entra_api_audience
      }

      env {
        name  = "ENTRA_REQUIRED_SCOPE"
        value = local.entra_required_scope
      }

      env {
        name  = "MCP_RESOURCE_SERVER_URL"
        value = local.native_mcp_url
      }

      env {
        name  = "ENTRA_OID_ACCESS_JSON"
        value = jsonencode(var.entra_oid_access)
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

resource "azurerm_api_management_api" "mcp" {
  for_each = {
    native = {
      display_name = "MCMC Native OAuth MCP"
      path         = "native"
      service_url  = "https://${azurerm_container_app.native.ingress[0].fqdn}"
    }
    gateway = {
      display_name = "MCMC Gateway OAuth MCP"
      path         = "gateway"
      service_url  = "https://${azurerm_container_app.gateway.ingress[0].fqdn}"
    }
  }

  name                  = "mcmc-${each.key}-mcp"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.api_management_name
  revision              = "1"
  display_name          = each.value.display_name
  path                  = each.value.path
  protocols             = ["https"]
  service_url           = each.value.service_url
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "mcp" {
  for_each = {
    for pair in setproduct(keys(azurerm_api_management_api.mcp), keys(local.api_operations)) :
    "${pair[0]}-${pair[1]}" => {
      route     = pair[0]
      operation = pair[1]
    }
  }

  operation_id        = replace(each.value.operation, "_", "-")
  api_name            = azurerm_api_management_api.mcp[each.value.route].name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = local.api_operations[each.value.operation].display_name
  method              = local.api_operations[each.value.operation].method
  url_template        = local.api_operations[each.value.operation].url_template
}

resource "azurerm_api_management_api_policy" "mcp" {
  for_each = azurerm_api_management_api.mcp

  api_name            = each.value.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        ${local.common_inbound_policy}
        ${each.key == "gateway" ? <<-AUTH
        <validate-jwt header-name="Authorization" require-scheme="Bearer" require-expiration-time="true" require-signed-tokens="true" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
          <openid-config url="${local.openid_configuration}" />
          <audiences>
            <audience>${var.entra_api_audience}</audience>
          </audiences>
          <issuers>
            <issuer>${local.entra_issuer}</issuer>
          </issuers>
          <required-claims>
            <claim name="tid" match="all"><value>${var.entra_tenant_id}</value></claim>
            <claim name="scp" match="any" separator=" "><value>${local.entra_required_scope}</value></claim>
          </required-claims>
        </validate-jwt>
        <set-header name="Authorization" exists-action="delete" />
        AUTH
: ""}
      </inbound>
      <backend>
        ${local.common_backend_policy}
      </backend>
      <outbound>
        <base />
        <set-header name="x-correlation-id" exists-action="override">
          <value>${local.response_correlation_id}</value>
        </set-header>
      </outbound>
      <on-error>
        <choose>
          <when condition="@(context.LastError.Reason == &quot;RateLimitExceeded&quot;)">
            <return-response>
              <set-status code="429" reason="Too Many Requests" />
              <set-header name="x-correlation-id" exists-action="override"><value>${local.response_correlation_id}</value></set-header>
              <set-body>Too many requests</set-body>
            </return-response>
          </when>
          <when condition="@(context.LastError.Reason == &quot;TokenNotPresent&quot; || context.LastError.Source == &quot;validate-jwt&quot;)">
            <return-response>
              <set-status code="401" reason="Unauthorized" />
              <set-header name="x-correlation-id" exists-action="override"><value>${local.response_correlation_id}</value></set-header>
              <set-header name="WWW-Authenticate" exists-action="override">
                <value>Bearer resource_metadata="${local.gateway_url}/.well-known/oauth-protected-resource/${each.key}/mcp"</value>
              </set-header>
              <set-body>Unauthorized</set-body>
            </return-response>
          </when>
          <otherwise>
            <return-response>
              <set-status code="500" reason="Gateway Error" />
              <set-header name="x-correlation-id" exists-action="override"><value>${local.response_correlation_id}</value></set-header>
              <set-body>Gateway request failed</set-body>
            </return-response>
          </otherwise>
        </choose>
      </on-error>
    </policies>
  XML
}

resource "azurerm_api_management_api" "metadata" {
  for_each = local.protected_resource_metadata

  name                  = "mcmc-${each.key}-oauth-metadata"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.api_management_name
  revision              = "1"
  display_name          = "MCMC ${title(each.key)} OAuth Metadata"
  path                  = each.value.path
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "metadata" {
  for_each = local.protected_resource_metadata

  operation_id        = "get-protected-resource-metadata"
  api_name            = azurerm_api_management_api.metadata[each.key].name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "Get protected resource metadata"
  method              = "GET"
  url_template        = "/"
}

resource "azurerm_api_management_api_policy" "metadata" {
  for_each = local.protected_resource_metadata

  api_name            = azurerm_api_management_api.metadata[each.key].name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <return-response>
          <set-status code="200" reason="OK" />
          <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
          <set-body>${jsonencode({
  resource                 = each.value.resource
  authorization_servers    = [local.entra_issuer]
  scopes_supported         = [var.entra_delegated_scope]
  bearer_methods_supported = ["header"]
})}</set-body>
        </return-response>
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}
