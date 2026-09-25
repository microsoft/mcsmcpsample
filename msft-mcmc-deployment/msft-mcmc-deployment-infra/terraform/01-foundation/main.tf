data "azurerm_client_config" "current" {}

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
  name                = "mcmc-smoke-677e8052-logs"
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

resource "azurerm_subnet_network_security_group_association" "api_management" {
  subnet_id                 = azurerm_subnet.api_management.id
  network_security_group_id = azurerm_network_security_group.api_management.id
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