---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC003
aliases:
  - MCMC003
name: Create Public-Ingress Copilot Studio Agents
ticket_status: "[[In Progress]]"
---
# Specification

Create and configure two Microsoft Copilot Studio agents that connect over the public internet to the governed MCP endpoints exposed by APIM in `MCMC002`.

Create one agent for each MCP authentication pattern, with exactly one MCP server connection per agent:

- **MCMC Public Native** uses the APIM route that passes OAuth tokens through to the MCP server for native validation.
- **MCMC Public Gateway** uses the APIM route that enforces OAuth and membership in the `mcmc-customer-admins` Microsoft Entra security group before forwarding to the MCP server without native OAuth. James, Jane, and the deployment administrator are members; Bill is excluded.

Keeping the routes in separate agents must make the selected ingress and OAuth enforcement boundary unambiguous during testing. Configure shared agent instructions so the deterministic demonstration tools are selected predictably. Validate both agents in Copilot Studio Preview because the current Copilot Studio trial supports creation and testing but not publishing.

# Technical Solution

Create and validate two golden-agent variants in the development environment using Copilot Studio's native MCP tool integration. Each golden agent must contain one MCP server connection: the Public Native variant targets only the native-validation route, and the Public Gateway variant targets only the gateway-validation route. Use manual OAuth 2.0 configuration against Microsoft Entra ID first; evaluate dynamic discovery only after the manual flow succeeds.

Configure the required Microsoft Entra ID API and client registrations, delegated scopes, redirect URI, consent, client credentials, and gateway authorization group. Emit security-group membership in MCP API access tokens and require the Terraform-managed `mcmc-customer-admins` group at the gateway. Do not store client secrets in the repository.

Clone or export both validated golden agents and all transportable dependencies into source control. Share common instructions and packaging conventions without combining the MCP connections into one agent. Include each custom MCP connector before its corresponding agent and connection reference, following Power Platform solution dependency ordering. Prove that each isolated MCP tool association, the shared agent instructions, and non-secret OAuth settings survive a clean solution export and import before treating the artifacts as deployable.

Implement a matrix-driven shell script that orchestrates the supported Power Platform CLI workflow for one agent variant at a time. Render the selected portable connector settings into a temporary copy of its standard Dataverse solution project, use `pac solution pack` to create the unmanaged package, and use `pac solution import` to deploy it. Verify the imported solution and logical component graph through supported solution and Dataverse interfaces while `pac copilot status` remains incompatible with the imported component schema. Invoke `pac copilot publish` only where the target license and environment permit publishing. The script must accept the agent display name, schema name, MCP URL, ingress type, OAuth enforcement type, and environment identifiers as inputs; use an existing authenticated `pac` profile or documented noninteractive authentication; avoid unsupported internal Dataverse `Pva*` actions; and never persist credentials in source control or command output.

Treat OAuth connections, callback URI registration, user consent, and imported-agent authentication settings as explicit environment-specific steps. Automate them only through supported interfaces; otherwise have the script stop with clear instructions for the required manual action and resume safely after it is completed.

Exercise each public-ingress agent independently from Copilot Studio Preview and correlate its requests through APIM to the corresponding private MCP deployment.

## Current Demo Decision

Automated agent deployment is deferred after clean-environment testing showed that connector secrets and delegated connections still require repeated portal repair. Retain the Phase 4 implementation and evidence for future work, but use manual agent and MCP connector creation for the current demonstration.

On 2026-09-26, the `MCMC Import Test` solutions, agents, custom connectors, connection references, and generated deployment settings were removed. The development golden agents, source-controlled artifacts, Microsoft Entra registrations, and Azure infrastructure were preserved. The two user-owned delegated connector connections remain for their owner to delete through Power Apps.

## Naming and Matrix Contract

Use one solution per agent so each authentication boundary can be packaged, imported, and validated independently. Persist the complete component schema names below; scripts must not prepend the publisher prefix a second time.

