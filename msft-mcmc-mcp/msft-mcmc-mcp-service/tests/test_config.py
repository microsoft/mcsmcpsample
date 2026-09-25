import unittest

from mcmc_mcp.config import AuthMode, ConfigurationError, ServerSettings
from mcmc_mcp.server import create_application


class ServerSettingsTests(unittest.TestCase):
    def test_missing_auth_mode_is_rejected(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "AUTH_MODE is required"):
            ServerSettings.from_mapping({})

    def test_unsupported_auth_mode_is_rejected(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "entra, trusted"):
            ServerSettings.from_mapping({"AUTH_MODE": "other"})

    def test_trusted_mode_and_hosts_are_parsed(self) -> None:
        settings = ServerSettings.from_mapping(
            {"AUTH_MODE": "trusted", "MCP_ALLOWED_HOSTS": "one.example,two.example:*"}
        )

        self.assertEqual(settings.auth_mode, AuthMode.TRUSTED)
        self.assertEqual(settings.allowed_hosts, ("one.example", "two.example:*"))

    def test_entra_mode_requires_native_oauth_components(self) -> None:
        settings = ServerSettings.from_mapping(self._entra_values())

        with self.assertRaisesRegex(ConfigurationError, "token verifier and auth settings"):
            create_application(settings)

    def test_entra_mode_parses_native_oauth_configuration(self) -> None:
        settings = ServerSettings.from_mapping(self._entra_values())

        self.assertIsNotNone(settings.entra)
        assert settings.entra is not None
        self.assertEqual(settings.entra.required_scope, "access_as_user")
        self.assertEqual(
            settings.entra.oid_access,
            {"james-oid": frozenset({"CUST-1001", "CUST-1002"})},
        )

    def test_entra_mode_rejects_missing_or_invalid_configuration(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "ENTRA_AUDIENCE"):
            ServerSettings.from_mapping({"AUTH_MODE": "entra"})

        values = self._entra_values()
        values["ENTRA_OID_ACCESS_JSON"] = "[]"
        with self.assertRaisesRegex(ConfigurationError, "JSON object"):
            ServerSettings.from_mapping(values)

    @staticmethod
    def _entra_values() -> dict[str, str]:
        return {
            "AUTH_MODE": "entra",
            "ENTRA_TENANT_ID": "tenant-id",
            "ENTRA_AUDIENCE": "api://example.test/mcmc-mcp",
            "ENTRA_REQUIRED_SCOPE": "access_as_user",
            "MCP_RESOURCE_SERVER_URL": "https://mcp.example.test/mcp",
            "ENTRA_OID_ACCESS_JSON": '{"james-oid":["CUST-1001","CUST-1002"]}',
        }


if __name__ == "__main__":
    unittest.main()
