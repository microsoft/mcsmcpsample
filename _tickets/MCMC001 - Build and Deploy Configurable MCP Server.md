---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC001
aliases:
  - MCMC001
name: Build and Deploy Configurable MCP Server
ticket_status: "[[In Progress]]"
---
# Specification

Create one stateless, containerized MCP server codebase for the Copilot Studio demonstration. The server must run in Azure Container Apps, expose a Streamable HTTP endpoint at `/mcp`, and not implement the legacy SSE transport. It must support two authentication modes selected through configuration:

- `entra`: Validate Microsoft Entra ID OAuth access tokens within the server.
- `trusted`: Perform no native OAuth validation because Azure API Management (APIM) authenticates and authorizes the request.

Create the MCP server, Python CLI, and application tests in the service component directory `msft-mcmc-mcp/msft-mcmc-mcp-service/`. Keep the module documentation in the root module directory `msft-mcmc-mcp/`.

Create `msft-mcmc-mcp/module.yaml` with the MCP module identity:

```yaml
symbol: mcp
name: MCP
```

Create `msft-mcmc-mcp/msft-mcmc-mcp-service/component.yaml` with the service component identity:

```yaml
symbol: service
name: Service
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

Create Terraform that provisions the deployment in two independently stateful layers. The foundation layer must create the resource group, Azure Container Registry (ACR), virtual network and delegated subnet, monitoring workspace, and an internal Azure Container Apps environment with public network access disabled. The application layer must later deploy two Container Apps from the same versioned image, one in each authentication mode. Both Container Apps must use only internal ingress and be reachable only from the private network path used by APIM.

The foundation layer must expose only the outputs required by the application layer, including the resource group name, ACR name and login server, Container Apps environment identifier and default domain, Log Analytics workspace identifier, and virtual network details. Each layer must have its own Terragrunt entry point and local Terraform state file. ACR administrator credentials must remain disabled; image pushes must authenticate through Microsoft Entra ID and application image pulls must use managed identity with `AcrPull` permission.

Create the Terragrunt/Terraform stack, infrastructure tests, and deployment module documentation in the root module directory `msft-mcmc-deployment/`.

Create `msft-mcmc-deployment/module.yaml` with the deployment module identity:

```yaml
symbol: deployment
name: Deployment
```

Terraform must also create the James, Jane, and Bill demonstration users in Microsoft Entra ID, using the tenant's verified domain, and map their object identifiers into the server's fine-grained access-control configuration. It must write their user principal names, object identifiers, and generated temporary passwords to a sensitive root `.env` file for local demonstration use. Temporary passwords exist only for initial interactive browser sign-in and must never be consumed programmatically by the CLI. The `.env` file must be excluded from source control, restricted to the local user where supported, and treated as disposable test data. Generated passwords remain sensitive values in Terraform state, so local state must remain gitignored and protected within the development environment.

Create a Python command-line application for exercising the deployed MCP server. It must provide an `mcp` subcommand with `--user James|Jane|Bill`, authenticate through Microsoft Entra ID device-code flow using a nonsecret public client, invoke the MCP tools, and display only the customer data accessible to that user. The selected user determines the expected immutable Entra object identifier; after interactive sign-in, the CLI must reject a token belonging to a different user. The CLI may display Microsoft's verification URL and device code but must not read, log, or echo passwords or tokens.

Expose a user-consentable delegated MCP API scope and declare that permission on the native CLI registration. Do not create an administrator delegated-permission grant in Terraform. Each demonstration user must be allowed to consent during first interactive sign-in, subject to the tenant's user-consent policy. A future Copilot Studio OAuth client is a separate registration and remains outside this ticket's native CLI registration.

Before implementing OAuth and private networking, deploy a temporary public smoke-test instance in `trusted` mode and connect it directly to the existing Microsoft Copilot Studio test agent with authentication set to **None**. Use Copilot Studio Preview to verify MCP discovery and tool invocation, then destroy the temporary endpoint. This is a short-lived development exception to the final private-ingress requirement and must not contain secrets or real data.

# Technical Solution

Use a supported MCP SDK and isolate authentication behind configuration-selected middleware. In `entra` mode, validate token signature, issuer, audience, lifetime, and required delegated scope against Microsoft Entra ID metadata. Use the validated `oid` claim as the authorization subject and deny access when the claim is missing or unmapped. In `trusted` mode, omit bearer-token validation and preserve the same MCP tool behavior without applying server-side user filtering.

Keep the MCP server stateless. Store no MCP session state between requests and place all demonstration customer data and access mappings in immutable in-process structures loaded at startup.

Package the server as an OCI container image. Build the image reproducibly, tag it with an immutable version, authenticate to ACR with Microsoft Entra ID, and push it without enabling registry administrator credentials. Deploy both authentication modes from the same image digest. Use an internal Container Apps environment on a subnet delegated to `Microsoft.App/environments`, disable public network access on the environment, and expose each application through internal ingress with health probes for `/health`.

Use Terraform with the AzureRM, AzureAD, Random, and Local providers to provision Azure resources, API and native public-client registrations, service principals, test identities, generated initial passwords, role configuration, and the local `.env` file. Configure the delegated scope for user consent, declare it as required access on the CLI registration, and do not provision an administrator consent grant or client secret. Mark password-bearing outputs as sensitive and keep each layer's local state gitignored. Ensure source control ignores `.env`, Terraform state, plans, container build artifacts, and other generated secret material.

Use Terragrunt as the stack orchestration layer in `msft-mcmc-deployment/`, with Terraform modules and environment inputs kept within that module boundary. The deployment stack may package or reference build output from `msft-mcmc-mcp/`, but application source must remain owned by the MCP module.

Manage OPMC identity files using the `@polycloudinc/opmc` conventions. Root `org.yaml` and `product.yaml` establish the shared `msft-mcmc` coordinate prefix. Each qualified module directory contains its own `module.yaml`, producing the module coordinates `msft-mcmc-mcp` and `msft-mcmc-deployment`.

Implement the Python CLI with a structured argument parser and an OAuth client appropriate for a native public client. Use device-code flow so authentication, first-use consent, MFA, and applicable Conditional Access remain interactive. Keep access tokens in memory unless a secure token cache is deliberately introduced. Verify the token's immutable `oid` claim matches the user selected by `--user` before invoking MCP tools. Treat refusal of consent, tenant policy blocking user consent, expiration, and wrong-user sign-in as sanitized authentication failures.

# Definition of Done

- One stateless server codebase exposes a working Streamable HTTP MCP endpoint at `/mcp`; legacy SSE is not implemented.
- MCP application source, CLI, tests, and module documentation are contained in `msft-mcmc-mcp/`.
- `msft-mcmc-mcp/module.yaml` exists with `symbol: mcp` and `name: MCP`.
- Root `org.yaml` exists with `symbol: msft` and `name: Microsoft Corporation`.
- Root `product.yaml` exists with `symbol: mcmc` and `name: Microsoft Copilot Studio MCP demo`.
- One deployable OCI container image supports both `entra` and `trusted` authentication modes.
- The server fails to start for a missing or unsupported authentication mode.
- The hard-coded dataset contains only obviously fictitious customer names, reserved phone numbers, and reserved email domains.
- Deterministic list and lookup tools have documented schemas and automated tests.
- James can access only his assigned customer subset, Jane can access only her different assigned subset, and Bill receives no customer records.
- Direct lookups and error responses do not reveal inaccessible customer records.
- In `entra` mode, valid Microsoft Entra ID access tokens can discover and invoke the tools.
- In `entra` mode, missing, invalid, expired, incorrectly scoped, and incorrectly targeted tokens are rejected.
- In `trusted` mode, native OAuth validation is disabled and the APIM-only network requirement is documented.
- Final APIM-only ingress enforcement is explicitly deferred to `MCMC002`; this ticket proves internal environment isolation and private-path reachability.
- Health checks, structured logs, and correlation identifiers are implemented.
- Logs do not contain access tokens, secrets, passwords, or sensitive tool payloads.
- Terraform is split into independently stateful foundation and application layers with explicit outputs and inputs between them.
- The foundation layer provisions the resource group, ACR with administrator credentials disabled, virtual network, delegated subnet, monitoring workspace, and private Container Apps environment.
- The application layer deploys two Container Apps from the same immutable ACR image with required managed identities and role assignments.
- The Terragrunt/Terraform stack, infrastructure tests, and deployment module documentation are contained in `msft-mcmc-deployment/`.
- `msft-mcmc-deployment/module.yaml` exists with `symbol: deployment` and `name: Deployment`.
- Both Container Apps use internal ingress and are reachable only through the private Container Apps environment path.
- Terraform creates James, Jane, and Bill as disposable Entra test users and configures authorization by immutable object identifier.
- Terraform creates an MCP API registration with a user-consentable delegated scope and a nonsecret native public-client registration that declares that scope, without an administrator consent grant.
- Terraform writes user principal names, object identifiers, and initial interactive-sign-in passwords to a gitignored root `.env` file without exposing them in normal command output.
- Terraform state containing sensitive values remains local, gitignored, and protected within the development environment.
- The Python CLI provides `mcp --user James|Jane|Bill`, authenticates through device-code flow, verifies the signed-in user's `oid` matches the selected user, invokes the tools, and displays only authorized data.
- First-use user consent succeeds when tenant policy permits it; refused consent, blocked consent, and wrong-user sign-in fail without leaking credentials or tokens.
- A temporary public endpoint proves MCP discovery and tool invocation from Microsoft Copilot Studio Preview before OAuth and private networking are implemented.
- The temporary public endpoint is removed after the smoke test and is not part of the final architecture.
- Terraform validation and application deployment tests pass.
- Deployment and teardown procedures are documented.

# Execution Plan

## Phase 1: Define and Prove the Local MCP Application

- [x] Create and validate root `org.yaml`, root `product.yaml`, and `msft-mcmc-mcp/module.yaml` with their defined OPMC identities.
- [x] Create the `msft-mcmc-mcp/` module structure and select the Python container runtime and supported MCP SDK.
- [x] Define the fictitious customer dataset, list and lookup tool schemas, and James/Jane/Bill access matrix.
- [x] Implement the stateless Streamable HTTP `/mcp` endpoint, health endpoint, tools, and correlation-safe logging.
- [x] Implement `entra` and `trusted` configuration boundaries with startup validation, unit tests, and protocol tests.

Verification:

- [x] Run formatting, linting, type checking, unit tests, and MCP protocol tests locally.
- [x] Verify the OPMC product coordinate resolves to `msft-mcmc` and the MCP module coordinate resolves to `msft-mcmc-mcp`.
- [x] Verify no SSE endpoint or session-state dependency exists.
- [x] Verify all mock contact data uses reserved fictional values.

## Phase 1A: Introduce the Service Component

- [x] Create the `msft-mcmc-mcp-service` component with its OPMC identity.
- [x] Move the complete deployable Python service project into the component directory.
- [x] Update module documentation and repository references for the component path and coordinate.
- [x] Run the service quality gates from the component directory.

## Phase 2: Smoke Test Microsoft Copilot Studio Connectivity

- [x] Deploy a temporary public endpoint from the same MCP application in `trusted` mode with no connection authentication.
- [x] Add the licensed-tenant APIM `/mcp` endpoint to the existing Microsoft Copilot Studio test agent using the API-scoped APIM subscription key.
- [x] Use Copilot Studio Preview to discover the list and lookup tools and invoke them with representative prompts.
- [x] Capture sanitized Copilot Studio compatibility and data-exposure findings in the root README.
- [ ] Capture a sanitized request correlation across APIM and Container Apps, then remove the tool connection.
- [x] Destroy the temporary public endpoint from the original tenant after the smoke-test attempt.

The original-tenant deployment passed direct health, MCP initialization, tool discovery, and tool invocation checks. Copilot Studio agent creation was blocked by `User license not found`, so no tool connection was created and the Copilot Studio checks remain open. The disposable `mcmc-smoke-rg` resource group was deleted on 2026-09-25 before moving the test to a licensed tenant.

The licensed-tenant Copilot Studio test connected to `https://mcmc-<subscription-prefix>-apim.azure-api.net/mcp` through the APIM subscription-key connection. Preview discovered `list_accessible_customers` and `get_accessible_customer`, rendered all four fictitious records from the list tool, returned the expected `CUST-1002` record from the lookup tool, and correctly returned no customer for the invalid `CUST-001` lookup. Copilot Studio displayed a tool-contract loading warning while still discovering and invoking both contracts successfully. No credentials, tokens, or non-fictitious data appeared in the observed responses.

