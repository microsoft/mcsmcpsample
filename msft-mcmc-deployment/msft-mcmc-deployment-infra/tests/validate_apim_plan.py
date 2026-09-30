import json
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_apim_plan.py PLAN_JSON")

    plan = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    resources = plan["planned_values"]["root_module"]["resources"]
    legacy_resources = {
        (resource["type"], resource["name"])
        for resource in resources
        if resource["name"] == "trusted_mcp"
    }
    if legacy_resources:
        fail("legacy subscription-key MCP resources must not remain in the plan")

    policy_sets = {
        policy_name: {
            resource.get("index"): resource["values"]["xml_content"]
            for resource in resources
            if resource["type"] == "azurerm_api_management_api_policy"
            and resource["name"] == policy_name
        }
        for policy_name in ("mcp", "private_mcp")
    }
    for policy_name, policies in policy_sets.items():
        if set(policies) != {"native", "gateway"}:
            fail(f"expected native and gateway policies in {policy_name}")

        for route, policy in policies.items():
            ElementTree.fromstring(policy)
            required = (
                'buffer-request-body="false"',
                'buffer-response="false"',
                'timeout="300"',
                "rate-limit-by-key",
                "x-correlation-id",
                "1048576",
            )
            if any(value not in policy for value in required):
                fail(f"{policy_name} {route} policy is missing a shared gateway control")
            if policy.count('name="x-correlation-id"') < 6:
                fail(f"{policy_name} {route} policy does not correlate all gateway-generated responses")
            if any(value not in policy for value in ("RateLimitExceeded", 'code="429"')):
                fail(f"{policy_name} {route} policy does not preserve throttling semantics")
            if "Authorization" in policy and route == "native":
                fail(f"{policy_name} native policy must pass Authorization through unchanged")

        gateway = policies["gateway"]
        required_gateway = (
            "validate-jwt",
            'require-scheme="Bearer"',
            'require-expiration-time="true"',
            'output-token-variable-name="validatedJwt"',
            '<claim name="tid"',
            '<claim name="scp"',
            'GetValueOrDefault(&quot;groups&quot;',
            'code="403"',
            'reason="Forbidden"',
            '<set-header name="Authorization" exists-action="delete"',
        )
        if any(value not in gateway for value in required_gateway):
            fail(f"{policy_name} gateway policy is missing an authentication control")

    public_gateway = policy_sets["mcp"]["gateway"]
    private_gateway = policy_sets["private_mcp"]["gateway"]
    private_native = policy_sets["private_mcp"]["native"]
    if "-private.azure-api.net" in public_gateway:
        fail("public gateway policy must not advertise private APIM metadata")
    if "-private.azure-api.net" not in private_gateway:
        fail("private gateway policy must advertise private APIM metadata")
    if (
        'context.Response.StatusCode == 401' not in private_native
        or 'set-header name="WWW-Authenticate" exists-action="override"' not in private_native
        or "-private.azure-api.net/.well-known/oauth-protected-resource/native/mcp" not in private_native
    ):
        fail("private native policy must rewrite backend challenges to private metadata")

    if any(secret in json.dumps(plan).lower() for secret in ("access_token", "client_secret")):
        fail("plan contains a prohibited secret field")

    print("APIM rendered policy validation passed")


if __name__ == "__main__":
    main()