| Field | Public Native | Public Gateway |
|---|---|---|
| Variant key | `public-native` | `public-gateway` |
| Agent display name | `MCMC Public Native` | `MCMC Public Gateway` |
| Agent schema name | `mcmc_PublicNative` | `mcmc_PublicGateway` |
| Solution display name | `MCMC Public Native Agent` | `MCMC Public Gateway Agent` |
| Solution unique name | `MCMCPublicNativeAgent` | `MCMCPublicGatewayAgent` |
| Connector display name | `MCMC Public Native MCP` | `MCMC Public Gateway MCP` |
| Connector schema name | `mcmc_PublicNativeMcp` | `mcmc_PublicGatewayMcp` |
| Connection reference display name | `MCMC Public Native MCP Connection` | `MCMC Public Gateway MCP Connection` |
| Connection reference schema name | `mcmc_PublicNativeMcpConnection` | `mcmc_PublicGatewayMcpConnection` |
| MCP URL source | `api_management_native_mcp_url` Terraform output | `api_management_gateway_mcp_url` Terraform output |
| Ingress type | `public` | `public` |
| OAuth enforcement type | `native` | `gateway` |

The deployment workflow must accept these common environment inputs:

- `MCMC_PAC_PROFILE`: authenticated Power Platform CLI profile; `mcmc` in the development environment.
- `MCMC_POWER_PLATFORM_ENVIRONMENT`: target environment URL or environment ID; never rely on a friendly-name lookup in automation.
- `MCMC_PUBLISHER_UNIQUE_NAME`: existing publisher unique name; `MCMC` in the development environment.
- `MCMC_PUBLISHER_PREFIX`: expected publisher prefix; `mcmc` in the development environment.
- `MCMC_SOLUTION_VERSION`: four-part solution version, initially `1.0.0.0`.
- `MCMC_ENTRA_TENANT_ID`: target Microsoft Entra tenant identifier.
- `MCMC_ENTRA_API_CLIENT_ID`: MCP API application client identifier.
- `MCMC_ENTRA_CONNECTOR_CLIENT_ID`: selected variant's connector application client identifier.
- `MCMC_ENTRA_SCOPE`: fully qualified delegated MCP scope.
- `MCMC_MCP_HOST`: selected target's APIM hostname without a scheme or route path.
- `MCMC_ALLOW_PUBLISH`: explicit boolean gate; `false` for the current trial environment.

Each selected matrix entry supplies its variant key, stable display and schema names, MCP URL, ingress type, and OAuth enforcement type. Environment-specific identifiers and non-secret OAuth values may be passed through environment variables or generated manifests. Client secrets, tokens, connection credentials, and consent artifacts must not be accepted as command-line arguments or committed to source control; their supported handling is defined in the following Phase 1 task.

The naming matrix is the desired contract for automation and future naming cleanup. Connector recreation caused Power Platform to persist generated transport identities in the validated artifacts. The deployment workflow must read these identities from the selected solution source rather than synthesize them from the desired connector and connection-reference names:

The source workspaces are owned by the `msft-mcmc-mcs` Copilot Studio module. Public Native is the `msft-mcmc-mcs-publicnative` component, and Public Gateway is the `msft-mcmc-mcs-publicgateway` component. Each component contains its editable agent workspace at the component root and its deployable Dataverse project under `solution/`.

| Transported identity | Public Native | Public Gateway |
|---|---|---|
| Bot ID in the development environment | `33333333-3333-4333-8333-333333333333` | `44444444-4444-4444-8444-444444444444` |
| Connector ID | `55555555-5555-4555-8555-555555555555` | `66666666-6666-4666-8666-666666666666` |
| Connector name | `mcmc_5Fmcmc-20public-20native-20mcp-202` | `mcmc_5Fmcmc-20public-20gateway-20mcp-202` |
| Connection-reference logical name | `mcmc_PublicNative.shared_mcmc-5fmcmc-20public-20native-20mcp-202-5f5e91a8aaf86d61ed.b647079188df4b84a77549e29cb7861b` | `mcmc_PublicGateway.shared_mcmc-5fmcmc-20public-20gateway-20mcp-202-5f5e91a8aaf86d61ed.e1216202c1284f56a83b73a016d699a2` |

## OAuth Automation Boundary