### Licensed-Tenant Foundation Deployment

- [x] Create `msft-mcmc-deployment/module.yaml` and `msft-mcmc-deployment/msft-mcmc-deployment-infra/component.yaml` with the deployment module and infrastructure component OPMC identities.
- [x] Create the Terragrunt/Terraform component structure, provider constraints, environment inputs, naming conventions, and deployment documentation.
- [x] Configure Terragrunt to store state locally under the gitignored repository-root `.terraform-state/` directory.
- [x] Validate that a private Container Apps environment can be provisioned in the licensed tenant.
- [x] Revise the architecture to use Container Apps and split deployment into foundation and application layers.
- [x] Consolidate the infrastructure component under `terraform/`, with ordered `01-foundation` and `02-container` layers and no separate environment tree.
- [x] Configure the foundation layer to own `mcmc-deployment-rg`, ACR, networking, monitoring, and the private Container Apps environment.
- [x] Add Standard v2 API Management with outbound VNet integration and private Container Apps DNS resolution to the foundation layer.
- [x] Migrate the retained live resources into foundation state and remove obsolete hosting resources through Terraform.
- [x] Apply the foundation layer, verify ACR and private environment controls, and record its application-layer outputs.

The private Container Apps feasibility deployment succeeded on 2026-09-25 with internal ingress, public network access disabled, delegated subnet `10.58.0.64/27`, and private static IP `10.58.0.82`. Azure created the required platform-managed `mcmc-container-apps-managed-rg` resource group. The retained resources were migrated into the dedicated foundation state, obsolete hosting resources were destroyed, and ACR `mcmc677e8052.azurecr.io` was created with administrator credentials disabled and Entra-authenticated push access.

