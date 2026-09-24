---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC001
aliases:
  - MCMC001
name: Build and Deploy Configurable MCP Server
ticket_status: "[[Ready]]"
---
# Specification

Create one stateless MCP server codebase for the Copilot Studio demonstration. The server must run as an HTTP-triggered Azure Function, expose a Streamable HTTP endpoint at `/mcp`, and not implement the legacy SSE transport. It must support two authentication modes selected through configuration:

- `entra`: Validate Microsoft Entra ID OAuth access tokens within the server.
- `trusted`: Perform no native OAuth validation because Azure API Management (APIM) authenticates and authorizes the request.

Create the MCP server, Python CLI, application tests, and module documentation in the root module directory `msft-mcmc-mcp/`.

Create `msft-mcmc-mcp/module.yaml` with the MCP module identity:

```yaml
symbol: mcp
name: MCP
```

Create an OPMC organization identity file at the repository root named `org.yaml` with exactly these identity values:

```yaml
symbol: msft
name: Microsoft Corporation
```

Create an OPMC product identity file at the repository root named `product.yaml` with exactly these identity values:

```yaml
symbol: mcmc
name: Microsoft Copilot Studio MCP demo
```

The server must contain a hard-coded set of fictitious customer records. Each record must contain a customer number, customer name, customer phone number, and customer email address. Names must be obviously fictitious, phone numbers must use reserved fictional ranges, and email addresses must use reserved domains such as `example.com`.

The server must provide deterministic MCP tools for listing accessible customers and retrieving an accessible customer by customer number. In `entra` mode, it must apply fine-grained access control using the immutable Microsoft Entra object identifier from the validated token:

- James can access one defined subset of customer records.
- Jane can access a different defined subset of customer records.
- Bill cannot access any customer records.

An authenticated user must not be able to infer inaccessible customer records through list results, direct lookup, error details, or logs. In `trusted` mode, the server does not perform user-level authorization because APIM owns the authentication boundary; this mode exists to demonstrate gateway-enforced OAuth.

Create Terraform that provisions an Azure Functions Elastic Premium `EP1` hosting plan with at least one always-ready instance and deploys the same application package to two Function Apps, one in each authentication mode. Both Function Apps must use private endpoints for inbound access, have public network access disabled, and be resolvable and reachable only from the private network path used by APIM.

Create the Terragrunt/Terraform stack, infrastructure tests, and deployment module documentation in the root module directory `msft-mcmc-deployment/`.

Create `msft-mcmc-deployment/module.yaml` with the deployment module identity:

```yaml
symbol: deployment
name: Deployment
```

Terraform must also create the James, Jane, and Bill demonstration users in Microsoft Entra ID, using the tenant's verified domain, and map their object identifiers into the server's fine-grained access-control configuration. It must write their user principal names and generated temporary passwords to a sensitive root `.env` file for local demonstration use. The `.env` file must be excluded from source control, restricted to the local user where supported, and treated as disposable test data. Generated passwords remain sensitive values in Terraform state, so the state backend must be access-controlled and encrypted.

Create a Python command-line application for exercising the deployed MCP server. It must provide an `mcp` subcommand with `--user James|Jane|Bill`, perform the configured test-only authentication flow using the selected identity, invoke the MCP tools, and display only the customer data accessible to that user. The authentication approach must be documented as demonstration-only if it uses username and password credentials; it must not log or echo passwords or tokens.

Before implementing OAuth and private networking, deploy a temporary public smoke-test instance in `trusted` mode and connect it directly to the existing Microsoft Copilot Studio test agent with authentication set to **None**. Use Copilot Studio Preview to verify MCP discovery and tool invocation, then destroy the temporary endpoint. This is a short-lived development exception to the final private-ingress requirement and must not contain secrets or real data.

# Technical Solution

Use a supported MCP SDK and isolate authentication behind configuration-selected middleware. In `entra` mode, validate token signature, issuer, audience, lifetime, and required delegated scope against Microsoft Entra ID metadata. Use the validated `oid` claim as the authorization subject and deny access when the claim is missing or unmapped. In `trusted` mode, omit bearer-token validation and preserve the same MCP tool behavior without applying server-side user filtering.

Keep the MCP server stateless. Store no MCP session state between requests and place all demonstration customer data and access mappings in immutable in-process structures loaded at startup. Keep tool execution comfortably below the Azure Functions HTTP response limit of 230 seconds.

Package and deploy the server as Azure Functions code rather than a container image. Use one Elastic Premium `EP1` plan for both Function Apps and configure at least one always-ready instance to avoid cold starts. Use private endpoints for inbound connectivity and a `privatelink.azurewebsites.net` private DNS zone linked to the APIM virtual network. Use a dedicated private-endpoint subnet. Add a separate subnet delegated to `Microsoft.Web/serverFarms` only if outbound VNet integration is required; VNet integration controls outbound connectivity and does not provide private inbound access.

