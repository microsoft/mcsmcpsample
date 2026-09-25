import asyncio
import json
import time
import unittest
from collections.abc import Mapping
from typing import Any

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt import PyJWK

from mcmc_mcp.entra import EntraTokenVerifier

TENANT_ID = "11111111-2222-4333-8444-555555555555"
AUDIENCE = "api://example.test/mcmc-mcp"
SCOPE = "access_as_user"
ISSUER = f"https://login.microsoftonline.com/{TENANT_ID}/v2.0"


class StaticSigningKeyProvider:
    def __init__(self, key: PyJWK) -> None:
        self._key = key

    def get_signing_key_from_jwt(self, token: str) -> PyJWK:
        return self._key


class EntraTokenVerifierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        public_jwk: dict[str, Any] = json.loads(
            jwt.algorithms.RSAAlgorithm.to_jwk(cls.private_key.public_key())
        )
        public_jwk["kid"] = "test-key"
        cls.verifier = EntraTokenVerifier(
            tenant_id=TENANT_ID,
            audience=AUDIENCE,
            required_scope=SCOPE,
            signing_key_provider=StaticSigningKeyProvider(PyJWK.from_dict(public_jwk)),
        )

    def test_valid_token_returns_access_token(self) -> None:
        access_token = asyncio.run(self.verifier.verify_token(self._token()))

        self.assertIsNotNone(access_token)
        assert access_token is not None
        self.assertEqual(access_token.client_id, "cli-client-id")
        self.assertEqual(access_token.scopes, [SCOPE])
        self.assertEqual(access_token.claims["oid"], "james-oid")

    def test_invalid_token_claims_are_rejected(self) -> None:
        now = int(time.time())
        cases: tuple[tuple[str, Mapping[str, object]], ...] = (
            ("expired", {"exp": now - 1}),
            ("wrong audience", {"aud": "api://wrong"}),
            ("wrong issuer", {"iss": "https://issuer.invalid/v2.0"}),
            ("wrong tenant", {"tid": "00000000-0000-0000-0000-000000000000"}),
            ("missing scope", {"scp": "other_scope"}),
            ("missing oid", {"oid": None}),
        )

        for name, overrides in cases:
            with self.subTest(name=name):
                self.assertIsNone(
                    asyncio.run(self.verifier.verify_token(self._token(overrides)))
                )

    def test_malformed_token_is_rejected(self) -> None:
        self.assertIsNone(asyncio.run(self.verifier.verify_token("not-a-jwt")))

    @classmethod
    def _token(cls, overrides: Mapping[str, object] | None = None) -> str:
        now = int(time.time())
        claims: dict[str, object] = {
            "aud": AUDIENCE,
            "azp": "cli-client-id",
            "exp": now + 300,
            "iat": now,
            "iss": ISSUER,
            "nbf": now - 1,
            "oid": "james-oid",
            "scp": SCOPE,
            "tid": TENANT_ID,
        }
        claims.update(overrides or {})
        if claims.get("oid") is None:
            del claims["oid"]
        return jwt.encode(claims, cls.private_key, algorithm="RS256", headers={"kid": "test-key"})


if __name__ == "__main__":
    unittest.main()