---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC004
aliases:
  - MCMC004
name: Create Private-Ingress Copilot Studio Agents
ticket_status: "[[Backlog]]"
---
# Specification

Create and configure two Microsoft Copilot Studio agents that reach the governed MCP endpoints through Power Platform private virtual network connectivity and an internal APIM path.

Create one agent for each MCP authentication pattern established by `MCMC001` and `MCMC002`, with exactly one MCP server connection per agent:

- **MCMC Private Native** uses the internal APIM route that passes OAuth tokens through to the MCP server for native validation.
- **MCMC Private Gateway** uses the internal APIM route that enforces OAuth with `validate-jwt` before forwarding to the MCP server without native OAuth.

These agents complete the four-agent matrix started by the MCMC Public Native and MCMC Public Gateway agents in `MCMC003`. The complete Copilot Studio-to-APIM path for both private variants must use private ingress, and neither APIM nor the MCP backends may require a public application endpoint.

Validate prerequisites, licensing, regional availability, DNS, routing, and isolation before configuring the agent. Preserve OAuth authorization in addition to private network controls.

# Technical Solution

Configure Power Platform virtual network connectivity for the selected environment and integrate it with the Azure virtual network containing APIM and the MCP backends. Configure private DNS and routing so Copilot Studio can resolve and reach internal APIM endpoints.

Reuse the APIM policies and MCP deployments created by the preceding tickets and the two golden-agent patterns and matrix-driven shell workflow created by `MCMC003`. Create separate Private Native and Private Gateway variants rather than combining both MCP connections in one agent. Parameterize the agent display name, schema name, internal MCP URL, ingress type, OAuth enforcement type, and target environment while preserving shared instructions and packaging conventions.

Configure each private agent with only its designated internal APIM route. Validate native OAuth token pass-through with the Private Native agent and APIM `validate-jwt` enforcement with the Private Gateway agent. Prove that replacing the public endpoint with an internal endpoint does not change the OAuth contract or introduce public fallback.

Use infrastructure as code where Power Platform and Azure providers support the required resources. Extend the supported `pac` shell workflow for agent packaging, solution import, provisioning checks, and conditional publishing. Document any network, OAuth connection, consent, or Copilot Studio configuration that must be completed manually.

# Definition of Done

- Power Platform private virtual network prerequisites, licensing, and regional support are confirmed.
- Power Platform virtual network connectivity is configured for the target environment.
- Copilot Studio privately resolves and reaches the internal APIM endpoint.
- Separate MCMC Private Native and MCMC Private Gateway agents exist, each with exactly one MCP server connection to its designated internal APIM route.
- The two private agents reuse the golden-agent patterns, shared instructions, packaging conventions, and matrix-driven shell workflow from `MCMC003`.
- Each agent discovers and invokes the expected tools only through its designated private route.
- OAuth enforcement remains effective for the native and APIM-enforced patterns without public fallback.
- Internal APIM and both MCP backends are inaccessible through public application endpoints.
- DNS, routing, authorization failures, and end-to-end request correlation are validated independently for both agents.
- The full four-agent matrix contains one isolated agent for each public/private ingress and native/gateway OAuth enforcement combination.
- Both private flows are tested independently in Copilot Studio Preview or the licensed equivalent available during implementation.
- Automated and manual configuration steps, operational constraints, and teardown procedures are documented.

# Execution Plan

## Phase 1 - Confirm Private Connectivity and Matrix Inputs

- [ ] Confirm Power Platform virtual network prerequisites, licensing, regional availability, environment permissions, and publishing constraints.
- [ ] Define stable names for the Private Native and Private Gateway agents, solutions, connectors, and connection references.
- [ ] Extend the MCMC003 matrix input contract with the internal MCP URLs, private ingress type, target environment, DNS, and network identifiers.
- [ ] Record which private-network and OAuth operations are supported for automation and which require operator action.

## Phase 2 - Provision and Validate Private APIM Connectivity

- [ ] Configure Power Platform virtual network connectivity to the Azure virtual network containing the internal APIM endpoint.
- [ ] Configure private DNS and routing so Copilot Studio resolves and reaches internal APIM without a public fallback.
- [ ] Verify that both internal MCP routes are reachable from the Power Platform environment and inaccessible through public application endpoints.
- [ ] Validate that OAuth discovery, authorization, token exchange, and callback traffic follow their documented paths without weakening private MCP ingress.

## Phase 3 - Create the Private Agent Variants

- [ ] Reuse the MCMC003 Public Native golden-agent pattern to create MCMC Private Native with only the internal native-validation MCP connection.
- [ ] Reuse the MCMC003 Public Gateway golden-agent pattern to create MCMC Private Gateway with only the internal gateway-validation MCP connection.
- [ ] Preserve shared deterministic instructions and generative orchestration while parameterizing only the matrix-specific names, endpoint, ingress, and OAuth enforcement values.
- [ ] Configure environment-specific OAuth connections, callback URIs, consent, and authentication settings without placing secrets in source control.

## Phase 4 - Extend and Run the Shell Deployment

- [ ] Extend the matrix-driven shell workflow to validate private agent inputs and prerequisites before making changes.
- [ ] Use supported `pac` commands to package, import, verify, and, where permitted, publish each private agent variant.
- [ ] Retain safe pause-and-resume behavior for network, OAuth, consent, and authentication steps that require operator action.
- [ ] Prove reruns identify each private agent by stable schema name and do not alter either public agent from `MCMC003`.

## Phase 5 - Validate and Document the Four-Agent Matrix

- [ ] Exercise successful and rejected requests independently through the Private Native and Private Gateway agents.
- [ ] Prove each private agent uses only its designated internal route and preserves the intended OAuth enforcement boundary.
- [ ] Correlate each request through internal APIM to the correct private MCP deployment and validate DNS, routing, and isolation failures.
- [ ] Verify the complete matrix contains exactly the Public Native, Public Gateway, Private Native, and Private Gateway agents with no cross-wired MCP connections.
- [ ] Document prerequisites, matrix inputs, automated and manual steps, authentication, secret handling, deployment, reruns, troubleshooting, operational constraints, and teardown.