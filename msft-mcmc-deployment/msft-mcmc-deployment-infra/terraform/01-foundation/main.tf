data "azurerm_client_config" "current" {}

locals {
  power_platform_networks = {
    japaneast = {
      address_space = "10.59.0.0/24"
      subnet_prefix = "10.59.0.0/27"
    }
    japanwest = {
      address_space = "10.60.0.0/24"
      subnet_prefix = "10.60.0.0/27"
    }
  }
}

resource "azurerm_resource_group" "deployment" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "deployment" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  sku                 = "Basic"
  admin_enabled       = false

  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_role_assignment" "image_pusher" {
  scope                = azurerm_container_registry.deployment.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_log_analytics_workspace" "deployment" {
  name                = var.log_analytics_workspace_name
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_virtual_network" "deployment" {
  name                = "mcmc-deployment-vnet"
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  address_space       = ["10.58.0.0/24"]
  tags                = var.tags
}

resource "azurerm_virtual_network" "power_platform" {
  for_each = local.power_platform_networks

  name                = "mcmc-power-platform-${each.key}-vnet"
  resource_group_name = azurerm_resource_group.deployment.name
  location            = each.key
  address_space       = [each.value.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "power_platform" {
  for_each = local.power_platform_networks

  name                 = "snet-power-platform"
  resource_group_name  = azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.power_platform[each.key].name
  address_prefixes     = [each.value.subnet_prefix]

  delegation {
    name = "Microsoft.PowerPlatform.enterprisePolicies"

    service_delegation {
      name    = "Microsoft.PowerPlatform/enterprisePolicies"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_virtual_network_peering" "power_platform_to_deployment" {
  for_each = local.power_platform_networks

  name                         = "peer-to-mcmc-deployment"
  resource_group_name          = azurerm_resource_group.deployment.name
  virtual_network_name         = azurerm_virtual_network.power_platform[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.deployment.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "deployment_to_power_platform" {
  for_each = local.power_platform_networks

  name                         = "peer-to-power-platform-${each.key}"
  resource_group_name          = azurerm_resource_group.deployment.name
  virtual_network_name         = azurerm_virtual_network.deployment.name
  remote_virtual_network_id    = azurerm_virtual_network.power_platform[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.deployment.name
  address_prefixes     = ["10.58.0.64/27"]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "api_management" {
  name                = "nsg-api-management"
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  tags                = var.tags

  security_rule {
    name                       = "AllowAzureKeyVaultOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }
}

resource "azurerm_subnet" "api_management" {
  name                 = "snet-api-management"
  resource_group_name  = azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.deployment.name
  address_prefixes     = ["10.58.0.0/27"]

  delegation {
    name = "Microsoft.Web.serverFarms"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

moved {
  from = azurerm_subnet.application_gateway
  to   = azurerm_subnet.private_api_management
}

resource "azurerm_subnet" "private_api_management" {
  name                 = "snet-api-management-private"
  resource_group_name  = azurerm_resource_group.deployment.name
  virtual_network_name = azurerm_virtual_network.deployment.name
  address_prefixes     = ["10.58.0.32/27"]

  delegation {
    name = "Microsoft.Web.serverFarms"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "api_management_private_endpoint" {
  name                              = "snet-apim-private-endpoint"
  resource_group_name               = azurerm_resource_group.deployment.name
  virtual_network_name              = azurerm_virtual_network.deployment.name
  address_prefixes                  = ["10.58.0.96/27"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet_network_security_group_association" "api_management" {
  subnet_id                 = azurerm_subnet.api_management.id
  network_security_group_id = azurerm_network_security_group.api_management.id
}

resource "azurerm_network_security_group" "private_api_management" {
  name                = "nsg-api-management-private"
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  tags                = var.tags

  security_rule {
    name                       = "AllowAzureKeyVaultOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_api_management" {
  subnet_id                 = azurerm_subnet.private_api_management.id
  network_security_group_id = azurerm_network_security_group.private_api_management.id
}

resource "azurerm_container_app_environment" "deployment" {
  name                               = var.container_apps_environment_name
  resource_group_name                = azurerm_resource_group.deployment.name
  location                           = azurerm_resource_group.deployment.location
  log_analytics_workspace_id         = azurerm_log_analytics_workspace.deployment.id
  infrastructure_subnet_id           = azurerm_subnet.container_apps.id
  infrastructure_resource_group_name = var.container_apps_infrastructure_resource_group_name
  internal_load_balancer_enabled     = true
  public_network_access              = "Disabled"
  tags                               = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_private_dns_zone" "container_apps" {
  name                = azurerm_container_app_environment.deployment.default_domain
  resource_group_name = azurerm_resource_group.deployment.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_apps" {
  name                  = "mcmc-container-apps-vnet-link"
  resource_group_name   = azurerm_resource_group.deployment.name
  private_dns_zone_name = azurerm_private_dns_zone.container_apps.name
  virtual_network_id    = azurerm_virtual_network.deployment.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "container_apps_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.container_apps.name
  resource_group_name = azurerm_resource_group.deployment.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.deployment.static_ip_address]
  tags                = var.tags
}

resource "azurerm_api_management" "deployment" {
  name                 = var.api_management_name
  resource_group_name  = azurerm_resource_group.deployment.name
  location             = azurerm_resource_group.deployment.location
  publisher_name       = var.api_management_publisher_name
  publisher_email      = var.api_management_publisher_email
  sku_name             = "StandardV2_1"
  virtual_network_type = "External"
  tags                 = var.tags

  identity {
    type = "SystemAssigned"
  }

  virtual_network_configuration {
    subnet_id = azurerm_subnet.api_management.id
  }

  depends_on = [azurerm_subnet_network_security_group_association.api_management]
}

resource "azurerm_api_management" "private" {
  name                          = "${var.api_management_name}-private"
  resource_group_name           = azurerm_resource_group.deployment.name
  location                      = azurerm_resource_group.deployment.location
  publisher_name                = var.api_management_publisher_name
  publisher_email               = var.api_management_publisher_email
  sku_name                      = "StandardV2_1"
  virtual_network_type          = "External"
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }

  virtual_network_configuration {
    subnet_id = azurerm_subnet.private_api_management.id
  }

  depends_on = [azurerm_subnet_network_security_group_association.private_api_management]
}

resource "azurerm_private_dns_zone" "api_management" {
  name                = "privatelink.azure-api.net"
  resource_group_name = azurerm_resource_group.deployment.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "api_management" {
  name                  = "mcmc-api-management-vnet-link"
  resource_group_name   = azurerm_resource_group.deployment.name
  private_dns_zone_name = azurerm_private_dns_zone.api_management.name
  virtual_network_id    = azurerm_virtual_network.deployment.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "api_management_power_platform" {
  for_each = local.power_platform_networks

  name                  = "mcmc-api-management-${each.key}-link"
  resource_group_name   = azurerm_resource_group.deployment.name
  private_dns_zone_name = azurerm_private_dns_zone.api_management.name
  virtual_network_id    = azurerm_virtual_network.power_platform[each.key].id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "api_management" {
  name                = "pe-${var.api_management_name}-private"
  resource_group_name = azurerm_resource_group.deployment.name
  location            = azurerm_resource_group.deployment.location
  subnet_id           = azurerm_subnet.api_management_private_endpoint.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.api_management_name}-private"
    private_connection_resource_id = azurerm_api_management.private.id
    subresource_names              = ["Gateway"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.api_management.id]
  }
}

resource "azapi_resource" "power_platform_network_injection" {
  type      = "Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview"
  name      = "mcmc-private-connectivity"
  parent_id = azurerm_resource_group.deployment.id
  location  = "japan"

  body = {
    kind = "NetworkInjection"
    properties = {
      networkInjection = {
        virtualNetworks = [
          for region in sort(keys(local.power_platform_networks)) : {
            id = azurerm_virtual_network.power_platform[region].id
            subnet = {
              name = azurerm_subnet.power_platform[region].name
            }
          }
        ]
      }
    }
  }
}

resource "azurerm_role_assignment" "power_platform_policy_reader" {
  scope                = azapi_resource.power_platform_network_injection.id
  role_definition_name = "Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_monitor_diagnostic_setting" "api_management" {
  name                           = "mcmc-apim-diagnostics"
  target_resource_id             = azurerm_api_management.deployment.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.deployment.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "private_api_management" {
  name                           = "mcmc-private-apim-diagnostics"
  target_resource_id             = azurerm_api_management.private.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.deployment.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}