Use Terraform with the AzureRM, AzureAD, Random, and Local providers to provision Azure resources, test identities, generated passwords, role configuration, private DNS, and the local `.env` file. Mark password-bearing outputs as sensitive and use an encrypted, access-controlled state backend. Ensure source control ignores `.env`, Terraform state, plans, and other generated secret material.

Use Terragrunt as the stack orchestration layer in `msft-mcmc-deployment/`, with Terraform modules and environment inputs kept within that module boundary. The deployment stack may package or reference build output from `msft-mcmc-mcp/`, but application source must remain owned by the MCP module.

Manage OPMC identity files using the `@polycloudinc/opmc` conventions. Root `org.yaml` and `product.yaml` establish the shared `msft-mcmc` coordinate prefix. Each qualified module directory contains its own `module.yaml`, producing the module coordinates `msft-mcmc-mcp` and `msft-mcmc-deployment`.

Implement the Python CLI with a structured argument parser and an OAuth client appropriate for a native test client. If the automated username/password flow is used, enable it only for these disposable cloud-only users, do not require password change on first use, and document that it is unsuitable for production, federation, MFA, or Conditional Access scenarios. Prefer a nonsecret public client registration and delegated scope for the CLI.

# Definition of Done

- One stateless server codebase exposes a working Streamable HTTP MCP endpoint at `/mcp`; legacy SSE is not implemented.
- MCP application source, CLI, tests, and module documentation are contained in `msft-mcmc-mcp/`.
- `msft-mcmc-mcp/module.yaml` exists with `symbol: mcp` and `name: MCP`.
- Root `org.yaml` exists with `symbol: msft` and `name: Microsoft Corporation`.
- Root `product.yaml` exists with `symbol: mcmc` and `name: Microsoft Copilot Studio MCP demo`.
- One deployable Azure Functions package supports both `entra` and `trusted` authentication modes.
- The server fails to start for a missing or unsupported authentication mode.
- The hard-coded dataset contains only obviously fictitious customer names, reserved phone numbers, and reserved email domains.
- Deterministic list and lookup tools have documented schemas and automated tests.
- James can access only his assigned customer subset, Jane can access only her different assigned subset, and Bill receives no customer records.
- Direct lookups and error responses do not reveal inaccessible customer records.
- In `entra` mode, valid Microsoft Entra ID access tokens can discover and invoke the tools.
- In `entra` mode, missing, invalid, expired, incorrectly scoped, and incorrectly targeted tokens are rejected.
- In `trusted` mode, native OAuth validation is disabled and the APIM-only network requirement is documented.
- Final APIM-only ingress enforcement is explicitly deferred to `MCMC002`; this ticket proves private endpoint isolation and private-path reachability.
- Health checks, structured logs, and correlation identifiers are implemented.
- Logs do not contain access tokens, secrets, passwords, or sensitive tool payloads.
- Terraform provisions an Elastic Premium `EP1` plan with at least one always-ready instance, two Function Apps, private endpoints, private DNS, monitoring, storage, and required identities.
- The Terragrunt/Terraform stack, infrastructure tests, and deployment module documentation are contained in `msft-mcmc-deployment/`.
- `msft-mcmc-deployment/module.yaml` exists with `symbol: deployment` and `name: Deployment`.
- Both Function Apps have public network access disabled and are reachable through their private endpoints.
- Terraform creates James, Jane, and Bill as disposable Entra test users and configures authorization by immutable object identifier.
- Terraform writes user principal names and temporary passwords to a gitignored root `.env` file without exposing them in normal command output.
- Terraform state containing sensitive values is encrypted and access-controlled.
- The Python CLI provides `mcp --user James|Jane|Bill`, authenticates the selected user, invokes the tools, and displays only authorized data.
- A temporary public endpoint proves MCP discovery and tool invocation from Microsoft Copilot Studio Preview before OAuth and private networking are implemented.
- The temporary public endpoint is removed after the smoke test and is not part of the final architecture.
- Terraform validation and application deployment tests pass.
- Deployment and teardown procedures are documented.

# Execution Plan

## Phase 1: Define and Prove the Local MCP Application

- [x] Create and validate root `org.yaml`, root `product.yaml`, and `msft-mcmc-mcp/module.yaml` with their defined OPMC identities.
- [x] Create the `msft-mcmc-mcp/` module structure and select the Azure Functions language runtime and supported MCP SDK.
- [x] Define the fictitious customer dataset, list and lookup tool schemas, and James/Jane/Bill access matrix.
- [x] Implement the stateless Streamable HTTP `/mcp` endpoint, health endpoint, tools, and correlation-safe logging.
- [x] Implement `entra` and `trusted` configuration boundaries with startup validation, unit tests, and protocol tests.

