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
        settings = ServerSettings.from_mapping({"AUTH_MODE": "entra"})

        with self.assertRaisesRegex(ConfigurationError, "token verifier and auth settings"):
            create_application(settings)


if __name__ == "__main__":
    unittest.main()
