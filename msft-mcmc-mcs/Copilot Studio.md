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

## Current Manual Deployment

For the current demonstration, create `MCMC Public Native` and `MCMC Public Gateway` manually in the target Dataverse-enabled environment. Enable generative orchestration, copy the deterministic instructions from the corresponding source-controlled `agent.mcs.yml`, and add exactly one manually configured OAuth 2.0 MCP tool to each agent. Native targets `/native/mcp`; Gateway targets `/gateway/mcp`.

Enter the variant's Terraform-managed client ID, current secret from the approved local secret source, tenant-specific authorization and token URLs, and fully qualified delegated scope. Save the connector, register its generated callback URI through the Terraform-owned redirect URI input, then create the delegated connection and complete consent. Confirm that `list_customers` and `get_customer` are discovered, enable the MCP server, and validate both tools in Preview.

Native results must follow per-user authorization. Gateway must return the complete demonstration catalog for members of `mcmc-customer-admins` and return `403 Forbidden` for Bill. Publishing remains outside the current trial scope.

## Deferred Deployment Automation

The scripted workflow below was implemented and validated as an experiment but is on hold for the current demonstration. It is retained for future work and is not the current deployment runbook.

`deploy.sh` selects one public agent variant and validates its supplied display name, schema name, MCP URL, ingress type, and OAuth enforcement type against the fixed deployment matrix. Before creating a package, it also validates every required environment input, the portable source placeholders, the named authenticated PAC profile, and access to the exact target environment URL or ID. Matrix mismatches and malformed or missing values fail without changing the target environment.

After preflight, the script copies the selected solution into an automatically removed temporary directory, renders its connector OAuth settings, APIM host, and solution version, and packages and imports the unmanaged solution with supported PAC commands. It then verifies the solution, connector, connection reference, agent, 15 bot components, and bot-to-connection-reference association using `pac solution list` and file-based `pac org fetch` queries. The tracked templates are never modified.

Deployment uses three explicit stages. `bootstrap` performs the first import, generates an ignored settings template under `.artifacts/mcmc003/`, and exits with status 3 plus instructions for callback registration, secret entry, connection creation, and consent. The operator populates both the connection ID and the target-generated connector resource ID because the connector resource suffix changes between environments. `bind` requires explicit confirmations and a populated, secret-free settings file, reimports with the connection-reference binding, and pauses for authentication repair. The operator must re-enter the connector secret after this final import because secure connector values are not transported, then repair or recreate the delegated connection and select it for the tool. `verify` requires confirmation that repair is complete and resumes directly at graph verification without rebuilding the package.

The final stage invokes `pac copilot publish` only when `MCMC_ALLOW_PUBLISH=true`. When publishing is disabled, it completes verification and explicitly directs the operator to the Copilot Studio Preview validation path.

PAC does not expose an Office AI management flag in its environment listings, so deployments require an explicit `MCMC_OFFICE_AI_MANAGED=false` assertion and reject `true`. Imports also recognize `PermissionBlockedByOfficeAI` and return the same actionable failure. Before any import or resume, the script checks for the solution by unique name and the agent by schema name; it rejects partial state, duplicate bootstrap attempts, and resume attempts against missing artifacts.

## Validated Transport

Both solutions were imported into and exported from a clean Dataverse-enabled Sandbox. Each retained one connector, one connection reference, one bot, 15 bot components, and one bot-to-connection-reference association. Instructions, MCP tool bindings, associations, designated routes, and portable OAuth settings survived the round trip. Target-generated callback metadata and connector capability normalization were the only expected differences.

The scripted bootstrap was subsequently run for both variants against a reset `MCMC Import Test` Sandbox. Both temporary packages imported successfully, both complete component graphs passed supported Dataverse verification, and both ignored deployment-settings templates were generated. The target-generated callback URIs were added to the Terraform-owned connector registrations and the Foundation layer converged. The operator completed delegated consent and selected both target connections; both scripted settings-file imports and final graph verification stages then passed.

On 2026-09-26, the scripted deployment was placed on hold because secure connector values and delegated connection repair required repeated portal intervention. The two test solutions, agents, connectors, connection references, and generated deployment settings were removed from `MCMC Import Test`. The two user-owned delegated connections require deletion by their owner in Power Apps. Development golden agents, source artifacts, Microsoft Entra registrations, and Azure infrastructure were preserved for manual recreation and future automation work.

Office AI-managed Microsoft 365 environments reject custom connector creation with `PermissionBlockedByOfficeAI` and are not valid deployment targets. `pac copilot status` in CLI 2.12.2 also fails for these agents because of a `componentstate_Property` schema incompatibility, so verification uses supported solution and Dataverse reads.
