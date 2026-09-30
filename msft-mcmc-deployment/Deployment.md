# Deployment

The deployment module owns Azure infrastructure and deployment orchestration for the Microsoft Copilot Studio MCP demonstration.

The module coordinate is `msft-mcmc-deployment`. Its `msft-mcmc-deployment-infra` component owns the ordered Terraform and deployment layers, local state configuration, and infrastructure tests.

## Structure

- `msft-mcmc-deployment-infra/terraform/root.hcl` defines shared Azure context, deterministic names, and tags.
- `msft-mcmc-deployment-infra/terraform/01-foundation/` contains the foundation Terraform and Terragrunt configuration, stores state in `.terraform-state/foundation.terraform.tfstate`, and owns the resource group, ACR, virtual network, delegated subnets, Log Analytics workspace, private Container Apps environment, private DNS, Standard v2 API Management service, and shared Microsoft Entra identities.
- `msft-mcmc-deployment-infra/terraform/02-container/buildandpush.sh` builds and pushes an immutable MCP service image through ACR Build and writes the gitignored `image.json` handoff manifest after a successful push.
- `msft-mcmc-deployment-infra/terraform/03-application/` contains the application Terraform and Terragrunt configuration, stores state in `.terraform-state/application.terraform.tfstate`, and models the two Container Apps as the `gateway` and `native` deployment roles. It owns both apps, their shared `apps_identity` user-assigned identity and `AcrPull` assignment, and the governed API Management APIs and policies.

## Environment

The demonstration environment targets Sweden Central. Operators provide the target account context through `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID`; neither value is stored in source control. Names use the first eight characters of the subscription identifier to avoid global collisions. The shared Log Analytics workspace is named `mcmc-<subscription-prefix>-logs`, the private Container Apps environment is named `mcmc-container-apps`, and all user-managed foundation resources are created in `mcmc-deployment-rg`. Deployment resources use the `mcmc-copilot-studio-demo` purpose tag.

The foundation owns the `MCMC MCP API` and `MCMC MCP CLI` Entra registrations and their service principals. The API exposes the user-consentable `access_as_user` delegated scope under the `api://example.onmicrosoft.com/mcmc-mcp` identifier URI and emits security-group membership in access tokens. Entra v2 access tokens use the API client ID as the `aud` claim, while native clients request the fully qualified URI-based scope. The CLI is a nonsecret native public client configured for device-code authentication and declares the delegated API permission. Terraform creates neither application secrets nor an administrator consent grant; each demonstration user consents interactively when tenant policy permits.

The foundation also owns disposable cloud-only users James, Jane, and Bill under the verified tenant domain. Their generated initial passwords require replacement at first interactive sign-in. Native authorization uses their immutable Entra object identifiers: James maps to `CUST-1001` and `CUST-1002`, Jane maps to `CUST-1003` and `CUST-1004`, and Bill maps to no customers. Terraform also owns the `mcmc-customer-admins` security group used by gateway authorization. James, Jane, and the deployment administrator are members; Bill is excluded.

Terraform writes the tenant, application, scope, user principal name, object identifier, and initial-password values to the gitignored root `.env` file with mode `0600`. Passwords remain sensitive in local Foundation state, are not Terraform outputs, and are intended only for initial interactive browser sign-in. The CLI must not read them.

The private Container Apps environment uses delegated subnet `10.58.0.64/27`, internal ingress, and disabled public network access. Azure Container Apps requires the separate platform-managed `mcmc-container-apps-managed-rg` resource group for its infrastructure. The environment currently has private static IP `10.58.0.93`.

Public API Management service `mcmc-<subscription-prefix>-apim` uses the Standard v2 SKU and outbound VNet integration through the dedicated `10.58.0.0/27` subnet delegated to `Microsoft.Web/serverFarms`. Its public network access remains enabled and it has no private endpoint. Layer 3 publishes `https://mcmc-<subscription-prefix>-apim.azure-api.net/native/mcp` for bearer pass-through to the Entra-mode service and `https://mcmc-<subscription-prefix>-apim.azure-api.net/gateway/mcp` for APIM bearer validation before trusted-mode forwarding. The existing MCMC003 agents continue to use these unchanged URLs.

