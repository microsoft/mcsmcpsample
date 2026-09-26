# Copilot Studio

The Copilot Studio module owns the source-controlled public-ingress agents and their deployable Microsoft Dataverse solution projects.

The module coordinate is `msft-mcmc-mcs`, derived from the repository organization, product, and module identity files.

## Components

- `msft-mcmc-mcs-publicnative/` owns the MCMC Public Native agent, its native-validation MCP tool, connection reference, and `MCMCPublicNativeAgent` solution project.
- `msft-mcmc-mcs-publicgateway/` owns the MCMC Public Gateway agent, its gateway-validation MCP tool, connection reference, and `MCMCPublicGatewayAgent` solution project.

Each component root is an editable workspace captured with Power Platform CLI. It contains the agent instructions, topics, connector definition, connection-reference manifest, and MCP tool association. Its `solution/` directory is the transportable Dataverse solution project used for deployment. Generated `.mcs/` synchronization state and solution build outputs are not source artifacts.

## Agent Boundaries

MCMC Public Native has exactly one MCP connection and targets `/native/mcp`. APIM preserves the delegated bearer token, and the MCP service validates the token and applies per-user customer authorization.

MCMC Public Gateway has exactly one MCP connection and targets `/gateway/mcp`. APIM validates the delegated token and membership in `mcmc-customer-admins`, removes the authorization header after successful authorization, and invokes the trusted MCP service. Authenticated nonmembers receive `403 Forbidden` before backend invocation.

Both agents use the same deterministic instructions. Customer data must come from `list_customers` or `get_customer`; unavailable or rejected tools must not produce fabricated results.

## Source And Packaging

Power Platform CLI 2.12.2 can clone and pull the enriched agent workspaces, but `pac copilot pack` rejects their connector, connection-reference, and MCP tool files. Deployable unmanaged packages are built from each component's `solution/src/` directory with `pac solution pack`.

Connector configuration is stored as a deployment template. Before packaging, render `MCMC_ENTRA_TENANT_ID`, `MCMC_ENTRA_CONNECTOR_CLIENT_ID`, `MCMC_ENTRA_SCOPE`, and `MCMC_MCP_HOST` into a temporary solution tree. Stable Dataverse component identities remain unchanged because they preserve relationships across environments. Client secrets, OAuth tokens, target connection IDs, generated callback URIs, and connector synchronization state are not tracked.

A first deployment imports the solution to create the target connector and agent graph. The operator then registers the target-generated callback URI through Terraform, enters the connector client secret through the supported Power Platform interface, creates and consents the delegated connection, and binds the connection reference.

## Validated Transport

Both solutions were imported into and exported from a clean Dataverse-enabled Sandbox. Each retained one connector, one connection reference, one bot, 15 bot components, and one bot-to-connection-reference association. Instructions, MCP tool bindings, associations, designated routes, and portable OAuth settings survived the round trip. Target-generated callback metadata and connector capability normalization were the only expected differences.

Office AI-managed Microsoft 365 environments reject custom connector creation with `PermissionBlockedByOfficeAI` and are not valid deployment targets. `pac copilot status` in CLI 2.12.2 also fails for these agents because of a `componentstate_Property` schema incompatibility, so verification uses supported solution and Dataverse reads.
