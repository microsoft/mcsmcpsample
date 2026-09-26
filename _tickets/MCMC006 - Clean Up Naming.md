---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC006
aliases:
  - MCMC006
name: Clean Up Naming
ticket_status: "[[Done]]"
---
# Specification

Clean up inconsistent names across the solution so deployed resources, infrastructure code, state files, documentation, and historical records consistently describe the demonstration environment and the two MCP authorization boundaries.

- Rename the APIM API display name `MCMC APIM OAuth MCP` to `MCMC Gateway OAuth MCP` so it is consistent with `MCMC Gateway OAuth Metadata`.
- Rename the trusted-mode Container App from `mcmc-mcp-trusted` to `mcmc-mcp-gateway` so its generated Azure Container Apps hostname begins with `mcmc-mcp-gateway.` instead of `mcmc-mcp-trusted.`.
- Rename the native-authentication Container App from `mcmc-mcp-entra` to `mcmc-mcp-native` so its generated Azure Container Apps hostname begins with `mcmc-mcp-native.` instead of `mcmc-mcp-entra.`.
- Rename the shared user-assigned identity from `mcmc-mcp-trusted-identity` to `mcmc-mcp-apps-identity` because it is used by both Container Apps.
- Rename the Container Apps environment from `mcmc-container-apps-probe` to `mcmc-container-apps`.
- Rename the Log Analytics workspace from the hard-coded `mcmc-smoke-677e8052-logs` to `mcmc-<subscription-prefix>-logs`, using the same computed subscription prefix as the other globally scoped resources.
- Rename the local Terraform state files from `smoke-foundation.terraform.tfstate` and `smoke-application.terraform.tfstate` to `foundation.terraform.tfstate` and `application.terraform.tfstate` respectively, preserving the existing state and backups during migration.
- Change the common `purpose` tag from `mcmc-copilot-studio-smoke-test` to `mcmc-copilot-studio-demo`.
- Refactor Layer 3 Terraform variables, locals, resource labels, outputs, descriptions, and references from ambiguous `container_app`, `trusted`, and `entra` deployment-role names to explicit `gateway` and `native` names.
- Update all repository-controlled references to the renamed resources and interfaces, including current documentation, commands, tests, and completed ticket or historical validation text. Generated Terragrunt cache files and Terraform provider state internals are not edited directly.

The runtime values `AUTH_MODE=trusted` and `AUTH_MODE=entra`, the `ENTRA_*` configuration names, and descriptions of their security behavior remain unchanged because they identify authentication semantics rather than deployment roles. The public `/gateway/mcp` and `/native/mcp` paths, APIM API resource names, Entra registrations and identifiers, ACR repository and image coordinates, resource group, APIM service, and product/module names are also unchanged.

Container App, managed identity, Container Apps environment, and Log Analytics workspace renames are implemented as direct Terraform replacements. Temporary service disruption during replacement is accepted; a parallel create-switch-delete migration is not required.

## Resolved Decisions

- Terraform interfaces and resource labels use `gateway` and `native` consistently.
- The shared managed identity uses the role-neutral name `mcmc-mcp-apps-identity`.
- Active `smoke` and `probe` deployment leftovers are included in the cleanup.
- All repository references, including historical records, are updated.
- Direct replacement and its temporary disruption are accepted.
- There are no open naming questions.

# Technical Solution

Update the foundation Terragrunt inputs and Terraform resources to derive the neutral Log Analytics workspace name from the subscription prefix, use the neutral Container Apps environment name, and apply the demonstration-purpose tag. Move the existing local state files to their new paths before changing the Terragrunt backend configuration so Terraform continues to manage the deployed resources rather than treating the new paths as empty state.

Refactor the application Terraform interface around two deployment roles. Use `gateway_container_app_name` and `native_container_app_name` variables; `gateway` and `native` resource labels and FQDN locals; matching role-specific outputs; and a shared `apps_identity` label and output. Use Terraform `moved` blocks or equivalent explicit state moves where an address changes without changing the Azure resource identity. Set the deployed names to `mcmc-mcp-gateway`, `mcmc-mcp-native`, and `mcmc-mcp-apps-identity`, and update APIM backend references and the gateway API display name accordingly. Preserve the runtime authentication modes and route behavior.

Run formatting, initialization, validation, and plans for the affected Terraform layers before applying them in dependency order. The plans must account for intentional replacements caused by immutable Azure names and must not propose unrelated resource changes. Because Azure will not delete a Container Apps environment while it contains Container Apps, review and apply a Layer 3 destroy plan before replacing the foundation environment, then deploy the refactored Layer 3 resources into the new environment. Verify the resulting Azure inventory, generated backend hostnames, APIM configuration, health, authorization behavior, network isolation, and telemetry.