| Operation | Ownership | Contract |
|---|---|---|
| MCP API and connector client registrations, delegated permissions, and scopes | Automated | Terraform owns the Microsoft Entra resources and non-secret configuration. |
| Connector and agent definitions | Automated after golden-agent validation | Store the editable `pac copilot clone` workspace and the transportable Dataverse solution project in source control. Render and package the solution project with `pac solution pack`. |
| Connector callback URI discovery | Operator | Create or import the connector in the target environment, then copy the generated redirect URI from its security settings. |
| Connector callback URI registration | Automated after discovery | Supply the approved URI to Terraform and apply it to the connector client registration; do not mutate the Terraform-owned registration only through the portal. |
| OAuth client secret creation and rotation | Automated generation, operator handoff | Create the secret through the infrastructure secret workflow, never commit it or pass it as a command-line argument, and enter it only through the supported connector security interface. |
| OAuth connection creation and sign-in | Operator | Create one target-environment connection for each connector and complete interactive Microsoft Entra sign-in. Connections and credentials are not transported in solutions. |
| Delegated user consent | Operator | Complete consent during connection sign-in when tenant policy permits it; use an administrator-approved consent process when policy blocks user consent. |
| Connection reference transport | Automated | Include the reference in its agent solution and generate deployment settings with `pac solution create-settings`. |
| Connection reference binding | Automated after operator input | Supply the target connection ID and connector ID through a generated, untracked deployment settings file passed to `pac solution import --settings-file`. |
| Solution import and agent provisioning | Automated | Import the connector-rooted solution, then verify its solution and logical component graph through supported solution and Dataverse interfaces. |
| Imported-agent authentication repair | Operator when prompted | Reauthenticate or repair the connection in Copilot Studio or Power Apps, then resume verification without rebuilding artifacts. |
| Agent publishing | Automated only when licensed | Require `MCMC_ALLOW_PUBLISH=true`; otherwise stop at Copilot Studio Preview validation. |

`pac connection create` is not used here because it creates an application-authenticated Dataverse connection and requires a client secret argument; it does not create the delegated OAuth connector connection used by these MCP tools.

On a first deployment, the workflow must import the solution before the target-generated connector callback URI or delegated connection can exist. It must then pause for callback discovery and Terraform registration, connector secret entry, delegated connection creation and consent, and connection-reference binding. A resumed deployment may re-import with an untracked settings file when a supported connection-reference binding is available. It must stop again when authentication repair is required and resume at verification after the operator confirms completion. Generated deployment settings containing environment-specific connection IDs must remain untracked even though they contain no connection credentials.

## Verified Golden-Agent and Authorization Evidence

- Both golden agents use identical deterministic instructions: customer data must come only from `list_customers` or `get_customer`, and failed or unavailable tools must never produce fabricated results.
- In Copilot Studio Preview, the Public Native agent returned zero customers for the deployment administrator under native per-user authorization. The Public Gateway agent returned all four demonstration customers for the same administrator through gateway authorization.
- The Terraform-managed `mcmc-customer-admins` group has object ID `77777777-7777-4777-8777-777777777777`. James, Jane, and the deployment administrator are members; Bill is excluded.
- APIM validates the Gateway token and group claim before deleting `Authorization`. Invalid tokens return `401`; authenticated nonmembers return `403 Forbidden` before backend invocation. The rendered-policy validator passes.
- The Native route preserves the bearer token for MCP-service validation. The Gateway route strips it only after successful token and group authorization and then invokes the trusted backend.
- Both connector client secrets were rotated after accidental exposure, and the exposed values are invalid. Current secret values, delegated tokens, and connection credentials are absent from tracked files and command output.
- Both recreated connector callback URIs were registered through Terraform. The foundation and application Terraform layers converged with no pending changes after deployment.
- `pac copilot pull` reported zero changes for both captured golden-agent workspaces before packaging work began.

## Verified Packaging and Round-Trip Evidence

