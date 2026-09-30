# Copilot Studio MCP Demonstration

This project demonstrates Microsoft Copilot Studio connecting through Azure API Management (APIM) to Model Context Protocol (MCP) servers hosted on Azure Container Apps. See [Vision.md](Vision.md) for the target public- and private-ingress architectures.

## Validated Learnings

The following findings are listed in reverse chronological order.

1. On 2026-09-27, `MCMC Import Test` was converted to a Managed Environment and associated with the `mcmc-private-connectivity` network-injection enterprise policy. The administration history reported `New Network Injection Policy` as `Succeeded`. A temporary custom connector in that environment reached both private APIM protected-resource metadata endpoints and received `200`, proving that Power Platform connector traffic can resolve and traverse the private path.
2. The first request from the temporary connector returned `503 Container Allocation Successful` with `Retry-After: 60`. This is the expected VNet-injected connector container cold start; retrying after allocation completed succeeded without an infrastructure change.
3. On 2026-09-26, Standard v2 APIM exposed separate OAuth-governed Streamable HTTP routes at `/native/mcp` and `/gateway/mcp`, with RFC 9728 protected-resource metadata for each. The temporary subscription-key route was removed after validation.
4. Independent device-code runs for James, Jane, and Bill discovered and invoked both tools through both routes. Native mode enforces the immutable-`oid` access matrix. Gateway mode validates tokens and requires membership in the Terraform-managed `mcmc-customer-admins` security group before returning the intentionally unfiltered trusted catalog.
5. Missing, malformed, and wrong-audience tokens returned `401`. A real request body over 1 MiB returned `413`, and gateway-generated error responses preserved sanitized correlation identifiers.
6. Both Container Apps allow ingress only from the delegated APIM subnet. A cross-backend request from a Container App replica returned `403`, and neither backend hostname resolves through public DNS.
7. APIM gateway logs and metrics flow to the existing Log Analytics workspace without request or response bodies. Correlation identifiers join APIM and sanitized backend completion telemetry without exposing authorization headers, tokens, credentials, or customer payloads.
8. On 2026-09-25, the licensed-tenant `MCP Capability Test` agent proved Copilot Studio compatibility through the former subscription-key MCP route. It discovered and invoked both tools despite displaying `We couldn't load this tool's contract`; that temporary tool connection and route were subsequently removed.
9. The Copilot Studio trial supports creating, configuring, previewing, and testing agents, but it does not support publishing them. The trial product provides tenant capacity and cannot be assigned to a user or device. Publishing requires an appropriate paid subscription or supported pay-as-you-go arrangement.
10. Copilot Studio supports MCP servers directly as agent tools. A connection requires a server name, description, and server URL; the interface presents `/mcp` as the expected endpoint pattern.
11. MCP connections support no authentication, API-key authentication, and OAuth 2.0.
12. OAuth 2.0 supports dynamic configuration with discovery, dynamic configuration, and manual configuration.
13. Manual OAuth requires a client ID, client secret, authorization URL, token URL, refresh-token URL, and scopes.
14. Dynamic OAuth with discovery requires only the MCP server URL and delegates metadata discovery to Copilot Studio. Manual OAuth remains the predictable initial option for a Microsoft Entra ID integration.
15. Connector and MCP catalog loading errors do not necessarily prevent adding a new MCP server through **Add** > **Model Context Protocol (MCP)**.
16. Dataverse and Copilot Studio provisioning are eventually consistent. Dataverse can report `Ready` before the Copilot Studio solution is fully available; refreshing after provisioning completes can resolve agent-creation errors.
17. The existing `Contoso (default)` Power Platform environment is usable. Dataverse has been provisioned, and the `MCP Capability Test` agent has been created.
18. The current user has sufficient administrative access: Global Administrator in Microsoft Entra ID, Azure Owner at management-group scope, and Environment Maker plus Basic User roles in Dataverse. A separate Copilot Studio tenant is not required.

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
- Wait for the assignment to propagate, then refresh the environment. Self-elevation is aud##### MCMC Public Gateway

- Agent name:

```text
MCMC Public Gateway
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Public Gateway MCP test3
```

- Description:

```text
Retrieves customer records through the public APIM route where the gateway validates delegated access.
```