Private API Management service `mcmc-<subscription-prefix>-apim-private` also uses Standard v2 but has its own required outbound VNet integration subnet at `10.58.0.32/27`. Its approved `Gateway` private endpoint resides in `10.58.0.96/27`; `privatelink.azure-api.net` resolves the default Microsoft-managed `azure-api.net` hostname to `10.58.0.100` from linked virtual networks. Public network access is disabled. Layer 3 replicates both governed MCP routes, operations, protected-resource metadata, OAuth boundaries, streaming behavior, diagnostics, and correlation handling on this instance. This design requires no custom domain, public certificate, or reverse proxy.

Power Platform network injection for the Japan environment uses `mcmc-power-platform-japaneast-vnet` (`10.59.0.0/24`) and `mcmc-power-platform-japanwest-vnet` (`10.60.0.0/24`). Each VNet has an equal `/27` subnet delegated to `Microsoft.PowerPlatform/enterprisePolicies`, bidirectional global peering to the Sweden Central deployment VNet, and a link to the APIM private DNS zone. The `mcmc-private-connectivity` enterprise policy references both subnets, and the deployment administrator has Reader access to it. `MCMC Import Test` currently reports Basic governance rather than Managed Environment status. A Power Platform administrator must enable Managed Environments and associate this enterprise policy before creating the private connectors.

The foundation ACR uses the Basic SKU with administrator credentials disabled. Public registry access remains enabled so authenticated developers can push images from the development environment using Microsoft Entra ID. Container Apps must pull images through managed identity and `AcrPull` role assignment in the application layer.

Layer 3 deploys `mcmc-mcp-gateway` and `mcmc-mcp-native` from the same exact Layer 2 image digest with one replica each, internal environment ingress on port `8000`, and `/health` startup, readiness, and liveness probes. Both apps share the `mcmc-mcp-apps-identity` user-assigned identity for image pulls. Each app permits ingress only from the public and private APIM integration subnets. The gateway app uses `AUTH_MODE=trusted`. The native app uses `AUTH_MODE=entra`, validates v2 tokens against the Foundation tenant and API client-ID audience, requires the `access_as_user` delegated scope, and authorizes immutable object identifiers through the Foundation access policy. Both stable FQDNs use the private Container Apps environment domain and do not resolve through public DNS.

The native route returns only James's two assigned customers, only Jane's two assigned customers, and an empty list for Bill. The gateway route accepts tokens with the required tenant, audience, scope, and `mcmc-customer-admins` group claim, removes the bearer header, and returns all four fictitious customers from the intentionally unfiltered trusted service. An authenticated nonmember receives `403 Forbidden` before backend invocation.

A tagged MCP request propagates a sanitized `x-correlation-id` through either APIM instance to Container App telemetry. Both APIM instances send resource logs and metrics to the existing Log Analytics workspace with request and response body logging disabled. Application completion records contain only the identifier, duration, event name, HTTP method, request path, and status code; authorization headers, tokens, customer payloads, and response bodies are not logged.

Layer 3 configures `GET`, `POST`, and `DELETE` MCP operations under both route prefixes and publishes RFC 9728 protected-resource metadata for each route. Shared policy controls require HTTPS, cap request bodies at 1 MiB, rate-limit by source address, forward with a 300-second timeout and no body buffering, sanitize correlation identifiers, and return sanitized errors. The gateway route validates signed tokens with tenant-specific v2 metadata, exact issuer, API client-ID audience, expiration, tenant, and delegated scope, then requires the Foundation-managed customer-administrator group before deleting `Authorization`. Missing, malformed, and wrong-audience tokens return `401`; authenticated nonmembers return `403`; an over-limit request returns `413`. The retired root subscription-key API has been removed.

Terraform authenticates through the current Azure CLI session. Terragrunt stores state locally under the repository-root `.terraform-state/` directory, which is excluded from source control. The operator must verify the selected Azure account before every plan, apply, or destroy.

## Security Boundary

