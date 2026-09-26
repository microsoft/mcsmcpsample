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

    policies = {
        resource.get("index"): resource["values"]["xml_content"]
        for resource in resources
        if resource["type"] == "azurerm_api_management_api_policy"
        and resource["name"] == "mcp"
    }
    if set(policies) != {"native", "gateway"}:
        fail("expected native and gateway MCP policies")

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
            fail(f"{route} policy is missing a shared gateway control")
        if policy.count('name="x-correlation-id"') < 6:
            fail(f"{route} policy does not correlate all gateway-generated responses")
        if any(value not in policy for value in ("RateLimitExceeded", 'code="429"')):
            fail(f"{route} policy does not preserve throttling semantics")
        if "Authorization" in policy and route == "native":
            fail("native policy must pass the Authorization header through unchanged")

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
        fail("gateway policy is missing an authentication control")

    if any(secret in json.dumps(plan).lower() for secret in ("access_token", "client_secret")):
        fail("plan contains a prohibited secret field")

    print("APIM rendered policy validation passed")


if __name__ == "__main__":
    main()