Update repository-owned documentation, commands, tests, and tickets to use the new names. Do not edit `.terragrunt-cache`, provider-generated files, or serialized Terraform state contents by hand. Remove generated caches when needed so validation uses the updated source.

# Definition of Done

- The APIM API currently displayed as `MCMC APIM OAuth MCP` is displayed as `MCMC Gateway OAuth MCP`.
- The trusted-mode Container App is named `mcmc-mcp-gateway`, and its generated application URL uses the `mcmc-mcp-gateway.` hostname prefix.
- The native-authentication Container App is named `mcmc-mcp-native`, and its generated application URL uses the `mcmc-mcp-native.` hostname prefix.
- The shared user-assigned identity is named `mcmc-mcp-apps-identity` and both Container Apps can pull the pinned image through it.
- The Container Apps environment is named `mcmc-container-apps`, the Log Analytics workspace is named `mcmc-<subscription-prefix>-logs`, and deployed resources carry the `mcmc-copilot-studio-demo` purpose tag.
- Terraform state is retained in `foundation.terraform.tfstate` and `application.terraform.tfstate`; planning from the renamed backends does not attempt to recreate unchanged resources because of lost state.
- Layer 3 Terraform variables, locals, resource labels, outputs, descriptions, and consumers consistently use `gateway` and `native` deployment-role names.
- The MCP containers still receive `AUTH_MODE=trusted` and `AUTH_MODE=entra` respectively, and all existing Entra authorization settings remain intact.
- The public `/gateway/mcp` and `/native/mcp` URLs and their authorization boundaries continue to work after replacement.
- Direct access to both private Container Apps remains blocked, health probes pass, both apps run the expected immutable image digest, and APIM-to-backend telemetry remains observable.
- Outside the rename definitions in this ticket, repository-controlled source, documentation, commands, tests, tickets, and historical records contain no stale instances of the replaced names or obsolete `smoke` and `probe` deployment labels.
- Terraform formatting and validation pass, and the final plans contain no unexpected changes.

# Execution Plan

- [x] Migrate the foundation and application local state files to their neutral names and update the Terragrunt backend paths without losing state.
- [x] Rename the foundation Container Apps environment, Log Analytics workspace, and common purpose tag, then update the foundation documentation.
- [x] Format, initialize, validate, and plan the foundation layer; review and remove the dependent Layer 3 resources; then apply the foundation replacements and confirm that only the intended changes occur.
- [x] Refactor the application Terraform variables, locals, resource labels, outputs, and state addresses to the `gateway`, `native`, and shared `apps_identity` terminology, then update the application documentation.
- [x] Set the new Container App and managed identity names, update APIM backend references and display text, and preserve the existing runtime authentication modes and public routes.
- [x] Format, initialize, validate, and review the application plan, then apply the accepted direct replacements and APIM update.
- [x] Validate the deployed resource names, generated hostnames, image digest, health, authorization matrices, private-backend isolation, APIM routing, and correlated telemetry.
- [x] Update all remaining repository-controlled documentation, commands, tests, tickets, and historical records to the new naming scheme.
- [x] Run final repository and Terraform checks, confirm that no stale names remain outside generated or serialized artifacts, and record the validation evidence.

# Validation Evidence

- Both renamed local backends initialized against their original state lineages and returned the existing foundation and application outputs before deployment.
- The foundation apply created `mcmc-container-apps` and `mcmc-677e8052-logs`; both resources carry the `mcmc-copilot-studio-demo` purpose tag. The final foundation plan returned detailed exit code `0`.
- The application apply created `mcmc-mcp-gateway`, `mcmc-mcp-native`, and `mcmc-mcp-apps-identity`. Both apps are running the pinned `sha256:165930594cff15507b0ed3d885c554c115bd9a40d8bc0aa8587f5f9c4f472a2f` image and share the identity's `AcrPull` assignment. The final application plan returned detailed exit code `0`.
- APIM displays `MCMC Gateway OAuth MCP`, targets both new private FQDNs, serves both protected-resource metadata documents with `200`, rejects unauthenticated requests with `401`, and rejects an oversized request with `413`. The rendered APIM policy validator passed.
- Authenticated James, Jane, and Bill sessions passed both public routes. Native mode returned each user's configured access set; gateway mode returned the complete four-customer catalog for all three users.
- A live cross-backend request returned `403`, neither backend hostname resolved publicly, and Log Analytics correlated successful APIM requests with sanitized completion records from both renamed Container Apps.
- Terraform and Terragrunt formatting checks, both Terraform validations, JSON validation for the dev-container manifest, `git diff --check`, and final retired-name and old-identifier audits passed.