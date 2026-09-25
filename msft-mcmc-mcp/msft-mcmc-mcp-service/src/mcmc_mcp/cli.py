import argparse
import asyncio
import json
import os
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, NoReturn, Protocol

import httpx2
import jwt
from mcp import Client
from mcp.client.streamable_http import streamable_http_client
from msal import PublicClientApplication


class CliError(RuntimeError):
    pass


USER_DISPLAY_NAMES = {
    "james": "James",
    "jane": "Jane",
    "bill": "Bill",
}


class DeviceCodeClient(Protocol):
    def initiate_device_flow(self, scopes: list[str]) -> dict[str, Any]: ...

    def acquire_token_by_device_flow(self, flow: dict[str, Any]) -> dict[str, Any]: ...


class DeviceCodeClientFactory(Protocol):
    def __call__(self, client_id: str, *, authority: str) -> DeviceCodeClient: ...


class McpClient(Protocol):
    async def list_tools(self) -> Any: ...

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Any: ...


@dataclass(frozen=True, slots=True)
class DemoUser:
    name: str
    principal_name: str
    object_id: str


@dataclass(frozen=True, slots=True)
class CliSettings:
    tenant_id: str
    client_id: str
    scope: str
    server_url: str
    user: DemoUser

    @classmethod
    def from_env_file(
        cls,
        path: Path,
        user_name: str,
        server_url: str,
        environ: Mapping[str, str] | None = None,
    ) -> "CliSettings":
        prefix = user_name.upper()
        display_name = USER_DISPLAY_NAMES[user_name]
        names = {
            "MCMC_ENTRA_TENANT_ID",
            "MCMC_ENTRA_CLI_CLIENT_ID",
            "MCMC_ENTRA_SCOPE",
            f"MCMC_{prefix}_UPN",
            f"MCMC_{prefix}_OID",
        }
        environment_values = {key: value for key, value in (environ or {}).items() if key in names}
        values = (
            {}
            if all(environment_values.get(name, "").strip() for name in names)
            else _load_allowed_values(path, names)
        )
        values.update(environment_values)

        missing = sorted(name for name in names if not values.get(name, "").strip())
        if missing:
            raise CliError(f"CLI configuration is missing: {', '.join(missing)}")

        return cls(
            tenant_id=values["MCMC_ENTRA_TENANT_ID"].strip(),
            client_id=values["MCMC_ENTRA_CLI_CLIENT_ID"].strip(),
            scope=values["MCMC_ENTRA_SCOPE"].strip(),
            server_url=server_url,
            user=DemoUser(
                name=display_name,
                principal_name=values[f"MCMC_{prefix}_UPN"].strip(),
                object_id=values[f"MCMC_{prefix}_OID"].strip(),
            ),
        )


def _load_allowed_values(path: Path, allowed_names: set[str]) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise CliError(f"Unable to read CLI configuration from {path}") from error

    values: dict[str, str] = {}
    for line in lines:
        name, separator, value = line.partition("=")
        if separator and name in allowed_names:
            values[name] = value.strip().strip('"').strip("'")
    return values


def acquire_access_token(
    settings: CliSettings,
    *,
    application_factory: DeviceCodeClientFactory = PublicClientApplication,
    write: Any = print,
) -> str:
    application = application_factory(
        settings.client_id,
        authority=f"https://login.microsoftonline.com/{settings.tenant_id}",
    )
    flow = application.initiate_device_flow(scopes=[settings.scope])
    if not isinstance(flow.get("user_code"), str):
        raise CliError("Unable to start device-code authentication")

    message = flow.get("message")
    if isinstance(message, str):
        write(message)

    result = application.acquire_token_by_device_flow(flow)
    access_token = result.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise CliError("Authentication failed or consent was not granted")

    try:
        claims = jwt.decode(access_token, options={"verify_signature": False})
    except jwt.PyJWTError as error:
        raise CliError("Authentication returned an invalid access token") from error
    if claims.get("oid") != settings.user.object_id:
        raise CliError("The signed-in account does not match the selected user")
    return access_token


def _structured_tool_result(result: Any) -> dict[str, Any]:
    if result.is_error or not isinstance(result.structured_content, dict):
        raise CliError("The MCP server returned an invalid tool result")
    return result.structured_content


async def exercise_mcp(client: McpClient, user_name: str) -> dict[str, Any]:
    listed = await client.list_tools()
    tool_names = {tool.name for tool in listed.tools}
    required_tools = {"list_accessible_customers", "get_accessible_customer"}
    if not required_tools.issubset(tool_names):
        raise CliError("The MCP server does not expose the required customer tools")

    list_result = _structured_tool_result(await client.call_tool("list_accessible_customers", {}))
    customers = list_result.get("customers")
    if not isinstance(customers, list) or not all(
        isinstance(customer, dict) for customer in customers
    ):
        raise CliError("The MCP server returned an invalid customer list")

    lookup_numbers = [customer.get("customer_number") for customer in customers]
    if not lookup_numbers:
        lookup_numbers = ["CUST-1001"]
    for customer_number in lookup_numbers:
        if not isinstance(customer_number, str):
            raise CliError("The MCP server returned an invalid customer record")
        lookup = _structured_tool_result(
            await client.call_tool("get_accessible_customer", {"customer_number": customer_number})
        )
        returned_customer = lookup.get("customer")
        if returned_customer is not None and returned_customer not in customers:
            raise CliError("The MCP server returned an inconsistent customer lookup")

    return {
        "user": user_name,
        "tools": sorted(required_tools),
        "customers": customers,
    }


async def invoke_mcp(settings: CliSettings, access_token: str) -> dict[str, Any]:
    timeout = httpx2.Timeout(30.0, read=300.0)
    async with httpx2.AsyncClient(
        headers={"Authorization": f"Bearer {access_token}"}, timeout=timeout
    ) as http_client:
        transport = streamable_http_client(settings.server_url, http_client=http_client)
        async with Client(transport) as client:
            return await exercise_mcp(client, settings.user.name)


def execute_cli(
    settings: CliSettings,
    *,
    authenticate: Any = acquire_access_token,
    invoke: Any = invoke_mcp,
    write: Any = print,
) -> None:
    access_token = authenticate(settings, write=write)
    try:
        result = asyncio.run(invoke(settings, access_token))
    except CliError:
        raise
    except Exception as error:
        raise CliError("MCP request failed") from error
    write(json.dumps(result, indent=2, sort_keys=True))


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="mcp", description="Exercise the MCMC MCP server")
    parser.add_argument("--user", required=True, choices=tuple(USER_DISPLAY_NAMES))
    parser.add_argument(
        "--url",
        default=os.environ.get("MCMC_MCP_URL", "http://127.0.0.1:8000/mcp"),
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(os.environ.get("MCMC_ENV_FILE", ".env")),
        help=argparse.SUPPRESS,
    )
    return parser


def _fail(message: str) -> NoReturn:
    raise SystemExit(message)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = create_parser().parse_args(argv)
    try:
        settings = CliSettings.from_env_file(
            arguments.env_file, arguments.user, arguments.url, os.environ
        )
        execute_cli(settings)
    except CliError as error:
        print(f"mcp: {error}", file=sys.stderr)
        return 1
    return 0
