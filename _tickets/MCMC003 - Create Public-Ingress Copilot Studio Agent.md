---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC003
aliases:
  - MCMC003
name: Create Public-Ingress Copilot Studio Agent
ticket_status: "[[Backlog]]"
---
# Specification

Create and configure a Microsoft Copilot Studio agent that connects over the public internet to the governed MCP endpoints exposed by APIM in `MCMC002`.

Add both MCP authentication patterns as tools:

- The APIM route that passes OAuth tokens through to the MCP server for native validation.
- The APIM route that enforces OAuth with `validate-jwt` before forwarding to the MCP server without native OAuth.

Configure agent instructions so the deterministic demonstration tools are selected predictably. Validate the agent in Copilot Studio Preview because the current Copilot Studio trial supports creation and testing but not publishing.

# Technical Solution

Use Copilot Studio's native MCP tool integration and OAuth 2.0 configuration. Begin with manual OAuth configuration against Microsoft Entra ID and evaluate dynamic discovery after the manual flow succeeds.

Configure the required Microsoft Entra ID API and client registrations, delegated scopes, redirect URI, consent, and client credentials. Do not store client secrets in the repository.

Exercise both APIM routes from Copilot Studio Preview and correlate each request through APIM and the corresponding private MCP deployment.

# Definition of Done

- A Copilot Studio agent exists in the Dataverse-enabled Power Platform environment.
- Both public APIM MCP endpoints are configured as agent tools.
- Microsoft Entra ID OAuth succeeds for both routes.
- The agent discovers and invokes the expected deterministic tools through both authentication patterns.
- Agent instructions result in predictable tool selection and do not fabricate failed tool results.
- Missing, invalid, or insufficient authorization is surfaced without exposing sensitive details.
- Requests can be correlated from Copilot Studio through APIM to the correct MCP deployment.
- Public access is limited to the governed APIM endpoint; neither MCP backend is publicly reachable.
- The complete flow is validated in Copilot Studio Preview.
- Publishing requirements and the current trial limitation are documented.

# Execution Plan

TODO