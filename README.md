# Copilot Studio MCP Demonstration

This project demonstrates Microsoft Copilot Studio connecting through Azure API Management (APIM) to Model Context Protocol (MCP) servers hosted on Azure Container Apps. See [Vision.md](Vision.md) for the target public- and private-ingress architectures.

## Validated Learnings

The following findings are listed in reverse chronological order.

1. On 2026-09-26, Standard v2 APIM exposed separate OAuth-governed Streamable HTTP routes at `/native/mcp` and `/gateway/mcp`, with RFC 9728 protected-resource metadata for each. The temporary subscription-key route was removed after validation.
2. Independent device-code runs for James, Jane, and Bill discovered and invoked both tools through both routes. Native mode enforces the immutable-`oid` access matrix. Gateway mode validates tokens and requires membership in the Terraform-managed `mcmc-customer-admins` security group before returning the intentionally unfiltered trusted catalog.
3. Missing, malformed, and wrong-audience tokens returned `401`. A real request body over 1 MiB returned `413`, and gateway-generated error responses preserved sanitized correlation identifiers.
4. Both Container Apps allow ingress only from the delegated APIM subnet. A cross-backend request from a Container App replica returned `403`, and neither backend hostname resolves through public DNS.
5. APIM gateway logs and metrics flow to the existing Log Analytics workspace without request or response bodies. Correlation identifiers join APIM and sanitized backend completion telemetry without exposing authorization headers, tokens, credentials, or customer payloads.
6. On 2026-09-25, the licensed-tenant `MCP Capability Test` agent proved Copilot Studio compatibility through the former subscription-key MCP route. It discovered and invoked both tools despite displaying `We couldn't load this tool's contract`; that temporary tool connection and route were subsequently removed.
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

## Deployment

### Microsoft Copilot Studio Agents

The user that creates and publishes the agents must have these Dataverse security roles in the target environment:

- **Basic User** for baseline Dataverse access. This role is normally assigned automatically in a default environment.
- **Environment Maker** to create agents, connections, and other environment resources.
- **System Customizer** to create or update solution-aware components and use the solution publisher.

An administrator with the **System Administrator** role, or equivalent privileges to read and assign security roles, can assign these roles. A Global Administrator, Power Platform Administrator, or Dynamics 365 Administrator who doesn't yet have direct Dataverse administrator access can optionally self-elevate through the [Power Platform admin center](https://admin.powerplatform.microsoft.com):

- Select **Manage** > **Environments** > **Caldova (default)**.
- On the environment command bar, select **Membership**.
- In the **System Administrators** pane, select **Add me**.
- Wait for the assignment to propagate, then refresh the environment. Self-elevation is audited in Microsoft Purview.

After obtaining administrator access, assign **System Customizer** to the deployment user:

- Select **Manage** > **Environments** > **Caldova (default)** > **Settings**.
- Select **Users + permissions** > **Users**.
- Open the deployment user's row menu (**...**) and select **Manage security roles**.
- Preserve **Basic User** and **Environment Maker**, select **System Customizer**, and then select **Save**.
- Allow time for the role change to propagate before authenticating with Power Platform CLI.

Create the shared solution publisher before creating either agent solution:

- In [Power Apps](https://make.powerapps.com), select **Caldova (default)** and open **Solutions**.
- Select **New solution** > **New publisher**.
- Set the display name to `MCMC`, unique name to `MCMC`, and prefix to `mcmc`.
- Save the publisher, then close the solution form without creating a solution. The stable solution names are defined separately before solution creation.

For more information, see [Assign security roles](https://learn.microsoft.com/power-platform/admin/assign-security-roles) and [Role-based security roles for Dataverse](https://learn.microsoft.com/power-platform/admin/database-security).

1. Authenticate Power Platform CLI to the target environment using the development container's managed identity:

   ```bash
   pac auth create \
	   --name mcmc \
	   --environment "Caldova (default)" \
	   --managedIdentity
   ```

   Confirm that the new profile is active and connected to `Caldova (default)`:

   ```bash
   pac auth select --name mcmc
   pac org who
   ```

#### OAuth Deployment Boundary

Terraform continues to own the Microsoft Entra registrations, scopes, and callback URI registrations. For the current demonstration, create the agents, connectors, delegated connections, and consent manually in the target Power Platform environment. The source-controlled agent and solution artifacts remain available as golden references.

An operator must create each target-environment connector connection, enter or rotate its client secret through the supported connector security interface, complete Microsoft Entra sign-in and consent, and provide the resulting connection ID for an untracked deployment settings file. Connections, credentials, tokens, and consent do not travel in solutions. `pac connection create` is not suitable because it creates an application-authenticated Dataverse connection rather than the delegated OAuth connection used by the MCP connector.

Publishing remains disabled unless the target environment is licensed. Validate the current demonstration in Copilot Studio Preview.

#### Deferred Scripted Agent Deployment

The scripted import workflow is retained for future development but is on hold for the current demonstration. Use the manual recreation procedure below instead. The following commands document the implemented experimental workflow and its validation history; they are not the current deployment runbook.

Run `msft-mcmc-mcs/deploy.sh` from the repository root with Power Platform CLI 2.12.2 or later, Python 3, an authenticated PAC profile, and a Dataverse-enabled target. The target must already contain the `MCMC` publisher with prefix `mcmc`. PAC does not identify Office AI-managed environments in its listings, so set `MCMC_OFFICE_AI_MANAGED=false` only after confirming the target supports custom connectors.

Set the shared non-secret inputs without placing connector secrets on the command line:

```bash
set -a
source .env
set +a

export MCMC_PAC_PROFILE=mcmc
export MCMC_POWER_PLATFORM_ENVIRONMENT=https://<target-environment>.crm.dynamics.com/
export MCMC_PUBLISHER_UNIQUE_NAME=MCMC
export MCMC_PUBLISHER_PREFIX=mcmc
export MCMC_SOLUTION_VERSION=1.0.0.0
export MCMC_MCP_HOST=<apim-hostname>
export MCMC_ALLOW_PUBLISH=false
export MCMC_OFFICE_AI_MANAGED=false
```

Select the variant's connector client ID and define its stable matrix arguments. Bootstrap imports the solution, verifies its logical graph, writes an ignored settings template under `.artifacts/mcmc003/`, and exits with status `3` to signal required operator action:

```bash
export MCMC_ENTRA_CONNECTOR_CLIENT_ID="$MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_ID"
native_args=(
	--variant public-native
	--agent-display-name "MCMC Public Native"
	--agent-schema-name mcmc_PublicNative
	--mcp-url "https://${MCMC_MCP_HOST}/native/mcp"
	--ingress-type public
	--oauth-enforcement-type native
)
msft-mcmc-mcs/deploy.sh --stage bootstrap "${native_args[@]}"
```

After bootstrap, copy the generated callback URI from the connector, add it to the Terraform-owned `entra_mcp_connector_redirect_uris` entry, review and apply the Foundation plan, and enter the current connector client secret only through Power Apps or Copilot Studio. Create the delegated OAuth connection and complete consent. In the generated settings file, set `ConnectionId` to that connection and `ConnectorId` to the target-generated connector resource ID; neither value is a credential, but the file remains untracked because both are environment-specific.

Resume binding only after those actions are complete:

```bash
export MCMC_CALLBACK_URI_REGISTERED=true
export MCMC_CONNECTOR_SECRET_CONFIGURED=true
export MCMC_CONNECTION_AUTHORIZED=true
msft-mcmc-mcs/deploy.sh --stage bind "${native_args[@]}"
```

The bind stage reimports with `--settings-file`, verifies the graph, and exits with status `3`. Because connector secrets are not transported by solutions, re-enter the current client secret after this final import. Create or repair the delegated connection, select it for the imported MCP tool, validate the connection in Copilot Studio, and finish without rebuilding the package:

```bash
export MCMC_AUTHENTICATION_REPAIRED=true
msft-mcmc-mcs/deploy.sh --stage verify "${native_args[@]}"
```

Use the corresponding Public Gateway values and `/gateway/mcp` route for the gateway variant. The script rejects matrix mismatches, malformed inputs, Office AI-managed targets, duplicate bootstrap attempts, missing resume targets, partial solution/agent state, secret-like deployment-settings keys, and an unexpected imported graph. `PermissionBlockedByOfficeAI` requires a different target environment. PAC 2.12.2 `copilot status` is not used because it fails on the imported component schema; verification uses supported solution and Dataverse reads. With the current trial, leave publishing disabled and validate in Preview.

For teardown of a disposable test target, remove each solution by unique name. Unmanaged solution deletion can leave the agent record behind, so remove any remaining agent by schema name:

```bash
pac solution delete --environment "$MCMC_POWER_PLATFORM_ENVIRONMENT" --solution-name MCMCPublicNativeAgent
pac solution delete --environment "$MCMC_POWER_PLATFORM_ENVIRONMENT" --solution-name MCMCPublicGatewayAgent
pac copilot delete --environment "$MCMC_POWER_PLATFORM_ENVIRONMENT" --bot mcmc_PublicNative --confirm
pac copilot delete --environment "$MCMC_POWER_PLATFORM_ENVIRONMENT" --bot mcmc_PublicGateway --confirm
rm -rf .artifacts/mcmc003
```

Unmanaged solution deletion can also leave custom connectors behind. In Power Apps, select the target environment, open **More** > **Discover all** > **Custom connectors**, and delete the two MCMC connectors if they remain. Then open **Connections** and delete the obsolete delegated connections as the user who owns them; a managed-identity PAC profile cannot delete user-owned connections. Confirm that the solutions, agents, custom connectors, and connections are absent before recreating the agents.

#### Manually Recreate the Copilot Studio Agents

In the target Dataverse-enabled environment, create two agents named `MCMC Public Native` and `MCMC Public Gateway`. Enable generative orchestration and give each agent these instructions:

```text
You are the MCMC customer demonstration agent. Use the connected MCP tools as the only source of customer data.

Use list_customers when the user asks to list, show, count, or summarize the customers they can access. Use get_customer when the user supplies a customer ID or asks for one specific customer.

Return only customer data provided by the selected tool. Never invent customers, identifiers, attributes, permissions, or tool results. If a tool rejects the request, returns an error, or is unavailable, state that the customer data could not be retrieved and do not fabricate an answer.
```

Add exactly one OAuth-protected Streamable HTTP MCP server to each agent. Use **Tools** > **Add a tool** > **New tool** > **Model Context Protocol** with:

In **`<agent-display-name>`**, use **Tools** > **Add a tool** > **New tool** > **Model Context Protocol** with:

- Server name: `<connector-display-name>`
- Description: `<description-of-the-data-and-oauth-enforcement-boundary>`
- Server URL: `<mcp-server-url>`
- Authentication: **OAuth 2.0** > **Manual**
- Client ID: `<connector-client-id>`
- Client secret: read `<connector-client-secret-variable>` directly from the approved local secret source
- Authorization URL: `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize`
- Token URL template: `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token`
- Refresh URL: `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token`
- Scopes: `<fully-qualified-delegated-scope>`

Configure and validate the connection:

1. Confirm that the agent name, instructions, and generative orchestration setting match the values above.
2. Add the agent's single MCP tool and create a new connection using the values above.
3. Enter the client secret directly in Copilot Studio. Never place it in source control, deployment settings, command-line arguments, or documentation.
4. Save the connector definition and copy the generated callback URI. The URI is specific to the connector and target Power Platform environment.
5. Add the callback URI to the matching entry in `entra_mcp_connector_redirect_uris`, run a Terraform plan, verify that only the intended application registration changes, and apply it.
6. Return to Copilot Studio, create or repair the connection, and complete Microsoft Entra sign-in and delegated consent.
7. Confirm that the expected MCP tools are discovered, enable the MCP server master switch, and save the agent.
8. In Preview, ask `List all customers.` and `Get customer CUST-1001.` Verify that requests use only the agent variant's designated endpoint.
9. Verify Native returns only records authorized for the signed-in user. Verify Gateway returns all four demonstration customers for James, Jane, and the deployment administrator, while Bill receives `403 Forbidden`.

For the current public MCMC variants, use the following Terraform outputs and local secret variables:

| Setting | Public Native | Public Gateway |
| --- | --- | --- |
| Agent | `MCMC Public Native` | `MCMC Public Gateway` |
| Connector | `MCMC Public Native MCP` | `MCMC Public Gateway MCP` |
| Description | `Retrieves customer records through the APIM route where the MCP server validates the delegated user token.` | `Retrieves customer records through the APIM route where the gateway validates the delegated user token and customer-administrator group membership.` |
| MCP server URL | `api_management_native_mcp_url` | `api_management_gateway_mcp_url` |
| Client ID | `entra_mcp_connector_client_ids["public_native"]` | `entra_mcp_connector_client_ids["public_gateway"]` |
| Client secret | `MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_SECRET` | `MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_SECRET` |
| Callback input | `entra_mcp_connector_redirect_uris["public_native"]` | `entra_mcp_connector_redirect_uris["public_gateway"]` |
| OAuth enforcement | MCP service | API Management gateway |

Both variants use `entra_tenant_id` for the tenant-specific authorization, token, and refresh URLs and `entra_mcp_delegated_scope` for the scope. See [Extend your agent with Model Context Protocol](https://learn.microsoft.com/microsoft-copilot-studio/agent-extend-action-mcp) for the Microsoft Copilot Studio MCP workflow.

The gateway route additionally requires the `groups` claim to contain the group identified by the `entra_customer_admin_group_id` Foundation output. Terraform manages the `mcmc-customer-admins` security group with James, Jane, and the deployment administrator as members; Bill is deliberately excluded. APIM returns `403 Forbidden` for an authenticated nonmember without invoking the trusted backend. After changing group membership or token group-claim settings, reauthenticate the Copilot Studio connection so it obtains a fresh access token.

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

The deployed public routes are:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user james --url https://example-apim.azure-api.net/native/mcp

uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user james --url https://example-apim.azure-api.net/gateway/mcp
```

The native route returns only the selected user's authorized customers. The gateway route proves APIM token validation against the trusted service and returns the complete fictitious catalog for every valid scoped demonstration user.

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

Delete the two obsolete delegated connector connections from the `MCMC Import Test` environment in Power Apps, then manually recreate and validate the two agents in Copilot Studio Preview using the procedure above. The imported solutions, agents, custom connectors, connection references, and generated local deployment settings have already been removed; the development golden agents and Azure infrastructure remain intact.