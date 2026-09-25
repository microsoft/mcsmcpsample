import socket
import threading
import time
import unittest

import uvicorn
from mcp.server.auth.provider import AccessToken
from mcp.server.auth.settings import AuthSettings

from mcmc_mcp.cli import CliSettings, DemoUser, invoke_mcp
from mcmc_mcp.config import ServerSettings
from mcmc_mcp.server import create_application


class FakeTokenVerifier:
    async def verify_token(self, token: str) -> AccessToken | None:
        oid = {
            "james-token": "james-oid",
            "jane-token": "jane-oid",
            "bill-token": "bill-oid",
        }.get(token)
        if oid is None:
            return None
        return AccessToken(
            token=token,
            client_id="test-client",
            scopes=["customers.read"],
            claims={"oid": oid},
        )


class CliLocalServerTests(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            cls.port = listener.getsockname()[1]
        resource_url = f"http://127.0.0.1:{cls.port}/mcp"
        app = create_application(
            ServerSettings.from_mapping(
                {
                    "AUTH_MODE": "entra",
                    "MCP_ALLOWED_HOSTS": "127.0.0.1:*",
                    "ENTRA_TENANT_ID": "tenant-id",
                    "ENTRA_AUDIENCE": "api://example.test/mcmc-mcp",
                    "ENTRA_REQUIRED_SCOPE": "customers.read",
                    "MCP_RESOURCE_SERVER_URL": resource_url,
                    "ENTRA_OID_ACCESS_JSON": "{}",
                }
            ),
            token_verifier=FakeTokenVerifier(),
            auth_settings=AuthSettings(
                issuer_url="https://login.example.test/tenant/v2.0",
                resource_server_url=resource_url,
                required_scopes=["customers.read"],
                validate_token_resource=False,
            ),
            oid_access={
                "james-oid": frozenset({"CUST-1001", "CUST-1002"}),
                "jane-oid": frozenset({"CUST-1003", "CUST-1004"}),
                "bill-oid": frozenset(),
            },
        )
        cls.server = uvicorn.Server(
            uvicorn.Config(app, host="127.0.0.1", port=cls.port, log_level="critical")
        )
        cls.server_thread = threading.Thread(target=cls.server.run, daemon=True)
        cls.server_thread.start()
        for _ in range(1000):
            if cls.server.started:
                break
            time.sleep(0.01)
        if not cls.server.started:
            raise RuntimeError("Local MCP test server failed to start")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.should_exit = True
        cls.server_thread.join(timeout=5)

    async def test_each_demo_user_receives_expected_access(self) -> None:
        cases = {
            "James": ("james-token", {"CUST-1001", "CUST-1002"}),
            "Jane": ("jane-token", {"CUST-1003", "CUST-1004"}),
            "Bill": ("bill-token", set()),
        }
        for user_name, (token, expected) in cases.items():
            with self.subTest(user=user_name):
                settings = CliSettings(
                    tenant_id="tenant-id",
                    client_id="client-id",
                    scope="customers.read",
                    server_url=f"http://127.0.0.1:{self.port}/mcp",
                    user=DemoUser(
                        name=user_name,
                        principal_name=f"{user_name.lower()}@example.test",
                        object_id=f"{user_name.lower()}-oid",
                    ),
                )

                result = await invoke_mcp(settings, token)

                self.assertEqual(
                    {customer["customer_number"] for customer in result["customers"]},
                    expected,
                )


if __name__ == "__main__":
    unittest.main()
