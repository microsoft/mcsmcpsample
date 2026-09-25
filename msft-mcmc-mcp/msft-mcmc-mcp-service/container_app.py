import os

from mcp.server.auth.settings import AuthSettings

from mcmc_mcp.config import ServerSettings
from mcmc_mcp.entra import EntraTokenVerifier
from mcmc_mcp.server import create_application

settings = ServerSettings.from_mapping(os.environ)
if settings.entra is None:
    app = create_application(settings)
else:
    entra = settings.entra
    app = create_application(
        settings,
        token_verifier=EntraTokenVerifier(
            tenant_id=entra.tenant_id,
            audience=entra.audience,
            required_scope=entra.required_scope,
        ),
        auth_settings=AuthSettings.model_validate(
            {
                "issuer_url": f"https://login.microsoftonline.com/{entra.tenant_id}/v2.0",
                "resource_server_url": entra.resource_server_url,
                "required_scopes": [entra.required_scope],
                "validate_token_resource": False,
            }
        ),
        oid_access=entra.oid_access,
    )
