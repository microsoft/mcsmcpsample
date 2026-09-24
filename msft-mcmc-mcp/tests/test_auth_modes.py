import unittest

from mcp.server.auth.provider import AccessToken
from mcp.server.auth.settings import AuthSettings
from starlette.testclient import TestClient

from mcmc_mcp.config import ServerSettings
from mcmc_mcp.server import create_application

RESOURCE = "https://mcp.example.com/mcp"


class FakeTokenVerifier:
    async def verify_token(self, token: str) -> AccessToken | None:
        claims = {
            "james-token": {"oid": "james-oid"},
            "missing-oid-token": {},
        }.get(token)
        if claims is None:
            return None
        return AccessToken(
            token=token,
            client_id="test-client",
            scopes=["customers.read"],
            resource=RESOURCE,
            claims=claims,
        )


class EntraModeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        app = create_application(
            ServerSettings.from_mapping({"AUTH_MODE": "entra", "MCP_ALLOWED_HOSTS": "testserver"}),
            token_verifier=FakeTokenVerifier(),
            auth_settings=AuthSettings(
                issuer_url="https://login.example.com/tenant/v2.0",
                resource_server_url=RESOURCE,
                required_scopes=["customers.read"],
                validate_token_resource=True,
            ),
            oid_access={"james-oid": frozenset({"CUST-1001", "CUST-1002"})},
        )
        cls.client_context = TestClient(app)
        cls.client = cls.client_context.__enter__()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client_context.__exit__(None, None, None)

    def test_unauthenticated_request_is_rejected(self) -> None:
        response = self._list_customers()

        self.assertEqual(response.status_code, 401)

    def test_verified_oid_selects_only_mapped_customers(self) -> None:
        response = self._list_customers("james-token")

        self.assertEqual(response.status_code, 200)
        customer_numbers = {
            customer["customer_number"]
            for customer in response.json()["result"]["structuredContent"]["customers"]
        }
        self.assertEqual(customer_numbers, {"CUST-1001", "CUST-1002"})

    def test_missing_oid_fails_closed(self) -> None:
        response = self._list_customers("missing-oid-token")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["result"]["structuredContent"]["customers"], [])

    def _list_customers(self, token: str | None = None):
        headers = {
            "accept": "application/json, text/event-stream",
            "content-type": "application/json",
        }
        if token:
            headers["authorization"] = f"Bearer {token}"
        return self.client.post(
            "/mcp",
            headers=headers,
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {"name": "list_accessible_customers", "arguments": {}},
            },
        )


if __name__ == "__main__":
    unittest.main()