- Power Platform CLI 2.12.2 can clone and pull the enriched agent workspaces, but `pac copilot pack` rejects the generated connector directory, connection-reference manifest, and MCP tool component. The deployable sources are therefore the standard Dataverse solution projects under `msft-mcmc-mcs/msft-mcmc-mcs-publicnative/solution/` and `msft-mcmc-mcs/msft-mcmc-mcs-publicgateway/solution/`, built with `pac solution pack`.
- The tracked connector templates use `MCMC_ENTRA_TENANT_ID`, `MCMC_ENTRA_CONNECTOR_CLIENT_ID`, `MCMC_ENTRA_SCOPE`, and `MCMC_MCP_HOST`. Connector credentials, OAuth tokens, target connection IDs, development-environment URLs, and generated connector timestamps are absent. Stable Dataverse component identities remain because they preserve relationships during transport.
- Each clean solution contains one current connector, one connection reference, one bot, 15 bot components, and one bot-to-connection-reference association. The Public Native solution excludes the superseded original connector.
- Both unmanaged packages imported successfully into the clean `MCMC Import Test` Sandbox and exported again. Shared instructions, MCP tool bindings, and bot-to-connection-reference associations matched exactly. Portable OAuth settings matched, and each connector retained only its designated `/native/mcp` or `/gateway/mcp` route.
- The target platform added only expected connector normalization: a target-generated callback URL, connector capability flags, and OAuth-setting casing normalization. The exported artifacts contained no secret-bearing fields.
- The Microsoft 365 environment is managed by Office AI and cannot host this deployment. Both solution import and direct connector creation failed with `PermissionBlockedByOfficeAI` for `Create Custom Connector`, despite the user having valid licenses and Global connector privileges. A normal Dataverse-enabled Sandbox is required.
- `pac copilot status` in CLI 2.12.2 fails against these agents because of a `componentstate_Property` schema incompatibility. Deployment verification must use supported solution and Dataverse reads until that CLI defect is resolved.

## Phase 4 and Phase 5 Execution Evidence

- `msft-mcmc-mcs/deploy.sh` implements the validated matrix, temporary rendering, unmanaged packaging and import, supported graph verification, staged operator handoffs, publication gate, Office AI rejection, and rerun-state checks. Nine focused mock-PAC tests cover valid deployment, invalid inputs, partial state, target-generated connector IDs, operator confirmation, and publish gating.
- On 2026-09-26, the `MCMC Import Test` Sandbox was reset to contain neither solution nor agent records. Scripted `bootstrap` then imported both Public Native and Public Gateway from the tracked templates and verified one connector, one connection reference, one agent, 15 bot components, and one bot-to-connection-reference association for each variant.
- Both bootstraps generated ignored settings templates under `.artifacts/mcmc003/` and stopped with the documented operator-action status. The target connector references are not yet bound to delegated connections.
- The clean-Sandbox connector callback URIs were discovered from supported Dataverse reads, added to the Terraform-owned registrations, and applied with a reviewed `0 add, 2 change, 0 destroy` plan. A subsequent Foundation plan reported no changes.
- The operator configured both connector secrets, completed delegated connection consent, and selected the target connections. Both ignored settings files were populated from supported Dataverse reads, and both `bind` stages reimported successfully with `--settings-file` before verifying the complete graphs.
- Live repair proved that the final solution import does not preserve the secure connector secret. Each variant therefore requires secret re-entry and connection repair after `bind`; the Gateway repair used a newly appended credential that was validated directly against Entra without exposing its value.
- Both `verify` stages passed with publishing disabled and reported the required Copilot Studio Preview path. Both target connection references remained populated after import. Preview invocation and correlation validation remain the final portal-triggered checks.
- Automated deployment is now deferred for the demo. The clean-Sandbox deployment artifacts were torn down on 2026-09-26, and manual recreation is the active path for completing the remaining Preview checks.

# Definition of Done

