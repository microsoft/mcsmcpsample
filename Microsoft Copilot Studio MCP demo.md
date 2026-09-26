# Microsoft Copilot Studio MCP demo

The Microsoft Copilot Studio MCP demo proves two authentication patterns for stateless Model Context Protocol services hosted in Azure Container Apps. Both deployments run the same immutable service image, expose Streamable HTTP at `/mcp`, and use only fictitious customer data.

## Current Capabilities

- Azure API Management exposes separate public OAuth routes for native MCP validation and APIM validation of the trusted service.
- A native command-line client authenticates disposable demonstration users through Microsoft Entra device-code flow.
- The Entra-mode MCP service validates bearer-token signature, issuer, client-ID audience, lifetime, delegated scope, tenant, and immutable user object identifier.
- James sees two assigned customer records, Jane sees a different two records, and Bill sees none.
- The trusted-mode MCP service performs no native token validation and returns the complete fictitious catalog because its authentication boundary is external.
- Health probes, structured completion logs, and caller-provided correlation identifiers support operational verification without logging credentials or tool payloads.

## Architecture

```mermaid
flowchart LR
    CS[Copilot Studio] --> NativeRoute[APIM native route]
    CS --> GatewayRoute[APIM gateway route]
    CLI[Python CLI] --> NativeRoute
    CLI --> GatewayRoute
    NativeRoute --> Entra[Private Entra MCP app]
    GatewayRoute --> Trusted[Private trusted MCP app]
    CLI --> EntraID[Microsoft Entra ID]
    EntraID --> CLI
    EntraID --> NativeRoute
    EntraID --> GatewayRoute
    Trusted --> Logs[Log Analytics]
    Entra --> Logs
    Image[Immutable ACR image] --> Trusted
    Image --> Entra
```

The Standard v2 APIM gateway is public and reaches both Container Apps through outbound VNet integration and private DNS. `/native/mcp` preserves the bearer token for native validation and per-`oid` authorization. `/gateway/mcp` validates the token and delegated scope at APIM, removes the bearer header, and invokes the intentionally unfiltered trusted service. Both routes publish protected-resource metadata and require OAuth rather than APIM subscription keys.

Both Container Apps run in one internal Azure Container Apps environment with public network access disabled. Their default-domain names do not resolve through public DNS, and ingress rules allow only the delegated APIM subnet. A shared user-assigned identity has `AcrPull` access to the registry, whose administrator credentials remain disabled.

## Workflows

The next Copilot Studio workflow connects the `MCMC003` test agent to both OAuth-governed APIM MCP endpoints, discovers both tools, and invokes them in Preview. The earlier subscription-key connection was removed after compatibility validation.

The validation workflow starts the Python CLI for James, Jane, or Bill, completes interactive device-code authentication and consent, verifies that the token's `oid` matches the selected profile, and calls either public APIM route. Tokens and the MSAL cache remain in memory.

Infrastructure deployment proceeds in three ordered layers: Foundation, immutable container publication, and Application. Foundation owns networking, monitoring, APIM, the registry, Entra registrations, disposable users, and the sensitive local `.env`. Application deploys both private Container Apps from the exact digest recorded by the container layer.

## Security And Data Handling

The customer catalog contains only obviously fictitious names, reserved telephone numbers, and `example.com` email addresses. Entra authorization uses only verified immutable object identifiers; mutable display names and user principal names are not authorization subjects. Inaccessible and nonexistent customer lookups are indistinguishable.

Generated initial passwords are limited to first interactive sign-in. They remain in gitignored local Terraform state and the mode-`0600` root `.env`; the CLI does not read them. Access tokens, passwords, authorization headers, customer payloads, and response bodies are excluded from application logs and APIM diagnostics.

## Validated State

Copilot Studio Preview discovered and invoked both MCP tools through the former APIM smoke route. The deployed native route passed the James, Jane, and Bill access matrix, while the APIM-validation route admitted all three valid scoped tokens and returned the trusted app's four fictitious records. Both apps run the same immutable image digest, health probes pass, direct cross-backend access returns `403`, public backend DNS resolution fails, and tagged requests correlate through sanitized APIM and Container App telemetry.

See [MCP](msft-mcmc-mcp/MCP.md) for service and CLI behavior, [Deployment](msft-mcmc-deployment/Deployment.md) for infrastructure lifecycle procedures, [Vision](Vision.md) for the long-term architecture, and the active tickets for planned changes.