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
            "jane-token": {"oid": "jane-oid"},
            "bill-token": {"oid": "bill-oid"},
            "unmapped-token": {"oid": "unmapped-oid"},
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
            ServerSettings.from_mapping(
                {
                    "AUTH_MODE": "entra",
                    "MCP_ALLOWED_HOSTS": "testserver",
                    "ENTRA_TENANT_ID": "tenant-id",
                    "ENTRA_AUDIENCE": "api://example.test/mcmc-mcp",
                    "ENTRA_REQUIRED_SCOPE": "customers.read",
                    "MCP_RESOURCE_SERVER_URL": RESOURCE,
                    "ENTRA_OID_ACCESS_JSON": '{"james-oid":["CUST-1001","CUST-1002"]}',
                }
            ),
            token_verifier=FakeTokenVerifier(),
            auth_settings=AuthSettings(
                issuer_url="https://login.example.com/tenant/v2.0",
                resource_server_url=RESOURCE,
                required_scopes=["customers.read"],
                validate_token_resource=True,
            ),
            oid_access={
                "james-oid": frozenset({"CUST-1001", "CUST-1002"}),
                "jane-oid": frozenset({"CUST-1003", "CUST-1004"}),
                "bill-oid": frozenset(),
            },
        )
        cls.client_context = TestClient(app)
        cls.client = cls.client_context.__enter__()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client_context.__exit__(None, None, None)

    def test_unauthenticated_request_is_rejected(self) -> None:
        response = self._list_customers()

        self.assertEqual(response.status_code, 401)

    def test_verified_oids_select_only_mapped_customers(self) -> None:
        cases = {
            "james-token": {"CUST-1001", "CUST-1002"},
            "jane-token": {"CUST-1003", "CUST-1004"},
            "bill-token": set(),
            "unmapped-token": set(),
        }
        for token, expected in cases.items():
            with self.subTest(token=token):
                response = self._list_customers(token)

                self.assertEqual(response.status_code, 200)
                customer_numbers = {
                    customer["customer_number"]
                    for customer in response.json()["result"]["structuredContent"]["customers"]
                }
                self.assertEqual(customer_numbers, expected)

    def test_missing_oid_fails_closed(self) -> None:
        response = self._list_customers("missing-oid-token")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["result"]["structuredContent"]["customers"], [])

    def test_direct_lookup_does_not_reveal_inaccessible_customers(self) -> None:
        cases = (
            ("james-token", "CUST-1001", True),
            ("james-token", "CUST-1003", False),
            ("jane-token", "CUST-1003", True),
            ("jane-token", "CUST-1001", False),
            ("bill-token", "CUST-1001", False),
            ("unmapped-token", "CUST-9999", False),
        )
        for token, customer_number, expected_found in cases:
            with self.subTest(token=token, customer_number=customer_number):
                response = self._get_customer(token, customer_number)

                self.assertEqual(response.status_code, 200)
                customer = response.json()["result"]["structuredContent"]["customer"]
                self.assertEqual(customer is not None, expected_found)

    def _list_customers(self, token: str | None = None):
        return self._call_tool(token, "list_accessible_customers", {})

    def _get_customer(self, token: str, customer_number: str):
        return self._call_tool(
            token,
            "get_accessible_customer",
            {"customer_number": customer_number},
        )

    def _call_tool(self, token: str | None, name: str, arguments: dict[str, str]):
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
                "params": {"name": name, "arguments": arguments},
            },
        )


if __name__ == "__main__":
    unittest.main()