- Separate MCMC Public Native and MCMC Public Gateway agents exist in the Dataverse-enabled Power Platform environment.
- Each agent has exactly one MCP server connection and targets only its designated public APIM route.
- Validated golden-agent variants and their transportable solution components are stored in source control without credentials or environment-specific secrets.
- A clean-environment round trip proves that each isolated MCP tool association, the shared agent instructions, connectors, and connection references survive packaging and solution import.
- Microsoft Entra ID OAuth succeeds for both routes.
- The gateway route permits members of `mcmc-customer-admins`, rejects authenticated nonmembers before backend invocation, and keeps Bill outside that group.
- A matrix-driven shell script uses supported `pac` commands to package, import, verify, and, where permitted, publish each agent without invoking internal Dataverse provisioning actions.
- The script is repeatable, accepts environment-specific configuration as inputs, and stops safely with actionable guidance for any OAuth or consent step that cannot be automated.
- Each agent discovers and invokes the expected deterministic tools only through its designated authentication pattern.
- Shared agent instructions result in predictable tool selection and do not fabricate failed tool results.
- Missing, invalid, or insufficient authorization is surfaced without exposing sensitive details.
- Requests can be correlated from Copilot Studio through APIM to the correct MCP deployment.
- Public access is limited to the governed APIM endpoint; neither MCP backend is publicly reachable.
- Both complete flows are validated independently in Copilot Studio Preview.
- Publishing requirements and the current trial limitation are documented.

# Execution Plan

## Phase 1 - Confirm Automation and Deployment Contracts

- [x] Confirm the required Power Platform CLI version, authentication method, environment permissions, solution publisher, and licensing constraints.
- [x] Define stable names for the Public Native and Public Gateway agents, solutions, connectors, and connection references, plus the environment-specific matrix input contract.
- [x] Record which OAuth settings, callback URI operations, connections, and consent steps are supported for automation and which require operator action.

## Phase 2 - Create and Validate the Golden Agents

- [x] Create the MCMC Public Native golden agent with shared deterministic instructions, generative orchestration enabled, and only the native-validation MCP connection.
- [x] Create the MCMC Public Gateway golden agent with the same shared instructions and only the gateway-validation MCP connection.
- [x] Create the `mcmc-customer-admins` security group with James, Jane, and the deployment administrator; emit security-group claims in MCP API access tokens; and enforce membership at the APIM gateway with automated policy validation.
- [x] Complete the Entra application, delegated scope, redirect URI, consent, and connector connection configuration without placing secrets in source control.
- [x] Validate each agent independently and prove it discovers and invokes tools only through its designated APIM route.

## Phase 3 - Capture a Deployable Artifact

- [x] Clone or export both golden agents, MCP connector definitions, connection references, and required solution components into source control.
- [x] Ensure each custom MCP connector is packaged for deployment before its corresponding agent and connection reference.
- [x] Remove credentials, generated environment identifiers, and other nonportable values from the tracked artifacts.
- [x] Import both variants into a clean test environment and prove that their isolated MCP tool associations, shared instructions, and non-secret settings survive the round trip.

## Phase 4 - Implement Shell-Based Deployment

- [x] Implement a matrix-driven shell script that validates prerequisites and one agent variant's display name, schema name, MCP URL, ingress type, OAuth enforcement type, and environment inputs before making changes.
- [x] Render portable connector settings into a temporary solution tree, orchestrate `pac solution pack` and `pac solution import`, and verify each imported logical component graph through supported solution and Dataverse interfaces.
- [x] Add safe first-import and pause-and-resume behavior with actionable instructions for callback URI registration, connector secret entry, OAuth connection creation, consent, connection-reference binding, or authentication repair.
- [x] Invoke `pac copilot publish` only when publishing is supported by the target environment and otherwise report the Preview-only validation path.
- [x] Make reruns safe by rejecting Office AI-managed targets, detecting existing solutions and agents by stable schema name, and failing clearly on incompatible state.

## Phase 5 - Validate and Document the Public-Ingress Agents

- [x] Run the script for both public matrix entries against a clean environment and record the automated and manual portions of each deployment.
- [x] Tear down the clean-environment solutions, agents, connectors, connection references, and generated deployment settings after deferring automated deployment.
- [ ] Exercise each agent's authentication pattern for successful and rejected requests and verify predictable tool selection and error handling.
- [ ] Correlate each agent's requests through APIM to the correct private MCP deployment and confirm neither backend is publicly reachable.
- [x] Document manual recreation, deferred automation, authentication, secret handling, teardown, and the current trial publishing limitation.