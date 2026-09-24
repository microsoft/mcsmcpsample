---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC002
aliases:
  - MCMC002
name: Provision and Configure Azure API Management
ticket_status: "[[Backlog]]"
---
# Specification

Create Terraform that provisions and configures Azure API Management (APIM) as the governed boundary between Microsoft Copilot Studio and the two private Azure Container Apps deployments created by `MCMC001`.

Expose separate MCP routes for the two authentication patterns:

- Pass the OAuth bearer token through to the `entra` deployment for native validation.
- Apply the APIM `validate-jwt` policy before forwarding approved requests to the `trusted-proxy` deployment.

The APIM design must support the public-ingress architecture first and provide a reusable foundation for the later Power Platform private-ingress architecture. APIM must reach both MCP backends over private networking without exposing either backend directly to the public internet.

# Technical Solution

Use Terraform to provision APIM, required networking, private DNS integration, identities, diagnostics, APIs, operations, backends, named values, and policies.

Configure Microsoft Entra ID token validation for issuer, audience, lifetime, and delegated scope. Preserve MCP Streamable HTTP behavior and apply shared controls for TLS, throttling, request limits, timeouts, correlation identifiers, and sanitized diagnostics.

Design Terraform modules and variables so the public APIM endpoint can be used by `MCMC003` and the private APIM path can be used by `MCMC004` without duplicating policy definitions.

# Definition of Done

- Terraform provisions APIM and its required networking and monitoring dependencies.
- APIM privately resolves and reaches both MCP deployments from `MCMC001`.
- The native OAuth route passes the bearer token through without replacing it.
- The APIM-enforced route validates token signature, issuer, audience, lifetime, and required delegated scope with `validate-jwt`.
- Missing, invalid, expired, incorrectly scoped, and incorrectly targeted tokens are rejected as designed.
- The trusted-proxy backend cannot be reached through a path that bypasses APIM authentication.
- MCP discovery and tool invocation work through both APIM routes.
- Shared gateway controls preserve MCP Streamable HTTP behavior.
- Diagnostics correlate APIM and backend requests without logging credentials or access tokens.
- The Terraform design supports public and private ingress configurations.
- Terraform validation and deployment tests pass.
- Deployment and teardown procedures are documented.

# Execution Plan

TODO