Verification:

- [x] Verify Copilot Studio successfully discovers both MCP tools over Streamable HTTP.
- [x] Verify Copilot Studio invokes both tools and renders the expected mock customer fields.
- [x] Verify no credentials, tokens, or non-fictitious data are exposed during the smoke test.
- [x] Verify the temporary endpoint is no longer publicly reachable after teardown.

## Phase 3: Implement Entra Authentication and Fine-Grained Access

- [x] Create Terraform definitions for the MCP API registration, user-consentable delegated scope, service principals, and nonsecret native CLI public-client registration with declared API access and no administrator consent grant.
- [x] Create Terraform definitions for James, Jane, and Bill and map their Entra object identifiers to the access-control policy.
- [x] Implement JWT validation for signature, issuer, audience, lifetime, delegated scope, and required `oid` claim.
- [x] Implement and test the James, Jane, Bill, unmapped-user, and unauthenticated authorization paths.
- [x] Generate the gitignored root `.env` file with user principal names, immutable object identifiers, and initial interactive-sign-in passwords using secure local-file handling.

Verification:

- [x] Run automated positive and negative token-validation tests.
- [x] Verify James and Jane see only their assigned subsets and Bill sees no records through both list and direct lookup.
- [x] Verify secrets are absent from Git status, logs, nonsensitive Terraform output, and test artifacts.

