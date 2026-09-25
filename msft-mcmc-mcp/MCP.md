# MCP

The MCP module owns the configurable Model Context Protocol server, its OCI image definition, its demonstration CLI, and application tests.

The module coordinate is `msft-mcmc-mcp`, derived from the repository organization, product, and module identity files.

## Runtime and SDK

The module targets Python 3.12 and runs as a standalone ASGI application under Uvicorn. It uses the official MCP Python SDK v2 for Streamable HTTP protocol handling and `uv` for dependency and environment management.

Production dependencies are declared in `pyproject.toml` and pinned in `uv.lock`. Development dependencies and tool configuration are defined in `pyproject.toml`. Python packages resolve through the corporate `https://packagefeedproxy.microsoft.io/pypi/simple` feed in both the development container and service image.

Run formatting, linting, type checking, startup validation, and tests from the `msft-mcmc-mcp-service/` component directory.

## Structure

- `msft-mcmc-mcp-service/` is the `msft-mcmc-mcp-service` OPMC component and owns the deployable containerized service.
- `msft-mcmc-mcp-service/src/mcmc_mcp/` contains reusable application code.
- `msft-mcmc-mcp-service/tests/` contains unit and protocol tests.
- `msft-mcmc-mcp-service/container_app.py` creates the standalone ASGI application.
- `msft-mcmc-mcp-service/Dockerfile` creates the non-root Python 3.12 runtime image and exposes port `8000`.

## HTTP Application

The standalone ASGI entry point exposes stateless Streamable HTTP at `POST /mcp` and an unauthenticated `GET /health` endpoint. Uvicorn listens on port `8000`. The superseded SSE transport is not registered.

Every HTTP response includes `x-correlation-id`. A caller-supplied identifier is retained only when it contains 1-128 ASCII letters, digits, dots, underscores, or hyphens; otherwise the server generates a UUID. Completion logs contain only this identifier, method, route, status, and duration. Request headers, authorization values, customer payloads, and response bodies are not logged.

## Container Image

The image build uses the locked production dependency set and runs as unprivileged user `10001`. The ordered deployment layer derives the image tag from the root `version` file as `VERSION_MAJOR.VERSION_MINOR.VERSION_REVISION.VERSION_BUILD`. It replaces the revision with the current branch commit count and increments and persists the build number before invoking ACR Build through the current Microsoft Entra-authenticated Azure CLI session. Existing tags are rejected and the pushed manifest digest is reported.

The ACR artifact repository uses the fully qualified component name `msft-mcmc-mcp-service`. The current validated image is `mcmc677e8052.azurecr.io/msft-mcmc-mcp-service:0.0.3.5`, with digest `sha256:165930594cff15507b0ed3d885c554c115bd9a40d8bc0aa8587f5f9c4f472a2f`. The private trusted and Entra Container Apps run this same immutable digest.

## Authentication Modes

`AUTH_MODE` is required and accepts only `trusted` or `entra`. `MCP_ALLOWED_HOSTS` is a comma-separated DNS-rebinding allowlist and defaults to local development hosts.

In `trusted` mode, the application rejects native OAuth configuration and returns the complete fictitious catalog because APIM owns authentication and authorization. This mode must eventually be reachable only through APIM; private ingress enforcement is delivered by the deployment and APIM tickets.

In `entra` mode, startup requires the tenant ID, API audience, delegated scope, HTTPS resource-server URL, and a JSON access policy keyed by immutable Entra object identifier. The production verifier resolves the tenant's signing keys through its v2 JWKS endpoint and accepts only RS256 tokens with valid signature, issuer, audience, lifetime, tenant, delegated `scp`, and nonempty `oid` claims. The MCP SDK advertises protected-resource metadata at the HTTPS MCP URL while audience validation remains in the Entra verifier.

Tool authorization consumes only verifier-produced claims and maps `oid` to customer numbers. Missing, malformed, and unmapped identities receive an empty access set. Access tokens, authorization headers, and identity mappings are not logged.

## Customer Tools

`list_accessible_customers` takes no tool arguments and returns an object with a `customers` array. `get_accessible_customer` requires a `customer_number` string and returns an object whose `customer` field contains a customer or `null`. Each customer contains `customer_number`, `name`, `phone_number`, and `email` strings.

List results use stable catalog order. A lookup for an inaccessible or nonexistent number produces the same generic not-found outcome so the caller cannot distinguish the two cases.

The local demonstration access matrix is:

| User | Accessible customers |
| --- | --- |
| James | `CUST-1001`, `CUST-1002` |
| Jane | `CUST-1003`, `CUST-1004` |
| Bill | None |

These names identify disposable Entra test profiles created by Foundation. Their immutable object identifiers are supplied to the service as the access policy; display names and user principal names are never authorization subjects. In `trusted` mode, APIM owns authorization and the server exposes the complete fictitious catalog.

## Demonstration CLI

The component installs an `mcp` console command. Run `mcp --user james`, `mcp --user jane`, or `mcp --user bill` from the repository root so the command can read the gitignored root `.env`. User arguments are lowercase; structured output retains the display names James, Jane, and Bill. The endpoint defaults to `http://127.0.0.1:8000/mcp`; set `MCMC_MCP_URL` for another Streamable HTTP endpoint or `MCMC_ENV_FILE` for another environment-file location.

The CLI allowlists only the tenant ID, public-client ID, delegated scope, and selected user's principal name and object identifier. It does not load initial-password variables. MSAL initiates an interactive device-code flow through the nonsecret native public client and keeps its token cache in memory. The CLI displays Microsoft's device-code message, then rejects the token unless its `oid` matches the selected user's configured object identifier.

After authentication, the CLI sends the bearer token through the official MCP Python SDK Streamable HTTP client, discovers both customer tools, invokes the list tool and representative lookup calls, and prints structured JSON containing only the selected display name, discovered tool names, and authorized fictitious customers. Invalid users, configuration errors, wrong-user sign-in, refused or blocked consent, malformed tokens, authorization failures, missing tools, and transport errors return a nonzero exit without including provider details, passwords, access tokens, or customer data from failed requests.

The deployed private Entra app was validated through a temporary Azure management-plane exec shell in its running replica. Independent device-code runs returned only `CUST-1001` and `CUST-1002` for James, only `CUST-1003` and `CUST-1004` for Jane, and no customers for Bill. Missing and malformed bearer requests returned `401`, while both private backend names remained unavailable through public DNS. No public ingress or APIM route was added for this validation path.