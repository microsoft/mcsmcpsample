---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC002
aliases:
  - MCMC002
name: Provision and Configure Azure API Management
ticket_status: "[[Done]]"
---
# Specification

Extend the Standard v2 Azure API Management (APIM) service and private outbound network path provisioned by `MCMC001` so APIM becomes the governed boundary between Microsoft Copilot Studio and both private Azure Container Apps deployments.

Expose separate MCP routes for the two authentication patterns:

- Pass the OAuth bearer token through unchanged to `mcmc-mcp-entra` for native validation and immutable-`oid` authorization.
- Apply the APIM `validate-jwt` policy before forwarding approved requests to `mcmc-mcp-trusted`, which intentionally performs no native authentication or user filtering.

Publish both routes through the existing public APIM gateway for `MCMC003`. Keep route definitions and shared policies reusable by the later private APIM ingress work in `MCMC004`, but do not provision the Power Platform private path in this ticket. APIM must continue reaching both backends over the existing virtual network and private DNS path, and neither backend may be directly reachable from the public internet.

Replace the temporary subscription-key-protected trusted route created by `MCMC001` after both OAuth routes have passed live validation. OAuth is the authorization boundary for these routes; an APIM subscription key must not be treated as a substitute for an Entra access token.

# Technical Solution

Evolve the existing Foundation and Application Terraform layers rather than creating another APIM instance or duplicate networking. Foundation owns the shared APIM service, delegated subnet, managed identity, Log Analytics integration, and outputs required by the Application layer. Application owns both route-specific APIs, operations, backend bindings, access policies, diagnostics, and public endpoint outputs.

Use stable, distinct public URL prefixes for the native-validation and APIM-validation routes. Proxy the MCP SDK's protected-resource metadata for the native route and configure `MCP_RESOURCE_SERVER_URL` with its public APIM MCP URL. Publish APIM-owned protected-resource metadata and a standards-compliant `WWW-Authenticate` challenge for the APIM-validation route, because the trusted backend deliberately has no OAuth middleware.

On the native-validation route, preserve the `Authorization` header and let the Entra-mode server validate signature, v2 issuer, API client-ID audience, lifetime, tenant, and the `access_as_user` delegated scope. On the APIM-validation route, use `validate-jwt` with the tenant-specific v2 OpenID configuration, the API client-ID audience, the exact v2 issuer, expiration enforcement, and the required delegated `scp` value. Remove the bearer token before forwarding a validated request to the trusted backend.

Restrict Container App ingress so the delegated APIM subnet is the only application path to the trusted backend, and apply the same governed-boundary restriction to the Entra backend if live validation confirms Container Apps preserves the expected APIM source range. Keep platform health probes operational. Do not use a repository-stored shared secret as the primary backend boundary.

Define shared policy fragments or Terraform-rendered policy content once and compose route-specific authentication behavior around it. Shared controls must preserve stateless MCP Streamable HTTP `GET`, `POST`, and `DELETE` behavior without buffering request or response bodies. They must enforce TLS, bounded request size, throttling, the existing 300-second backend timeout, safe `x-correlation-id` propagation, and sanitized errors. Send APIM platform diagnostics to the existing Log Analytics workspace without logging authorization headers, access tokens, MCP payloads, customer data, or response bodies.

# Definition of Done

- Terraform extends the existing APIM, networking, private DNS, and monitoring foundation without duplicating resources owned by `MCMC001`.
- APIM privately resolves and reaches both MCP deployments from `MCMC001`, while neither backend resolves or responds through a public application endpoint.
- Stable public APIM URLs expose separate native-validation and APIM-validation MCP routes for `MCMC003`.
- The native-validation route publishes correct protected-resource metadata and passes the bearer token through unchanged.
- The APIM-validation route publishes correct protected-resource metadata and challenges unauthorized callers with a standards-compliant `WWW-Authenticate` response.
- The APIM-validation route validates token signature, v2 issuer, API client-ID audience, lifetime, tenant, and required delegated scope with `validate-jwt`, then removes the bearer token before forwarding.
- Missing, invalid, expired, incorrectly scoped, and incorrectly targeted tokens are rejected as designed.
- The trusted backend cannot be reached through an application path that bypasses APIM authentication; the Entra backend remains natively protected and is restricted to the same governed path when compatible with the platform.
- Through the native-validation route, James, Jane, and Bill receive exactly their defined customer results; through the APIM-validation route, all three valid scoped users receive the trusted backend's intentionally unfiltered deterministic dataset.
- MCP initialization, tool discovery, tool invocation, and session deletion work through both routes with Streamable HTTP request and response buffering disabled.
- Shared gateway controls enforce TLS, request limits, throttling, timeouts, correlation identifiers, and sanitized errors without breaking MCP behavior.
- APIM and backend telemetry can be joined by correlation identifier without recording credentials, tokens, MCP arguments, customer payloads, or response bodies.
- The temporary MCMC001 subscription-key route is removed after both OAuth routes pass validation.
- Shared route and policy definitions can be reused for the private APIM ingress configuration in `MCMC004` without duplicating authentication policy bodies.
- Terraform validation and deployment tests pass.
- Deployment and teardown procedures are documented.

