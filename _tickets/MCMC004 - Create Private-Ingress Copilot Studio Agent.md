---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC004
aliases:
  - MCMC004
name: Create Private-Ingress Copilot Studio Agent
ticket_status: "[[Backlog]]"
---
# Specification

Create and configure a Microsoft Copilot Studio agent that reaches the governed MCP endpoints through Power Platform private virtual network connectivity and an internal APIM path.

Reuse both MCP authentication patterns established by `MCMC001` and `MCMC002`. The complete Copilot Studio-to-APIM path for this architecture must use private ingress, and neither APIM nor the MCP backends may require a public application endpoint.

Validate prerequisites, licensing, regional availability, DNS, routing, and isolation before configuring the agent. Preserve OAuth authorization in addition to private network controls.

# Technical Solution

Configure Power Platform virtual network connectivity for the selected environment and integrate it with the Azure virtual network containing APIM and the MCP backends. Configure private DNS and routing so Copilot Studio can resolve and reach internal APIM endpoints.

Use the reusable APIM policies and MCP deployments created by the preceding tickets. Configure the Copilot Studio agent with both MCP routes and validate native OAuth token pass-through and APIM `validate-jwt` enforcement over the private path.

Use infrastructure as code where Power Platform and Azure providers support the required resources. Document any configuration that must be completed manually in the Power Platform or Copilot Studio administration interfaces.

# Definition of Done

- Power Platform private virtual network prerequisites, licensing, and regional support are confirmed.
- Power Platform virtual network connectivity is configured for the target environment.
- Copilot Studio privately resolves and reaches the internal APIM endpoint.
- Both MCP authentication patterns are configured as agent tools over private ingress.
- The agent discovers and invokes the expected tools through both routes.
- OAuth enforcement remains effective for the native and APIM-enforced patterns.
- Internal APIM and both MCP backends are inaccessible through public application endpoints.
- DNS, routing, authorization failures, and end-to-end request correlation are validated.
- The complete flow is tested in Copilot Studio Preview or the licensed equivalent available during implementation.
- Automated and manual configuration steps, operational constraints, and teardown procedures are documented.

# Execution Plan

TODO