- MCP server URL:

```text
https://example-apim.azure-api.net/gateway/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
API Management gateway
```

##### MCMC Public Native

- Agent name:

```text
MCMC Public Native
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Public Native MCP test3
```

- Description:

```text
Retrieves customer records through the public APIM route where the MCP server validates delegated access.
```

- MCP server URL:

```text
https://example-apim.azure-api.net/native/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
MCP service
```

##### MCMC Private Gateway

- Agent name:

```text
MCMC Private Gateway
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Private Gateway MCP test3
```

- Description:

```text
Retrieves customer records through the private APIM route where the gateway validates delegated access.
```

- MCP server URL:

```text
https://example-apim-private.azure-api.net/gateway/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PRIVATE_GATEWAY_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PRIVATE_GATEWAY_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
API Management gateway
```

##### MCMC Private Native

- Agent name:

```text
MCMC Private Native
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Private Native MCP test3
```

- Description:

```text
Retrieves customer records through the private APIM route where the MCP server validates delegated access.
```

- MCP server URL:

```text
https://example-apim-private.azure-api.net/native/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PRIVATE_NATIVE_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PRIVATE_NATIVE_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
MCP service
```

ted in Microsoft Purview.

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

#### Manually Enable and Validate Private Power Platform Networking

The private Azure topology is deployed before these manual steps. It includes the private Standard v2 APIM instance, its private endpoint and `privatelink.azure-api.net` private DNS zone, paired Power Platform virtual networks in `japaneast` and `japanwest`, delegated subnets, bidirectional peering to the deployment virtual network, and the `mcmc-private-connectivity` network-injection enterprise policy. Complete the following steps in the `MCMC Import Test` Sandbox environment.

Enable Managed Environments:

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com/).
2. Select **Manage** > **Environments** > **MCMC Import Test**.
3. Select **Edit managed environments** and enable Managed Environments.
4. Return to the environment details page and confirm **Managed environments** shows **Yes**.
5. Open **History** and confirm **Enable Managed Environment** has status **Succeeded**.

Associate the network-injection enterprise policy:

1. In the far-left Power Platform admin center navigation rail, select the **Security** shield icon. This is a top-level feature area and is not part of the expanded **Manage** menu.
2. Select **Data and privacy** > **Azure Virtual Network policies**.
3. Select the `MCMC Import Test` environment and the `mcmc-private-connectivity` policy, then select **Save**.
4. Return to **Manage** > **Environments** > **MCMC Import Test** and open **History**.
5. Confirm **New Network Injection Policy** has status **Succeeded**. Enabling or changing subnet injection can cause up to 30 minutes of temporary connection instability while delegated connector containers initialize.

Create a temporary connector to validate the private path independently of MCP OAuth:

1. Sign in to [Power Apps](https://make.powerapps.com/) and select the `MCMC Import Test` environment.
2. Open **Solutions**, create or open an unmanaged test solution, and select **New** > **Automation** > **Custom connector** > **Create from blank**.
3. Name the connector `MCMC Private APIM Connectivity Test`.
4. On **General**, set the scheme to `HTTPS`, the host to `example-apim-private.azure-api.net`, and the base URL to `/`. Do not configure an on-premises data gateway.
5. On **Security**, select **No authentication**. This connector calls only the route-specific protected-resource metadata endpoints, which intentionally require no bearer token.
6. On **Definition**, create an action named `Get Native OAuth metadata` with operation ID `GetNativeOAuthMetadata`. Under **Request**, select **Import from sample**, choose `GET`, and enter:

	```text
	https://example-apim-private.azure-api.net/.well-known/oauth-protected-resource/native/mcp
	```

7. Create a second action named `Get Gateway OAuth metadata` with operation ID `GetGatewayOAuthMetadata`. Import this `GET` URL:

	```text
	https://example-apim-private.azure-api.net/.well-known/oauth-protected-resource/gateway/mcp
	```

8. Confirm the definition has no validation errors and select **Create connector** or **Update connector**.
9. On **Test**, select **New connection** and create the no-authentication connection. Return to the connector, refresh the connection list, and test each operation.

The first operation can return this temporary response while Power Platform allocates its VNet-injected connector container:

```text
503 Container Allocation Successful
Container allocated - .../PConnector/ExtnCtrDelegatedSvc. Please re-try.
Retry-After: 60
```

This response is a successful allocation signal rather than an APIM failure. Wait at least 60 seconds, refresh the connector test page or connection to avoid a cached response, and retry. The completed validation must produce:

- HTTP `200` from `GetNativeOAuthMetadata`, with `resource` set to the private `/native/mcp` URL.
- HTTP `200` from `GetGatewayOAuthMetadata`, with `resource` set to the private `/gateway/mcp` URL.
- The tenant-specific Microsoft Entra issuer in `authorization_servers` and the expected delegated scope in `scopes_supported` for both responses.

These results prove that a connector running in `MCMC Import Test` can resolve the private APIM hostname through Private Link and reach both governed routes without public fallback. The private APIM hostname must still return `403` when requested from the public internet. Keep the temporary connector until the policy-association and connector-test evidence is recorded, then remove its connection and connector before final cleanup.

#### Manually Recreate the Copilot Studio Agents

Create the four agents in the `MCMC Test 3` Sandbox environment:

- Environment ID: `22222222-2222-4222-8222-222222222222`
- Dataverse URL: `https://example.crm7.dynamics.com/`
- Power Platform region: Japan West
- Security group: `Meridian Account Team`
- Private-network enterprise policy: `mcmc-private-connectivity`

Before configuring the private agents, enable Managed Environments for `MCMC Test 3`, associate `mcmc-private-connectivity`, and wait for the network-injection operation to succeed. The public agents do not depend on this association.

Enable generative orchestration on every agent and paste these exact instructions:

```text
You are the MCMC customer demonstration agent. Use the connected MCP tools as the only source of customer data.

Use list_accessible_customers when the user asks to list, show, count, or summarize the customers they can access. Use get_accessible_customer when the user supplies a customer ID or asks for one specific customer.

Return only customer data provided by the selected tool. Never invent customers, identifiers, attributes, permissions, or tool results. If a tool rejects the request, returns an error, or is unavailable, state that the customer data could not be retrieved and do not fabricate an answer.
```

Add exactly one OAuth-protected Streamable HTTP MCP server to each agent through **Tools** > **Add a tool** > **New tool** > **Model Context Protocol**. Use a new connector name if Power Platform reports that a previously deleted display name is still reserved.

##### MCMC Public Gateway

- Agent name:

```text
MCMC Public Gateway
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Public Gateway MCP test3
```

- Description:

```text
Retrieves customer records through the public APIM route where the gateway validates delegated access.
```

- MCP server URL:

```text
https://example-apim.azure-api.net/gateway/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PUBLIC_GATEWAY_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
API Management gateway
```

##### MCMC Public Native

- Agent name:

```text
MCMC Public Native
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Public Native MCP test3
```

- Description:

```text
Retrieves customer records through the public APIM route where the MCP server validates delegated access.
```

- MCP server URL:

```text
https://example-apim.azure-api.net/native/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PUBLIC_NATIVE_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
MCP service
```

##### MCMC Private Gateway

- Agent name:

```text
MCMC Private Gateway
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Private Gateway MCP test3
```

- Description:

```text
Retrieves customer records through the private APIM route where the gateway validates delegated access.
```

- MCP server URL:

```text
https://example-apim-private.azure-api.net/gateway/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PRIVATE_GATEWAY_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PRIVATE_GATEWAY_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
API Management gateway
```

##### MCMC Private Native

- Agent name:

```text
MCMC Private Native
```

- Enable generative orchestration:

```text
Yes
```

- Instructions:

```text
Use the exact shared instructions above.
```

- MCP server name:

```text
MCMC Private Native MCP test3
```

- Description:

```text
Retrieves customer records through the private APIM route where the MCP server validates delegated access.
```

- MCP server URL:

```text
https://example-apim-private.azure-api.net/native/mcp
```

- Authentication:

```text
OAuth 2.0 > Manual
```

- Client ID source:

```text
MCMC_PRIVATE_NATIVE_CONNECTOR_CLIENT_ID
```

- Client secret source:

```text
MCMC_PRIVATE_NATIVE_CONNECTOR_CLIENT_SECRET
```

- Authorization URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/authorize
```

- Token URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Refresh URL:

```text
https://login.microsoftonline.com/11111111-1111-4111-8111-111111111111/oauth2/v2.0/token
```

- Scopes:

```text
api://example.onmicrosoft.com/mcmc-mcp/access_as_user offline_access
```

- PKCE:

```text
Enabled, if Copilot Studio exposes the option
```

- Entra implicit and hybrid flows:

```text
Leave Access tokens and ID tokens unchecked
```

- OAuth enforcement boundary:

```text
MCP service
```

Read each client ID and secret from the repository-root `.env` key shown in that agent's section. Do not copy credential values into this document, source control, terminal arguments, or screenshots. Enable PKCE if Copilot Studio exposes that option. Leave the Entra **Access tokens** and **ID tokens** implicit-flow options disabled.

Configure and validate the connection:

1. Save the MCP definition and copy its complete generated callback URI, beginning with `https://global.consent.azure-apim.net/redirect/`.
2. Open the Entra app registration identified by that row's client ID and add the callback as a **Web** redirect URI.
3. Return to Copilot Studio, create the connection, and complete Microsoft Entra sign-in and delegated consent.
4. Open the MCP tool and verify that `List accessible customers` and `Get accessible customer` are discovered.
5. Enable **Allow all**, save the agent, and start a new test session.
6. Ask `List the customers I can access.` and `Get customer CUST-1001.`
7. Verify Native returns only records authorized for the signed-in user. Verify Gateway returns all four demonstration customers for James, Jane, and the deployment administrator, while Bill receives `403 Forbidden`.

See [Extend your agent with Model Context Protocol](https://learn.microsoft.com/microsoft-copilot-studio/agent-extend-action-mcp) for the Microsoft Copilot Studio MCP workflow.

The gateway route additionally requires the `groups` claim to contain the group identified by the `entra_customer_admin_group_id` Foundation output. Terraform manages the `mcmc-customer-admins` security group with James, Jane, and the deployment administrator as members; Bill is deliberately excluded. APIM returns `403 Forbidden` for an authenticated nonmember without invoking the trusted backend. After changing group membership or token group-claim settings, reauthenticate the Copilot Studio connection so it obtains a fresh access token.

## CLI Usage

The Python demonstration CLI is installed as `mcp` from the `msft-mcmc-mcp-service` project. Run these examples from the repository root so the CLI uses the gitignored root `.env`. The project configures `uv` to resolve Python packages through the corporate package proxy.

The CLI supports device-code authentication as its interactive flow. It does not accept passwords or provide a username/password flow. Before a first device-code run, complete any required initial password change for the selected disposable user in a browser.

### Run as Each User

Select the authentication boundary with the endpoint path: `/native/mcp` makes the MCP service validate and authorize the token, while `/gateway/mcp` makes APIM validate the token and require membership in `mcmc-customer-admins` before invoking the trusted backend.

James receives `CUST-1001` and `CUST-1002` through Native auth, and the complete four-customer catalog through Gateway auth:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user james --url https://example-apim.azure-api.net/native/mcp
```

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user james --url https://example-apim.azure-api.net/gateway/mcp
```

Jane receives `CUST-1003` and `CUST-1004` through Native auth, and the complete four-customer catalog through Gateway auth:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user jane --url https://example-apim.azure-api.net/native/mcp
```

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user jane --url https://example-apim.azure-api.net/gateway/mcp
```

Bill receives an empty `customers` array through Native auth. Gateway auth rejects Bill with `403 Forbidden` because he is deliberately excluded from `mcmc-customer-admins`:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user bill --url https://example-apim.azure-api.net/native/mcp
```

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service \
	mcp --user bill --url https://example-apim.azure-api.net/gateway/mcp
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

Private Power Platform networking is now validated from `MCMC Import Test`: Managed Environments and the network-injection association both succeeded, and both private APIM metadata operations returned `200` through the temporary custom connector. Manually create and validate `MCMC Private Native` and `MCMC Private Gateway` in Copilot Studio Preview using the private `/native/mcp` and `/gateway/mcp` URLs. Preserve the existing public agents and leave publishing disabled unless suitable capacity is available.