---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC004
aliases:
  - MCMC004
name: Create Private-Ingress Copilot Studio Agents
ticket_status: "[[In Progress]]"
---
# Specification

Create and configure two Microsoft Copilot Studio agents that reach the governed MCP endpoints through Power Platform private virtual network connectivity and an internal APIM path.

Create one agent for each MCP authentication pattern established by `MCMC001` and `MCMC002`, with exactly one MCP server connection per agent:

- **MCMC Private Native** uses the internal APIM route that passes OAuth tokens through to the MCP server for native validation.
- **MCMC Private Gateway** uses the internal APIM route that enforces OAuth with `validate-jwt` before forwarding to the MCP server without native OAuth.

These agents complete the four-agent matrix started by the MCMC Public Native and MCMC Public Gateway agents in `MCMC003`. The complete Copilot Studio-to-APIM path for both private variants must use private ingress, and neither APIM nor the MCP backends may require a public application endpoint.

Validate prerequisites, licensing, regional availability, DNS, routing, and isolation before configuring the agent. Preserve OAuth authorization in addition to private network controls.

# Technical Solution

Configure Power Platform virtual network connectivity for the selected environment and integrate it with the Azure virtual network containing APIM and the MCP backends. Configure private DNS and routing so Copilot Studio can resolve and reach the APIM private endpoint.

Keep the existing Standard v2 APIM instance and its public ingress unchanged for the MCMC003 agents. Add a second Standard v2 APIM instance with a dedicated outbound virtual network integration subnet, an inbound private endpoint, and disabled public network access. Power Platform virtual network connectivity reaches the private APIM instance through Private Link. Reuse the APIM policies and MCP deployments created by the preceding tickets so both APIM instances retain the same OAuth enforcement boundaries without requiring a custom domain, certificate, or public reverse proxy.

Reuse the two golden-agent patterns created by `MCMC003`, but keep its deployment automation deferred. Create the Private Native and Private Gateway agents manually rather than combining both MCP connections in one agent. Preserve shared instructions and packaging conventions while parameterizing the agent names, private MCP URL, ingress type, OAuth enforcement type, and target environment.

Configure each private agent with only its designated internal APIM route. Validate native OAuth token pass-through with the Private Native agent and APIM `validate-jwt` enforcement with the Private Gateway agent. Prove that replacing the public endpoint with an internal endpoint does not change the OAuth contract or introduce public fallback.

Use infrastructure as code for Azure networking, both APIM instances, Private Link, DNS, diagnostics, and the Power Platform network-injection enterprise policy. Use supported Power Platform administration interfaces for environment association and manual Copilot Studio configuration. Document each interactive network, OAuth connection, consent, or agent operation.

# Definition of Done

- Power Platform private virtual network prerequisites, licensing, and regional support are confirmed.
- Power Platform virtual network connectivity is configured for the target environment.
- Copilot Studio privately resolves and reaches the internal APIM endpoint.
- Separate MCMC Private Native and MCMC Private Gateway agents exist, each with exactly one MCP server connection to its designated internal APIM route.
- The two private agents reuse the golden-agent patterns, shared instructions, and packaging conventions from `MCMC003` without depending on its deferred deployment workflow.
- Each agent discovers and invokes the expected tools only through its designated private route.
- OAuth enforcement remains effective for the native and APIM-enforced patterns without public fallback.
- Internal APIM and both MCP backends are inaccessible through public application endpoints.
- DNS, routing, authorization failures, and end-to-end request correlation are validated independently for both agents.
- The full four-agent matrix contains one isolated agent for each public/private ingress and native/gateway OAuth enforcement combination.
- Both private flows are tested independently in Copilot Studio Preview or the licensed equivalent available during implementation.
- Automated and manual configuration steps, operational constraints, and teardown procedures are documented.

# Execution Plan

## Phase 1 - Add the Private API Management Instance