Verification:

- [x] Run formatting, linting, type checking, unit tests, and MCP protocol tests locally.
- [x] Verify the OPMC product coordinate resolves to `msft-mcmc` and the MCP module coordinate resolves to `msft-mcmc-mcp`.
- [x] Verify no SSE endpoint or session-state dependency exists.
- [x] Verify all mock contact data uses reserved fictional values.

## Phase 2: Smoke Test Microsoft Copilot Studio Connectivity

- [ ] Deploy a temporary public Azure Function from the same MCP application package in `trusted` mode with no connection authentication.
- [ ] Add the temporary `/mcp` endpoint to the existing Microsoft Copilot Studio test agent as an MCP tool with authentication set to **None**.
- [ ] Use Copilot Studio Preview to discover the list and lookup tools and invoke them with representative prompts.
- [ ] Capture sanitized request correlation and compatibility findings, then remove the tool connection and destroy the temporary public endpoint.

Verification:

- [ ] Verify Copilot Studio successfully discovers both MCP tools over Streamable HTTP.
- [ ] Verify Copilot Studio invokes both tools and renders the expected mock customer fields.
- [ ] Verify no credentials, tokens, or non-fictitious data are exposed during the smoke test.
- [ ] Verify the temporary endpoint is no longer publicly reachable after teardown.

## Phase 3: Implement Entra Authentication and Fine-Grained Access

- [ ] Create Terraform definitions for the MCP API registration, delegated scope, native CLI registration, and required consent configuration.
- [ ] Create Terraform definitions for James, Jane, and Bill and map their Entra object identifiers to the access-control policy.
- [ ] Implement JWT validation for signature, issuer, audience, lifetime, delegated scope, and required `oid` claim.
- [ ] Implement and test the James, Jane, Bill, unmapped-user, and unauthenticated authorization paths.
- [ ] Generate the gitignored root `.env` file with sensitive user identifiers and temporary credentials using secure local-file handling.

Verification:

- [ ] Run automated positive and negative token-validation tests.
- [ ] Verify James and Jane see only their assigned subsets and Bill sees no records through both list and direct lookup.
- [ ] Verify secrets are absent from Git status, logs, nonsensitive Terraform output, and test artifacts.

## Phase 4: Build the Python Demonstration CLI

- [ ] Implement the CLI entry point and `mcp --user James|Jane|Bill` argument validation.
- [ ] Load selected test-user configuration from `.env` without echoing credentials.
- [ ] Implement the documented test-only OAuth flow and token handling.
- [ ] Invoke MCP discovery and customer tools and render authorized results and sanitized errors.

Verification:

- [ ] Run CLI unit tests with mocked OAuth and MCP responses.
- [ ] Verify each supported user produces the expected access result against the local server.
- [ ] Verify invalid users, failed authentication, and authorization failures return nonzero exits without leaking secrets.

## Phase 5: Provision Private Azure Functions Infrastructure

- [ ] Create and validate `msft-mcmc-deployment/module.yaml`, then create the module structure for Terragrunt, Terraform, tests, and documentation.
- [ ] Create Terraform for the Elastic Premium `EP1` plan, always-ready capacity, Function storage, Application Insights, both Function Apps, and the encrypted state backend.
- [ ] Create a dedicated private-endpoint subnet, private endpoints, and linked `privatelink.azurewebsites.net` private DNS zone.
- [ ] Disable public network access on both Function Apps and add a separate delegated outbound integration subnet only if required.
- [ ] Configure each Function App with the same package and its respective `entra` or `trusted` mode settings.

Verification:

- [ ] Run Terraform formatting, initialization, validation, and plan review.
- [ ] Verify the deployment module coordinate resolves to `msft-mcmc-deployment`.
- [ ] Apply the infrastructure and verify both Function Apps are healthy and always ready.
- [ ] Verify private DNS resolution and HTTPS access from an authorized VNet path.
- [ ] Verify public requests to both Function Apps fail.

## Phase 6: Validate the Deployed Demonstration and Handoff

- [ ] Run the Python CLI against the deployed `entra` Function App for James, Jane, and Bill.
- [ ] Exercise the `trusted` Function App from a temporary authorized private test path without native token validation.
- [ ] Validate correlation identifiers and sanitized telemetry across client and Function App requests.
- [ ] Document deployment, configuration, operation, teardown, and the APIM-only ingress control to be completed by `MCMC002`.
- [ ] Update the affected product and module documentation with the implemented current state.

Verification:

- [ ] Confirm deployed James, Jane, and Bill results match the defined access matrix.
- [ ] Confirm invalid tokens and direct public access are rejected.
- [ ] Run the complete automated test suite and Terraform checks from a clean workspace.
- [ ] Destroy disposable resources and verify identities, private endpoints, DNS records, Function Apps, and local secret files are removed as documented.