The two APIM instances are the only application ingress paths to both Container Apps. Container App IP restrictions allow only `10.58.0.0/27` and `10.58.0.32/27`, the dedicated public and private APIM integration subnets. The native route preserves the bearer token for validation and per-`oid` authorization by `mcmc-mcp-native`. The gateway route validates the bearer token, delegated scope, and `mcmc-customer-admins` membership at APIM, removes the header, and invokes `mcmc-mcp-gateway`, which deliberately returns the complete fictitious catalog. Private DNS and the internal Container Apps environment prevent direct public backend resolution.

## Configuration

Run Terraform only through the layer's Terragrunt entry point. State, plans, `.env`, `02-container/image.json`, and `.terragrunt-cache/` are generated or sensitive and must remain excluded from source control.

Authenticate Azure CLI, verify the selected account, and export the matching provider context from the repository root:

```bash
az login
az account show --query '{subscription:id,tenant:tenantId,name:name}' --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId --output tsv)"
```

The Foundation Terragrunt inputs define the verified Entra domain, region, resource names, and root `.env` destination. Layer 3 reads only Foundation outputs plus the immutable image repository and digest in `02-container/image.json`. Do not copy the password-bearing root `.env` into a container or remote client.

## Deployment

Plan and apply Foundation first:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/01-foundation
terragrunt run -- plan -out=/tmp/mcmc-foundation.tfplan
terragrunt run -- apply /tmp/mcmc-foundation.tfplan
cd -
```

Build and push the next versioned image through Entra-authenticated ACR Build:

```bash
msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/02-container/buildandpush.sh
```

The script reads the root `version` file, replaces `VERSION_REVISION` with the current branch commit count, increments `VERSION_BUILD`, and atomically persists both values before contacting Azure. It rejects existing tags and writes the pushed digest to the generated image manifest. Failed executions still consume a build number. The validated image `msft-mcmc-mcp-service:0.0.3.5` has digest `sha256:165930594cff15507b0ed3d885c554c115bd9a40d8bc0aa8587f5f9c4f472a2f`.

Plan and apply the application layer last:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
terragrunt run -- plan -out=/tmp/mcmc-application.tfplan
terragrunt run -- apply /tmp/mcmc-application.tfplan
cd -
```

## Operation

Inspect both app revisions and confirm the immutable images match:

```bash
for app in mcmc-mcp-gateway mcmc-mcp-native; do
	az containerapp show \
		--resource-group mcmc-deployment-rg \
		--name "$app" \
		--query '{name:name,status:properties.runningStatus,revision:properties.latestReadyRevisionName,image:properties.template.containers[0].image}' \
		--output table
done
```

Inspect sanitized application logs without enabling request or response body logging:

```bash
az containerapp logs show \
	--resource-group mcmc-deployment-rg \
	--name mcmc-mcp-native \
	--tail 50 \
	--format text
```

Read the public route URLs without exposing any credentials:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
native_url="$(terragrunt run -- output -raw api_management_native_mcp_url)"
gateway_url="$(terragrunt run -- output -raw api_management_gateway_mcp_url)"
cd -
```

Run the device-code CLI through either route. Native mode applies the per-user access matrix; gateway mode permits customer-administrator group members and returns the trusted service's complete fictitious catalog:

```bash
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user james --url "$native_url"
uv run --project msft-mcmc-mcp/msft-mcmc-mcp-service mcp --user james --url "$gateway_url"
unset native_url gateway_url
```

The private routes use the same paths on the private APIM hostname. They resolve only through the linked virtual networks after public network access is disabled:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
private_native_url="$(terragrunt run -- output -raw private_api_management_native_mcp_url)"
private_gateway_url="$(terragrunt run -- output -raw private_api_management_gateway_mcp_url)"
cd -
```

## Verification

Generate reviewed Foundation and Application plans and their JSON representations:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/01-foundation
terragrunt run -- plan -out=/tmp/mcmc-foundation.tfplan
terragrunt run -- show -json /tmp/mcmc-foundation.tfplan > /tmp/mcmc-foundation.json
cd ../03-application
terragrunt run -- plan -out=/tmp/mcmc-application.tfplan
terragrunt run -- show -json /tmp/mcmc-application.tfplan > /tmp/mcmc-application.json
cd -
```

Run static checks, validate the rendered private-ingress foundation and APIM policies, and confirm live state has converged:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
terragrunt run -- validate
python ../../tests/validate_apim_plan.py /tmp/mcmc-application.json
cd ../01-foundation
terragrunt run -- validate
python ../../tests/validate_foundation_plan.py /tmp/mcmc-foundation.json
terragrunt run -- plan -detailed-exitcode
cd -
```

