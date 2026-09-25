# Copilot Studio MCP Demonstration

This project demonstrates Microsoft Copilot Studio connecting through Azure API Management (APIM) to Model Context Protocol (MCP) servers hosted on Azure Container Apps. See [Vision.md](Vision.md) for the target public- and private-ingress architectures.

## Validated Learnings

The following findings are listed in reverse chronological order.

1. On 2026-09-25, the licensed-tenant `MCP Capability Test` agent connected to the public Standard v2 APIM gateway using an API-scoped subscription key. APIM reached the MCP server through outbound VNet integration, private DNS, and the private Container Apps environment; the backend remained unavailable through public DNS.
2. Copilot Studio discovered `list_accessible_customers` and `get_accessible_customer` over Streamable HTTP at `/mcp`. The editor displayed `We couldn't load this tool's contract` while still listing and successfully invoking both tools, so that warning did not indicate a blocking protocol incompatibility.
3. `list_accessible_customers` returned and rendered all four fictitious records with customer number, name, reserved fictional phone number, and `example.com` email address.
4. `get_accessible_customer` returned the expected `CUST-1002` record. An invalid `CUST-001` lookup returned no customer, after which the agent used the list result to suggest the valid `CUST-1001` through `CUST-1004` range.
5. The observed Copilot Studio responses and citations exposed no APIM subscription key, access token, credentials, or non-fictitious customer data.
6. A uniquely tagged `GET /health` request returned `200` through APIM and the same sanitized correlation identifier appeared in the private Container App telemetry, proving propagation across the gateway-to-backend path without recording the identifier value. The temporary MCP tool connection was removed from the Copilot Studio test agent after the smoke test.
7. The Copilot Studio trial supports creating, configuring, previewing, and testing agents, but it does not support publishing them. The trial product provides tenant capacity and cannot be assigned to a user or device. Publishing requires an appropriate paid subscription or supported pay-as-you-go arrangement.
8. Copilot Studio supports MCP servers directly as agent tools. A connection requires a server name, description, and server URL; the interface presents `/mcp` as the expected endpoint pattern.
9. MCP connections support no authentication, API-key authentication, and OAuth 2.0.
10. OAuth 2.0 supports dynamic configuration with discovery, dynamic configuration, and manual configuration.
11. Manual OAuth requires a client ID, client secret, authorization URL, token URL, refresh-token URL, and scopes.
12. Dynamic OAuth with discovery requires only the MCP server URL and delegates metadata discovery to Copilot Studio. Manual OAuth remains the predictable initial option for a Microsoft Entra ID integration.
13. Connector and MCP catalog loading errors do not necessarily prevent adding a new MCP server through **Add** > **Model Context Protocol (MCP)**.
14. Dataverse and Copilot Studio provisioning are eventually consistent. Dataverse can report `Ready` before the Copilot Studio solution is fully available; refreshing after provisioning completes can resolve agent-creation errors.
15. The existing `Contoso (default)` Power Platform environment is usable. Dataverse has been provisioned, and the `MCP Capability Test` agent has been created.
16. The current user has sufficient administrative access: Global Administrator in Microsoft Entra ID, Azure Owner at management-group scope, and Environment Maker plus Basic User roles in Dataverse. A separate Copilot Studio tenant is not required.

## CLI Usage

The Python demonstration CLI is installed as `mcp` from the `msft-mcmc-mcp-service` project. Run these examples from the repository root so the CLI uses the gitignored root `.env`. The project configures `uv` to resolve Python packages through the corporate package proxy.

The CLI supports device-code authentication as its interactive flow. It does not accept passwords or provide a username/password flow. Before a first device-code run, complete any required initial password change for the selected disposable user in a browser.

### Run as Each User

James can access `CUST-1001` and `CUST-1002`:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user james
```

Jane can access `CUST-1003` and `CUST-1004`:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user jane
```

Bill has no customer access and receives an empty `customers` array:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user bill
```

### Complete a Device-Code Run

1. Start one of the user commands above.
2. Open the Microsoft verification URL printed in the terminal.
3. Enter the displayed device code.
4. Sign in as the same user selected by `--user` and grant the delegated permission when prompted.
5. Return to the terminal. The CLI verifies that the access token's immutable `oid` matches the selected user before contacting the MCP server.

The token and MSAL cache remain in memory. Signing in as another user, refusing consent, or having consent blocked by tenant policy produces a sanitized nonzero exit.

### Select an MCP Endpoint

The default endpoint is a local Entra-mode server at `http://127.0.0.1:8000/mcp`. Point the CLI at another Streamable HTTP endpoint with `MCMC_MCP_URL`:

```bash
MCMC_MCP_URL="https://<mcp-host>/mcp" \
	uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user james
```

Use another environment file when the generated configuration is not at the repository root:

```bash
MCMC_ENV_FILE="/secure/path/to/mcmc.env" \
MCMC_MCP_URL="https://<mcp-host>/mcp" \
	uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user jane
```

The environment file must contain the tenant ID, native public-client ID, delegated scope, and selected user's UPN and OID variables generated by Foundation. The CLI does not load initial-password variables.

### Noninteractive Checks

Display command help without authenticating:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --help
```

Confirm argument validation without authenticating. This returns exit code `2`:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user unknown
```

Run the mocked device-code tests and the real loopback Streamable HTTP integration test. These tests exercise the James, Jane, and Bill access matrix without live credentials:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	pytest \
	msft-mcmc-mcp/msft-mcmc-mcp-service/tests/test_cli.py \
	msft-mcmc-mcp/msft-mcmc-mcp-service/tests/test_cli_integration.py \
	-q
```

Successful runs print structured JSON containing the selected display name, the two discovered customer tool names, and only the customers authorized for that user. Configuration, authentication, authorization, protocol, and transport failures return a nonzero exit without printing passwords, access tokens, or provider error details.

## Revised Execution Plan

1. Define two deterministic demonstration tools, including their parameters, responses, errors, OAuth scopes, and acceptance tests.
2. Build one MCP server codebase and container image that can run with native OAuth validation enabled or with authentication delegated to APIM.
3. Deploy one minimal public MCP endpoint to Azure Container Apps and validate basic MCP discovery and invocation before introducing APIM or OAuth.
4. Connect the public endpoint to the Copilot Studio test agent with authentication set to **None**, then validate tool discovery and invocation in Preview.
5. Register the API and OAuth client in Microsoft Entra ID, expose delegated scopes, and configure the native OAuth server mode.
6. Provision APIM and private Azure Container Apps backends. Route one endpoint to the native OAuth server with token pass-through and protect the other with the APIM `validate-jwt` policy.
7. Validate successful requests, invalid-token cases, audience and scope enforcement, direct backend isolation, and end-to-end request tracing for both authentication patterns.
8. Evaluate standard OAuth metadata discovery after the manual Entra ID configuration works.
9. Continue agent development and testing in Copilot Studio Preview. Resolve paid publishing capability only when deployment to a channel is required.
10. Implement the Power Platform private-ingress architecture after the public-ingress architecture is proven, reusing the validated MCP servers and OAuth policies.

## Immediate Next Step

The validated disposable environment is intentionally retained at the operator's request. When testing is complete, destroy resources in application-then-foundation order and remove local secret-bearing state using the documented procedure.