# Execution Plan

## Phase 1 - Confirm the Baseline and Contracts

- [x] Revalidate the deployed MCMC001 APIM service, private DNS resolution, backend health, immutable image digest, Entra outputs, and clean Terraform plans.
- [x] Record the native-validation and APIM-validation public route prefixes and their route-specific protected-resource metadata URLs.
- [x] Confirm the Standard v2 policy, diagnostics, throttling, and Container Apps ingress-restriction features against current Microsoft documentation.
- [x] Define a validation matrix covering MCP methods, all token failure modes, all three demonstration users, backend bypass, correlation, and sensitive-data exclusion.

## Phase 2 - Extend the Shared Foundation

- [x] Export the APIM subnet address prefix and existing Log Analytics details required by the Application layer.
- [x] Add only the shared diagnostics or identity configuration that must be owned with the APIM service.
- [x] Update Terragrunt dependencies and typed variables without copying tenant-specific identifiers or secrets into source control.
- [x] Format and validate the Foundation layer, then review a saved Terraform plan before applying it.

## Phase 3 - Implement Reusable APIM Policy Building Blocks

- [x] Define shared policy content for TLS enforcement, request-size limits, throttling, the 300-second unbuffered backend forward, correlation handling, and sanitized errors.
- [x] Define route-specific native bearer pass-through and APIM `validate-jwt` policy content without duplicating the shared controls.
- [x] Configure `validate-jwt` with tenant-specific v2 metadata, exact v2 issuer, API client-ID audience, expiration enforcement, and the `access_as_user` delegated scope.
- [x] Remove the bearer token before forwarding APIM-validated requests to the trusted backend.
- [x] Add focused automated checks that parse the rendered policy XML and assert the required controls, claims, forwarding behavior, and prohibited logging settings.

## Phase 4 - Publish Both Governed MCP Routes

- [x] Replace the temporary root trusted API with distinct native-validation and APIM-validation APIs, backend bindings, and `GET`, `POST`, and `DELETE` MCP operations.
- [x] Expose the required protected-resource metadata operation for the native route and set the Entra Container App resource-server URL to its public APIM MCP URL.
- [x] Expose APIM-owned protected-resource metadata and the corresponding unauthorized challenge for the APIM-validation route.
- [x] Publish non-sensitive route URLs as Terraform outputs and keep subscription credentials and bearer tokens out of outputs and state additions.
- [x] Preserve the existing private backend host routing and unbuffered Streamable HTTP behavior.

## Phase 5 - Enforce the APIM-to-Backend Boundary

- [x] Restrict trusted Container App ingress to the delegated APIM subnet while preserving platform health probes.
- [x] Test the same APIM-subnet restriction on the Entra Container App and retain it when native OAuth metadata and MCP requests remain healthy.
- [x] Prove that APIM reaches each backend and that a non-APIM workload on the virtual network cannot invoke the trusted backend.
- [x] Confirm both backend FQDNs remain unresolvable and unreachable from the public internet.

## Phase 6 - Deploy and Validate Authentication Behavior

- [x] Format, validate, and review saved plans for every changed Terraform layer before applying in dependency order.
- [x] Verify missing, malformed, invalid-signature, expired, wrong-issuer, wrong-audience, and missing-scope tokens are rejected at the intended layer.
- [x] Verify the native route receives the original bearer token and the trusted backend receives no bearer token after APIM validation.
- [x] Run independent device-code MCP sessions for James, Jane, and Bill through both routes; confirm the native access matrix and the trusted backend's intentionally unfiltered dataset.
- [x] Exercise MCP initialization, tool discovery, both tool calls, and session deletion through both routes.
- [x] Remove the temporary subscription-key API and subscription only after both OAuth routes pass all positive and negative checks.

## Phase 7 - Validate Operations, Telemetry, and Handoff

- [x] Exercise throttling, request-size, timeout, correlation, and sanitized-error controls without recording secrets or MCP payloads.
- [x] Correlate tagged requests across APIM and each Container App, then inspect telemetry fields for credentials, tokens, customer data, and response bodies.
- [x] Run the complete service test, lint, format, type-check, Terraform format, Terraform validation, plan, and repository hygiene gates.
- [x] Update product, deployment, and MCP module documentation with current routes, authentication boundaries, operation, troubleshooting, and application-first teardown procedures.
- [x] Capture the `MCMC003` public-route handoff and the reusable `MCMC004` private-ingress inputs and constraints.
- [x] Resolve teardown disposition: retain the validated environment for `MCMC003` and preserve the documented application-first teardown procedure.

Completed on 2026-09-26. Both Terraform layers converged with no drift. The native route enforced the James, Jane, and Bill `oid` access matrix; the APIM-validation route accepted all three valid scoped tokens, removed `Authorization`, and returned the trusted service's complete fictitious catalog. Negative-token checks returned `401`, a 1 MiB limit violation returned `413`, concurrent requests produced `429`, and a non-APIM cross-backend call returned `403`. APIM and Container App records joined on one correlation identifier, with zero captured body bytes, no captured header bags, and only the approved application completion fields. Resources remain live for the next ticket.