Exit code `0` from the final plan means live infrastructure matches configuration; exit code `2` means a nonempty plan requires review. Both Container App FQDNs must fail public DNS resolution outside the private network path. The public APIM metadata URLs must return `200` from the internet. The private APIM hostname must return `403` from the internet, resolve to its private endpoint from a linked virtual network, and return `200` for both metadata routes over that path. Missing, malformed, expired, incorrectly scoped, or incorrectly targeted bearer tokens must return `401` from the applicable route. A fresh gateway token for a group member must reach both tools, while a fresh token for Bill must return `403` without reaching the trusted backend.

## Downstream Handoff

`MCMC003` should configure Copilot Studio against the `/native/mcp` and `/gateway/mcp` public URLs. Both routes advertise the same delegated Entra scope through route-specific protected-resource metadata. Native mode demonstrates per-user customer authorization; gateway mode demonstrates APIM token, scope, and group enforcement against the intentionally unfiltered trusted service. Copilot Studio connections must be reauthenticated after group membership or token group-claim configuration changes so cached tokens are replaced.

`MCMC004` uses the private Standard v2 APIM routes at `https://mcmc-<subscription-prefix>-apim-private.azure-api.net/native/mcp` and `/gateway/mcp`. The private endpoint, private DNS zone, paired Japan Power Platform networks, and `mcmc-private-connectivity` enterprise policy are deployed. The remaining Power Platform administrator action is to confirm Managed Environment status and associate `MCMC Import Test` with that policy. The private agents can then use the default APIM hostname and Microsoft-managed TLS without custom DNS or certificates.

Before Power Platform association, roll back MCMC004 infrastructure by reverting its Terraform changes, applying the Application layer first to remove private APIs and backend allow rules, and then applying Foundation to remove the private APIM and networking. Review both plans before apply. The public APIM retains its original Terraform addresses throughout and must show no replacement or deletion.

## Teardown

Destroy the application layer before Foundation so Container Apps, APIM application configuration, managed identity, and `AcrPull` assignment are removed before their dependencies. Save the nonsensitive identity handles needed for post-destroy verification before destroying Foundation:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
terragrunt run -- plan -destroy -out=/tmp/mcmc-application-destroy.tfplan
terragrunt run -- apply /tmp/mcmc-application-destroy.tfplan
cd ../01-foundation

api_client_id="$(terragrunt run -- output -raw entra_mcp_api_client_id)"
cli_client_id="$(terragrunt run -- output -raw entra_mcp_cli_client_id)"
demo_upns="$(terragrunt run -- output -json entra_demo_user_principal_names)"

terragrunt run -- plan -destroy -out=/tmp/mcmc-foundation-destroy.tfplan
terragrunt run -- apply /tmp/mcmc-foundation-destroy.tfplan
cd -
```

Verify the resource group, Entra registrations, disposable users, and generated secret file are gone:

```bash
test "$(az group exists --name mcmc-deployment-rg)" = false

for app_id in "$api_client_id" "$cli_client_id"; do
	if az ad app show --id "$app_id" --output none 2>/dev/null; then
		echo "Entra application still exists: $app_id" >&2
		exit 1
	fi
done

while IFS= read -r upn; do
	if az ad user show --id "$upn" --output none 2>/dev/null; then
		echo "Disposable user still exists: $upn" >&2
		exit 1
	fi
done < <(jq -r '.[]' <<<"$demo_upns")

test ! -e .env
```

Only after Azure and Entra teardown verification succeeds, delete the local state files and backups that contained generated passwords, plus the generated image manifest:

```bash
rm -f .terraform-state/application.terraform.tfstate*
rm -f .terraform-state/foundation.terraform.tfstate*
rm -f msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/02-container/image.json
unset api_client_id cli_client_id demo_upns
```
