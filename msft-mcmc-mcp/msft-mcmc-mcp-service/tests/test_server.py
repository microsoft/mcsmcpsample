import json
import logging
import unittest

from starlette.testclient import TestClient

from mcmc_mcp.config import ServerSettings
from mcmc_mcp.server import create_application

asgi_app = create_application(
    ServerSettings.from_mapping({"AUTH_MODE": "trusted", "MCP_ALLOWED_HOSTS": "testserver"})
)


class ServerHttpTests(unittest.TestCase):
    client_context: TestClient
    client: TestClient

    @classmethod
    def setUpClass(cls) -> None:
        cls.client_context = TestClient(asgi_app)
        cls.client = cls.client_context.__enter__()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client_context.__exit__(None, None, None)

    def test_health_returns_status_and_correlation_id(self) -> None:
        response = self.client.get("/health", headers={"x-correlation-id": "test-correlation-123"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        self.assertEqual(response.headers["x-correlation-id"], "test-correlation-123")

    def test_invalid_correlation_id_is_replaced_and_not_logged(self) -> None:
        with self.assertLogs("mcmc_mcp.requests", logging.INFO) as captured:
            response = self.client.get(
                "/health", headers={"x-correlation-id": "unsafe value with spaces"}
            )

        replacement = response.headers["x-correlation-id"]
        event = json.loads(captured.records[-1].message)
        self.assertNotEqual(replacement, "unsafe value with spaces")
        self.assertEqual(event["correlation_id"], replacement)
        self.assertNotIn("unsafe value with spaces", captured.records[-1].message)

    def test_mcp_initialize_uses_streamable_http_at_mcp(self) -> None:
        response = self._mcp_request(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "test-client", "version": "1.0.0"},
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["result"]["serverInfo"]["name"], "msft-mcmc-mcp")
        self.assertNotIn("mcp-session-id", response.headers)

    def test_protocol_discovers_and_invokes_customer_tools(self) -> None:
        listed = self._mcp_request("tools/list", {})

        self.assertEqual(listed.status_code, 200)
        self.assertEqual(
            {tool["name"] for tool in listed.json()["result"]["tools"]},
            {"list_accessible_customers", "get_accessible_customer"},
        )

        called = self._mcp_request(
            "tools/call",
            {"name": "get_accessible_customer", "arguments": {"customer_number": "CUST-1001"}},
        )
        self.assertEqual(called.status_code, 200)
        self.assertEqual(
            called.json()["result"]["structuredContent"]["customer"]["customer_number"],
            "CUST-1001",
        )

    def _mcp_request(self, method: str, params: dict[str, object]):
        return self.client.post(
            "/mcp",
            headers={
                "accept": "application/json, text/event-stream",
                "content-type": "application/json",
            },
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": method,
                "params": params,
            },
        )

    def test_legacy_sse_endpoint_is_absent(self) -> None:
        response = self.client.get("/sse")

        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
