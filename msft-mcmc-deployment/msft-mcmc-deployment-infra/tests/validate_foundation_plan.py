import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_foundation_plan.py PLAN_JSON")

    plan = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    resources = plan["planned_values"]["root_module"]["resources"]
    indexed = {
        (resource["type"], resource["name"], resource.get("index")): resource["values"]
        for resource in resources
    }

    public_apim = indexed[("azurerm_api_management", "deployment", None)]
    private_apim = indexed[("azurerm_api_management", "private", None)]
    for ingress, apim in (("public", public_apim), ("private", private_apim)):
        if apim["sku_name"] != "StandardV2_1" or apim["virtual_network_type"] != "External":
            fail(f"{ingress} APIM must use Standard v2 outbound VNet integration")
    if not public_apim["public_network_access_enabled"]:
        fail("public APIM must retain public network access")
    if private_apim["public_network_access_enabled"]:
        fail("private APIM must disable public network access")

    private_endpoint = indexed[("azurerm_private_endpoint", "api_management", None)]
    connection = private_endpoint["private_service_connection"][0]
    if connection["subresource_names"] != ["Gateway"]:
        fail("APIM private endpoint must target the Gateway subresource")
    if connection["private_connection_resource_id"] != private_apim["id"]:
        fail("APIM private endpoint must target the private APIM instance")

    private_dns = indexed[("azurerm_private_dns_zone", "api_management", None)]
    if private_dns["name"] != "privatelink.azure-api.net":
        fail("APIM must use the documented Private Link DNS zone")

    expected_networks = {
        "japaneast": ("japaneast", "10.59.0.0/24", "10.59.0.0/27"),
        "japanwest": ("japanwest", "10.60.0.0/24", "10.60.0.0/27"),
    }
    for region, (location, address_space, subnet_prefix) in expected_networks.items():
        network = indexed[("azurerm_virtual_network", "power_platform", region)]
        subnet = indexed[("azurerm_subnet", "power_platform", region)]
        if network["location"] != location or network["address_space"] != [address_space]:
            fail(f"{region} Power Platform VNet has an unexpected region or address space")
        if subnet["address_prefixes"] != [subnet_prefix]:
            fail(f"{region} Power Platform subnet has an unexpected address range")
        delegation = subnet["delegation"][0]["service_delegation"][0]["name"]
        if delegation != "Microsoft.PowerPlatform/enterprisePolicies":
            fail(f"{region} subnet is not delegated to Power Platform")
        indexed[("azurerm_virtual_network_peering", "power_platform_to_deployment", region)]
        indexed[("azurerm_virtual_network_peering", "deployment_to_power_platform", region)]
        indexed[("azurerm_private_dns_zone_virtual_network_link", "api_management_power_platform", region)]

    policy = indexed[("azapi_resource", "power_platform_network_injection", None)]
    if policy["location"] != "japan" or policy["body"]["kind"] != "NetworkInjection":
        fail("Power Platform enterprise policy must be a Japan network-injection policy")
    policy_networks = policy["body"]["properties"]["networkInjection"]["virtualNetworks"]
    if len(policy_networks) != 2:
        fail("Power Platform enterprise policy must contain both Japan regional VNets")

    policy_reader = indexed[("azurerm_role_assignment", "power_platform_policy_reader", None)]
    if policy_reader["role_definition_name"] != "Reader":
        fail("deployment administrator must have Reader access to the enterprise policy")

    destructive_actions = [
        change["address"]
        for change in plan["resource_changes"]
        if "delete" in change["change"]["actions"]
    ]
    if destructive_actions:
        fail(f"foundation plan contains destructive actions: {destructive_actions}")

    print("Foundation private-ingress plan validation passed")


if __name__ == "__main__":
    main()
