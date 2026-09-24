# Copilot Studio MCP Demonstration

This project demonstrates Microsoft Copilot Studio connecting through Azure API Management (APIM) to Model Context Protocol (MCP) servers hosted on Azure Container Apps. See [Vision.md](Vision.md) for the target public- and private-ingress architectures.

## Validated Learnings

The following findings are listed in reverse chronological order.

1. The Copilot Studio trial supports creating, configuring, previewing, and testing agents, but it does not support publishing them. The trial product provides tenant capacity and cannot be assigned to a user or device. Publishing requires an appropriate paid subscription or supported pay-as-you-go arrangement.
2. Copilot Studio supports MCP servers directly as agent tools. A connection requires a server name, description, and server URL; the interface presents `/mcp` as the expected endpoint pattern.
3. MCP connections support no authentication, API-key authentication, and OAuth 2.0.
4. OAuth 2.0 supports dynamic configuration with discovery, dynamic configuration, and manual configuration.
5. Manual OAuth requires a client ID, client secret, authorization URL, token URL, refresh-token URL, and scopes.
6. Dynamic OAuth with discovery requires only the MCP server URL and delegates metadata discovery to Copilot Studio. Manual OAuth remains the predictable initial option for a Microsoft Entra ID integration.
7. Connector and MCP catalog loading errors do not necessarily prevent adding a new MCP server through **Add** > **Model Context Protocol (MCP)**.
8. Dataverse and Copilot Studio provisioning are eventually consistent. Dataverse can report `Ready` before the Copilot Studio solution is fully available; refreshing after provisioning completes can resolve agent-creation errors.
9. The existing `Contoso (default)` Power Platform environment is usable. Dataverse has been provisioned, and the `MCP Capability Test` agent has been created.
10. The current user has sufficient administrative access: Global Administrator in Microsoft Entra ID, Azure Owner at management-group scope, and Environment Maker plus Basic User roles in Dataverse. A separate Copilot Studio tenant is not required.

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

Define the two demonstration MCP tools and their input and output schemas before implementing the server.