- [x] Define stable names and nonoverlapping address ranges for the private APIM outbound integration subnet, APIM private-endpoint subnet, and private DNS zone without changing the existing public APIM or Container Apps subnets.
- [x] Provision a second Standard v2 APIM instance with a dedicated outbound virtual network integration subnet while preserving the existing public APIM instance and routes.
- [x] Move the inbound `Gateway` private endpoint from the public APIM instance to the private APIM instance.
- [x] Configure and link the `privatelink.azure-api.net` private DNS zone so linked virtual networks resolve only the private APIM gateway hostname to the private endpoint.
- [x] Replicate both MCP APIs, operations, protected-resource metadata endpoints, OAuth policies, diagnostics, correlation behavior, payload limits, streaming settings, and timeouts to the private APIM instance.
- [x] Allow both dedicated APIM outbound integration subnets to reach the private Container Apps without exposing either backend publicly.
- [x] Validate private DNS resolution and both governed MCP routes through the private endpoint before disabling public network access on the private APIM instance.
- [x] Disable public network access on only the private APIM instance and verify its public path is rejected while its private path remains available.
- [x] Verify the existing public APIM routes continue to work without configuration changes and retain the MCMC003 agent URLs.
- [x] Add automated Terraform and live checks for two-instance isolation, private DNS, policy parity, route behavior, and unchanged Container App isolation.
- [x] Record the reviewed plans, staged deployment evidence, and rollback procedure.

## Phase 2 - Prepare Power Platform Virtual Network Connectivity

- [ ] Enable Managed Environments for `MCMC Import Test` and validate its Sandbox licensing, permissions, and custom-connector support; its administration metadata reports Basic governance, the `japan` Power Platform region, and `JPN` Dataverse geography.
- [x] Define equal-sized Power Platform delegated subnets in paired `japaneast` and `japanwest` virtual networks and peer the required network path back to the Sweden Central deployment virtual network.
- [x] Register the required Azure resource providers and delegate the correctly sized regional subnets to `Microsoft.PowerPlatform/enterprisePolicies`.
- [x] Create the `mcmc-private-connectivity` network-injection enterprise policy and grant the deployment administrator read access.
- [ ] Associate the enterprise policy with the target Managed Environment through a supported Power Platform administration interface and verify that provisioning succeeds.
- [ ] Validate private APIM DNS resolution and HTTPS connectivity from a Power Platform custom connector to both MCP metadata endpoints.
- [ ] Validate controlled outbound access to Microsoft Entra authorization and token endpoints and the generated global connector callback endpoint.
- [ ] Record DNS, routing, TLS, policy-association, and connector diagnostics before creating the private agents.

## Phase 3 - Create the Private Agent Variants Manually

- [ ] Create MCMC Private Native with generative orchestration, the shared deterministic instructions, and exactly one MCP connection directly to the private APIM native route.
- [ ] Create MCMC Private Gateway with the same instructions and exactly one MCP connection directly to the private APIM gateway route.
- [ ] Configure manual OAuth with the existing delegated API scope and the appropriate native or gateway connector client registration without storing secrets in source control.
- [ ] Register each generated connector callback URI through Terraform, enter its client secret through Copilot Studio, and complete delegated sign-in and consent.
- [ ] Confirm that each agent discovers only `list_customers` and `get_customer`, enable its MCP server connection, and retain Preview-only operation unless suitable publishing capacity is available.
- [ ] Capture the validated private agent and connector artifacts in source control only after the manual configurations work, without enabling the deferred deployment automation.

## Phase 4 - Validate the Private Agent Paths

- [ ] Exercise successful Native requests as James and Jane and confirm each receives only the customer records assigned to their immutable object identifier.
- [ ] Exercise Native as Bill and confirm the result contains no customer records without exposing sensitive authentication details.
- [ ] Exercise Gateway as James, Jane, and the deployment administrator and confirm each receives the complete demonstration catalog.
- [ ] Exercise Gateway as Bill and confirm APIM returns `403 Forbidden` before invoking the trusted backend.
- [ ] Verify each private agent resolves and uses the private APIM endpoint rather than the public APIM path.
- [ ] Correlate each private-agent request through APIM to the correct Container App while confirming logs omit tokens, credentials, and customer payloads.

## Phase 5 - Complete Four-Agent Validation and Documentation

- [ ] Confirm that the public APIM remains available, the private APIM rejects public requests, and Power Platform private-endpoint requests succeed.
- [ ] Verify that both Container Apps remain unreachable except from the two dedicated APIM outbound integration subnets.
- [ ] Verify that the four-agent matrix contains exactly Public Native, Public Gateway, Private Native, and Private Gateway, each with one correctly wired MCP connection.
- [ ] Re-run successful and rejected authorization cases across all four agents and confirm the intended native or gateway enforcement boundary.
- [ ] Document prerequisites, topology, temporary migration state, matrix values, infrastructure deployment, manual agent changes, authentication, secret handling, validation, troubleshooting, operational constraints, rollback, and ordered teardown.