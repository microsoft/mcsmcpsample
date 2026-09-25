import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from typing import Any
from unittest.mock import Mock, patch

import jwt

from mcmc_mcp.cli import (
    CliError,
    CliSettings,
    acquire_access_token,
    create_parser,
    execute_cli,
    exercise_mcp,
    main,
)


class FakeDeviceCodeClient:
    def __init__(self, result: dict[str, Any], flow: dict[str, Any] | None = None) -> None:
        self.result = result
        self.flow = flow or {"user_code": "device-code", "message": "Sign in message"}

    def initiate_device_flow(self, scopes: list[str]) -> dict[str, Any]:
        return self.flow

    def acquire_token_by_device_flow(self, flow: dict[str, Any]) -> dict[str, Any]:
        return self.result


class FakeMcpClient:
    def __init__(self, customers: list[dict[str, str]], include_tools: bool = True) -> None:
        self.customers = customers
        self.include_tools = include_tools
        self.calls: list[tuple[str, dict[str, Any]]] = []

    async def list_tools(self) -> Any:
        names = ["list_accessible_customers", "get_accessible_customer"]
        if not self.include_tools:
            names.pop()
        return SimpleNamespace(tools=[SimpleNamespace(name=name) for name in names])

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Any:
        self.calls.append((name, arguments))
        if name == "list_accessible_customers":
            structured_content = {"customers": self.customers}
        else:
            number = arguments["customer_number"]
            structured_content = {
                "customer": next(
                    (
                        customer
                        for customer in self.customers
                        if customer["customer_number"] == number
                    ),
                    None,
                )
            }
        return SimpleNamespace(is_error=False, structured_content=structured_content)


class CliConfigurationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.env_file = Path(self.temporary_directory.name) / ".env"
        self.secret = "sentinel-password-must-not-escape"
        self.env_file.write_text(
            "\n".join(
                (
                    "MCMC_ENTRA_TENANT_ID=tenant-id",
                    "MCMC_ENTRA_CLI_CLIENT_ID=client-id",
                    "MCMC_ENTRA_SCOPE=api://example/access_as_user",
                    "MCMC_JAMES_UPN=james@example.test",
                    "MCMC_JAMES_OID=james-oid",
                    f'MCMC_JAMES_INITIAL_PASSWORD="{self.secret}"',
                )
            ),
            encoding="utf-8",
        )

    def test_selected_user_configuration_excludes_password(self) -> None:
        settings = CliSettings.from_env_file(
            self.env_file,
            "james",
            "https://mcp.example.test/mcp",
        )

        self.assertEqual(settings.user.principal_name, "james@example.test")
        self.assertEqual(settings.user.object_id, "james-oid")
        self.assertNotIn(self.secret, repr(settings))
        self.assertFalse(hasattr(settings.user, "password"))

    def test_environment_can_supply_allowlisted_values(self) -> None:
        settings = CliSettings.from_env_file(
            Path("missing.env"),
            "jane",
            "https://mcp.example.test/mcp",
            {
                "MCMC_ENTRA_TENANT_ID": "tenant-id",
                "MCMC_ENTRA_CLI_CLIENT_ID": "client-id",
                "MCMC_ENTRA_SCOPE": "scope",
                "MCMC_JANE_UPN": "jane@example.test",
                "MCMC_JANE_OID": "jane-oid",
            },
        )

        self.assertEqual(settings.user.name, "Jane")

    def test_missing_selected_user_configuration_is_sanitized(self) -> None:
        with self.assertRaises(CliError) as context:
            CliSettings.from_env_file(self.env_file, "bill", "http://localhost/mcp")

        self.assertIn("MCMC_BILL_OID", str(context.exception))
        self.assertNotIn(self.secret, str(context.exception))

    def test_parser_rejects_unknown_user(self) -> None:
        parser = create_parser()

        with self.assertRaises(SystemExit):
            parser.parse_args(["--user", "unknown"])

    def test_parser_rejects_title_case_user(self) -> None:
        parser = create_parser()

        with self.assertRaises(SystemExit):
            parser.parse_args(["--user", "James"])

    def test_entry_point_reports_configuration_errors_without_secrets(self) -> None:
        with patch.dict(os.environ, {}, clear=True), patch("sys.stderr") as stderr:
            exit_code = main(["--user", "bill", "--env-file", str(self.env_file)])

        self.assertEqual(exit_code, 1)
        self.assertNotIn(self.secret, str(stderr.method_calls))


class DeviceCodeAuthenticationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = CliSettings.from_env_file(
            Path("unused.env"),
            "james",
            "https://mcp.example.test/mcp",
            {
                "MCMC_ENTRA_TENANT_ID": "tenant-id",
                "MCMC_ENTRA_CLI_CLIENT_ID": "client-id",
                "MCMC_ENTRA_SCOPE": "api://example/access_as_user",
                "MCMC_JAMES_UPN": "james@example.test",
                "MCMC_JAMES_OID": "james-oid",
            },
        )

    def test_device_flow_returns_token_for_selected_user(self) -> None:
        token = jwt.encode({"oid": "james-oid"}, key="", algorithm="none")
        client = FakeDeviceCodeClient({"access_token": token})
        factory = Mock(return_value=client)
        messages: list[str] = []

        result = acquire_access_token(
            self.settings,
            application_factory=factory,
            write=messages.append,
        )

        self.assertEqual(result, token)
        self.assertEqual(messages, ["Sign in message"])
        factory.assert_called_once_with(
            "client-id", authority="https://login.microsoftonline.com/tenant-id"
        )

    def test_wrong_user_token_is_rejected_without_token_exposure(self) -> None:
        token = jwt.encode({"oid": "jane-oid"}, key="", algorithm="none")

        with self.assertRaises(CliError) as context:
            acquire_access_token(
                self.settings,
                application_factory=Mock(
                    return_value=FakeDeviceCodeClient({"access_token": token})
                ),
                write=Mock(),
            )

        self.assertNotIn(token, str(context.exception))
        self.assertIn("does not match", str(context.exception))

    def test_refused_or_blocked_consent_is_sanitized(self) -> None:
        provider_detail = "provider-detail-must-not-escape"

        with self.assertRaises(CliError) as context:
            acquire_access_token(
                self.settings,
                application_factory=Mock(
                    return_value=FakeDeviceCodeClient(
                        {"error": "authorization_declined", "error_description": provider_detail}
                    )
                ),
                write=Mock(),
            )

        self.assertNotIn(provider_detail, str(context.exception))

    def test_device_flow_start_failure_is_sanitized(self) -> None:
        with self.assertRaises(CliError) as context:
            acquire_access_token(
                self.settings,
                application_factory=Mock(
                    return_value=FakeDeviceCodeClient(
                        {}, {"error": "authorization_pending", "secret": "provider-secret"}
                    )
                ),
                write=Mock(),
            )

        self.assertNotIn("provider-secret", str(context.exception))

    def test_malformed_access_token_is_rejected_without_exposure(self) -> None:
        token = "malformed-access-token"

        with self.assertRaises(CliError) as context:
            acquire_access_token(
                self.settings,
                application_factory=Mock(
                    return_value=FakeDeviceCodeClient({"access_token": token})
                ),
                write=Mock(),
            )

        self.assertNotIn(token, str(context.exception))


class McpInvocationTests(unittest.IsolatedAsyncioTestCase):
    @staticmethod
    def _customer(number: str) -> dict[str, str]:
        return {
            "customer_number": number,
            "name": f"Customer {number}",
            "phone_number": "+1-555-0100",
            "email": f"{number.lower()}@example.test",
        }

    async def test_discovery_and_customer_tools_return_authorized_records(self) -> None:
        customers = [self._customer("CUST-1001"), self._customer("CUST-1002")]
        client = FakeMcpClient(customers)

        result = await exercise_mcp(client, "James")

        self.assertEqual(result["customers"], customers)
        self.assertEqual(
            [name for name, _ in client.calls],
            [
                "list_accessible_customers",
                "get_accessible_customer",
                "get_accessible_customer",
            ],
        )

    async def test_zero_access_user_exercises_lookup_without_disclosure(self) -> None:
        client = FakeMcpClient([])

        result = await exercise_mcp(client, "Bill")

        self.assertEqual(result["customers"], [])
        self.assertEqual(
            client.calls[-1],
            ("get_accessible_customer", {"customer_number": "CUST-1001"}),
        )

    async def test_missing_required_tool_is_sanitized(self) -> None:
        with self.assertRaises(CliError) as context:
            await exercise_mcp(FakeMcpClient([], include_tools=False), "Bill")

        self.assertIn("required customer tools", str(context.exception))


class CliExecutionTests(unittest.TestCase):
    def test_transport_failure_is_sanitized_and_token_is_not_rendered(self) -> None:
        token = "access-token-must-not-escape"
        settings = Mock()
        output: list[str] = []

        async def failed_invoke(settings: Any, access_token: str) -> dict[str, Any]:
            raise RuntimeError(f"transport failed with {access_token}")

        with self.assertRaises(CliError) as context:
            execute_cli(
                settings,
                authenticate=Mock(return_value=token),
                invoke=failed_invoke,
                write=output.append,
            )

        self.assertNotIn(token, str(context.exception))
        self.assertEqual(output, [])


if __name__ == "__main__":
    unittest.main()
