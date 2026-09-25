from collections.abc import Mapping

from mcp.server import MCPServer
from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.provider import TokenVerifier
from mcp.server.auth.settings import AuthSettings
from mcp.server.transport_security import TransportSecuritySettings
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from mcmc_mcp.config import AuthMode, ConfigurationError, ServerSettings
from mcmc_mcp.customers import get_customer, list_customers
from mcmc_mcp.observability import CorrelationLoggingMiddleware
from mcmc_mcp.tool_models import CustomerListResult, CustomerLookupResult


def create_application(
    settings: ServerSettings,
    *,
    token_verifier: TokenVerifier | None = None,
    auth_settings: AuthSettings | None = None,
    oid_access: Mapping[str, frozenset[str]] | None = None,
) -> CorrelationLoggingMiddleware:
    if settings.auth_mode is AuthMode.ENTRA:
        if token_verifier is None or auth_settings is None:
            raise ConfigurationError("entra mode requires a token verifier and auth settings")
    elif token_verifier is not None or auth_settings is not None:
        raise ConfigurationError("trusted mode must not configure native OAuth validation")

    mcp = MCPServer(
        "msft-mcmc-mcp",
        title="Microsoft Copilot Studio MCP demo",
        description="Provides deterministic access to fictitious customer records.",
        version="0.1.0",
        token_verifier=token_verifier,
        auth=auth_settings,
    )

    def allowed_customer_numbers() -> frozenset[str] | None:
        if settings.auth_mode is AuthMode.TRUSTED:
            return None

        token = get_access_token()
        oid = (token.claims or {}).get("oid") if token is not None else None
        if not isinstance(oid, str):
            return frozenset()
        return (oid_access or {}).get(oid, frozenset())

    @mcp.tool(name="list_accessible_customers")
    def list_accessible_customers() -> CustomerListResult:
        """List the fictitious customer records accessible to the current caller."""
        return CustomerListResult.from_customer_list(list_customers(allowed_customer_numbers()))

    @mcp.tool(name="get_accessible_customer")
    def get_accessible_customer(customer_number: str) -> CustomerLookupResult:
        """Get an accessible fictitious customer by customer number, or no result."""
        return CustomerLookupResult.from_customer(
            get_customer(customer_number, allowed_customer_numbers())
        )

    async def health(_: Request) -> Response:
        return JSONResponse({"status": "ok"})

    mcp.custom_route("/health", methods=["GET"])(health)

    return CorrelationLoggingMiddleware(
        mcp.streamable_http_app(
            streamable_http_path="/mcp",
            json_response=True,
            stateless_http=True,
            transport_security=TransportSecuritySettings(
                allowed_hosts=list(settings.allowed_hosts)
            ),
        )
    )