## Phase 4: Build the Python Demonstration CLI

- [x] Implement the CLI entry point and `mcp --user james|jane|bill` argument validation.
- [x] Load the selected test user's expected principal name and object identifier from `.env` without reading or echoing the initial password.
- [x] Implement device-code authentication with the native public client, interactive first-use user consent, in-memory token handling, and selected-user `oid` verification.
- [x] Invoke MCP discovery and customer tools and render authorized results and sanitized errors.

Verification:

- [x] Run CLI unit tests with mocked device-code, consent, token, and MCP responses.
- [x] Verify each supported user produces the expected access result against the local server.
- [x] Verify invalid users, wrong-user sign-in, refused or policy-blocked consent, failed authentication, and authorization failures return nonzero exits without leaking passwords, device codes, or tokens.

## Phase 5: Build and Deploy the Container Apps Application Layer

- [x] Add a reproducible OCI image definition and standalone ASGI entry point for the MCP service component.
- [x] Publish the fully qualified `msft-mcmc-mcp-service` artifact from the ordered `02-container` layer, derive its dotted image tag from the root `version` file, use the current branch commit count as the revision, increment and persist the build number on every execution, push through Entra-authenticated ACR Build, and record the digest without enabling administrator credentials.
- [x] Create the ordered `03-application` Terraform and Terragrunt stack with a dedicated local state file.
- [x] Read the required `01-foundation` outputs explicitly and create a user-assigned identity with `AcrPull` for the application.
- [x] Deploy one private `trusted` Container App from the exact validated `msft-mcmc-mcp-service:0.0.1.3` digest with internal ingress on port `8000`, `/health` startup, readiness, and liveness probes, and `AUTH_MODE=trusted`.
- [x] Configure the trusted MCP API in APIM with `/mcp` and `/health` operations routed to the private Container App.
- [x] Require an API-scoped APIM subscription key and verify keyless requests are rejected.
- [ ] After Phase 3 token verification is complete, extend `03-application` with the private `entra` Container App using the same immutable image contract and mode-specific configuration.

Verification:

- [x] Run image, Terraform, formatting, validation, and plan checks.
- [x] Verify the deployment module coordinate resolves to `msft-mcmc-deployment`.
- [x] Verify the private `trusted` Container App becomes healthy and runs the expected immutable image digest.
- [ ] After the `entra` app is added, verify both Container Apps run the same expected immutable image digest.
- [x] Verify private name resolution and HTTPS access from APIM's authorized VNet integration path.
- [x] Verify the trusted Container App has no public DNS resolution outside the private environment path.

## Phase 6: Validate the Deployed Demonstration and Handoff

- [ ] Run the Python CLI against the deployed `entra` Container App for James, Jane, and Bill.
- [ ] Exercise the `trusted` Container App from a temporary authorized private test path without native token validation.
- [ ] Validate correlation identifiers and sanitized telemetry across client and Container App requests.
- [ ] Document deployment, configuration, operation, teardown, and the APIM-only ingress control to be completed by `MCMC002`.
- [ ] Update the affected product and module documentation with the implemented current state.

Verification:

- [ ] Confirm deployed James, Jane, and Bill results match the defined access matrix.
- [ ] Confirm invalid tokens and direct public access are rejected.
- [ ] Run the complete automated test suite and Terraform checks from a clean workspace.
- [ ] Destroy disposable resources in application-then-foundation order and verify identities, Container Apps, ACR, the private environment, and local secret files are removed as documented.