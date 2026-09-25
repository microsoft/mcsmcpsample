import asyncio
from typing import Protocol

import jwt
from jwt import PyJWK, PyJWKClient, PyJWTError
from mcp.server.auth.provider import AccessToken


class SigningKeyProvider(Protocol):
    def get_signing_key_from_jwt(self, token: str) -> PyJWK: ...


class EntraTokenVerifier:
    def __init__(
        self,
        *,
        tenant_id: str,
        audience: str,
        required_scope: str,
        signing_key_provider: SigningKeyProvider | None = None,
    ) -> None:
        self._tenant_id = tenant_id
        self._audience = audience
        self._required_scope = required_scope
        self._issuer = f"https://login.microsoftonline.com/{tenant_id}/v2.0"
        self._signing_key_provider = signing_key_provider or PyJWKClient(
            f"https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys",
            cache_keys=True,
        )

    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            signing_key = await asyncio.to_thread(
                self._signing_key_provider.get_signing_key_from_jwt, token
            )
            claims = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                audience=self._audience,
                issuer=self._issuer,
                options={"require": ["aud", "exp", "iss", "oid", "scp", "tid"]},
            )
        except (PyJWTError, TypeError, ValueError):
            return None

        oid = claims.get("oid")
        tenant_id = claims.get("tid")
        scope_claim = claims.get("scp")
        if not isinstance(oid, str) or not oid:
            return None
        if not isinstance(tenant_id, str) or tenant_id.lower() != self._tenant_id.lower():
            return None
        if not isinstance(scope_claim, str):
            return None

        scopes = scope_claim.split()
        if self._required_scope not in scopes:
            return None

        client_id = claims.get("azp", claims.get("appid", ""))
        if not isinstance(client_id, str):
            return None

        return AccessToken(
            token=token,
            client_id=client_id,
            scopes=scopes,
            resource=self._audience,
            claims=claims,
        )
