# Deployment

The deployment module owns Azure infrastructure and deployment orchestration for the Microsoft Copilot Studio MCP demonstration.

The module coordinate is `msft-mcmc-deployment`. Its `msft-mcmc-deployment-infra` component owns the ordered Terraform and deployment layers, local state configuration, and infrastructure tests.

## Structure

- `msft-mcmc-deployment-infra/terraform/root.hcl` defines shared Azure context, deterministic names, and tags.
- `msft-mcmc-deployment-infra/terraform/01-foundation/` contains the foundation Terraform and Terragrunt configuration, stores state in `.terraform-state/smoke-foundation.terraform.tfstate`, and owns the resource group, ACR, virtual network, delegated subnets, Log Analytics workspace, private Container Apps environment, private DNS, Standard v2 API Management service, and shared Microsoft Entra identities.
- `msft-mcmc-deployment-infra/terraform/02-container/buildandpush.sh` builds and pushes an immutable MCP service image through ACR Build and writes the gitignored `image.json` handoff manifest after a successful push.
- `msft-mcmc-deployment-infra/terraform/03-application/` contains the application Terraform and Terragrunt configuration, stores state in `.terraform-state/smoke-application.terraform.tfstate`, and owns the trusted Container App, its user-assigned identity, its `AcrPull` assignment, and its API Management API configuration.

## Environment

The smoke environment targets Sweden Central. Operators provide the target account context through `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID`; neither value is stored in source control. Names use the first eight characters of the subscription identifier to avoid global collisions. All user-managed foundation resources are created in `mcmc-deployment-rg`.

The foundation owns the `MCMC MCP API` and `MCMC MCP CLI` Entra registrations and their service principals. The API exposes the user-consentable `access_as_user` delegated scope under the `api://example.onmicrosoft.com/mcmc-mcp` identifier URI. Entra v2 access tokens use the API client ID as the `aud` claim, while native clients request the fully qualified URI-based scope. The CLI is a nonsecret native public client configured for device-code authentication and declares the delegated API permission. Terraform creates neither application secrets nor an administrator consent grant; each demonstration user consents interactively when tenant policy permits.

The foundation also owns disposable cloud-only users James, Jane, and Bill under the verified tenant domain. Their generated initial passwords require replacement at first interactive sign-in. Authorization uses their immutable Entra object identifiers: James maps to `CUST-1001` and `CUST-1002`, Jane maps to `CUST-1003` and `CUST-1004`, and Bill maps to no customers.

Terraform writes the tenant, application, scope, user principal name, object identifier, and initial-password values to the gitignored root `.env` file with mode `0600`. Passwords remain sensitive in local Foundation state, are not Terraform outputs, and are intended only for initial interactive browser sign-in. The CLI must not read them.

The private Container Apps environment uses delegated subnet `10.58.0.64/27`, internal ingress, and disabled public network access. Azure Container Apps requires the separate platform-managed `mcmc-container-apps-managed-rg` resource group for its infrastructure. The environment currently has private static IP `10.58.0.82`.

API Management service `mcmc-<subscription-prefix>-apim` uses the Standard v2 SKU and outbound VNet integration through the dedicated `10.58.0.0/27` subnet delegated to `Microsoft.Web/serverFarms`. The VNet-linked private DNS zone for the Container Apps environment resolves its wildcard host to `10.58.0.82`, allowing APIM to reach private Container App ingress. Standard v2 retains a public gateway; Layer 3 publishes the trusted MCP endpoint at `https://mcmc-<subscription-prefix>-apim.azure-api.net/mcp` and requires an active API-scoped APIM subscription key. The Terraform-managed primary key is available only through the sensitive `api_management_subscription_primary_key` output. OAuth authentication and user-level authorization remain separate follow-up work.

The foundation ACR uses the Basic SKU with administrator credentials disabled. Public registry access remains enabled so authenticated developers can push images from the development environment using Microsoft Entra ID. Container Apps must pull images through managed identity and `AcrPull` role assignment in the application layer.

The trusted application is `mcmc-mcp-trusted`. It runs the exact image digest from Layer 2, uses `AUTH_MODE=trusted`, listens on port `8000`, and exposes `/health` startup, readiness, and liveness probes. Its stable private FQDN is `mcmc-mcp-trusted.politeisland-4556c29f.swedencentral.azurecontainerapps.io`. The revision is healthy with one replica, and public DNS does not resolve outside the private environment path.

Layer 3 configures API Management operations for `GET`, `POST`, and `DELETE` on `/mcp` and `GET` on `/health`. Its API policy disables request and response buffering for Streamable HTTP forwarding. Live gateway tests returned HTTP 401 without a subscription key and HTTP 200 with the managed key for both `/health` and MCP initialization, proving subscription enforcement, APIM outbound VNet integration, private DNS resolution, and private backend connectivity.

Terraform authenticates through the current Azure CLI session. Terragrunt stores state locally under the repository-root `.terraform-state/` directory, which is excluded from source control. The operator must verify the selected Azure account before every plan, apply, or destroy.

## Commands

Run foundation commands from `msft-mcmc-deployment-infra/terraform/01-foundation/` through Terragrunt. Never commit Terraform state, plan files, generated container artifacts, or `.terragrunt-cache/` content.

Set the Azure account context before running Terragrunt:

```bash
export ARM_SUBSCRIPTION_ID="<azure-subscription-id>"
export ARM_TENANT_ID="<entra-tenant-id>"
```

Build and push the next versioned image:

```bash
msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/02-container/buildandpush.sh
```

The script reads the root `version` file, replaces `VERSION_REVISION` with the current branch commit count, increments `VERSION_BUILD`, and atomically persists both values before contacting Azure. It constructs the immutable dotted tag `VERSION_MAJOR.VERSION_MINOR.VERSION_REVISION.VERSION_BUILD`, so failed executions still consume a build number. The script publishes the fully qualified `msft-mcmc-mcp-service` artifact to the registry from foundation outputs, rejects existing tags, uses the current Entra-authenticated Azure CLI session, and prints the pushed digest. The validated image `msft-mcmc-mcp-service:0.0.1.3` has digest `sha256:83d9ca5c9590a758002f098061ab621face777bd44e12a9b95f0d36eb35dbf7e`.

Run application commands from `msft-mcmc-deployment-infra/terraform/03-application/` through Terragrunt. Layer 3 reads foundation outputs and the Layer 2 `image.json` manifest; it does not query or mutate ACR during planning.

Detailed deployment, verification, and teardown commands are added as their corresponding MCMC001 tasks are implemented and validated.
