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

API Management service `mcmc-<subscription-prefix>-apim` uses the Standard v2 SKU and outbound VNet integration through the dedicated `10.58.0.0/27` subnet delegated to `Microsoft.Web/serverFarms`. The VNet-linked private DNS zone for the Container Apps environment resolves its wildcard host to `10.58.0.82`, allowing APIM to reach private Container App ingress. Standard v2 retains a public gateway; Layer 3 publishes the trusted MCP endpoint at `https://mcmc-<subscription-prefix>-apim.azure-api.net/mcp` and requires an active API-scoped APIM subscription key. The Terraform-managed primary key is available only through the sensitive `api_management_subscription_primary_key` output.

The foundation ACR uses the Basic SKU with administrator credentials disabled. Public registry access remains enabled so authenticated developers can push images from the development environment using Microsoft Entra ID. Container Apps must pull images through managed identity and `AcrPull` role assignment in the application layer.

Layer 3 deploys `mcmc-mcp-trusted` and `mcmc-mcp-entra` from the same exact Layer 2 image digest with one replica each, internal environment ingress on port `8000`, and `/health` startup, readiness, and liveness probes. The trusted app uses `AUTH_MODE=trusted`. The Entra app uses `AUTH_MODE=entra`, validates v2 tokens against the Foundation tenant and API client-ID audience, requires the `access_as_user` delegated scope, and authorizes immutable object identifiers through the Foundation access policy. Both stable FQDNs use the private Container Apps environment domain and do not resolve through public DNS.

The deployed Entra access matrix was validated from an Azure management-plane exec shell in the running private replica. This temporary authorized path resolved the private HTTPS endpoint without adding public ingress or an APIM route; independent device-code runs returned the expected James, Jane, and Bill customer sets. A separate exec shell in the trusted replica used the official MCP client without an authorization header, discovered both customer tools, and returned all four fictitious customers.

A tagged MCP discovery request from the temporary private client path propagated the same client-generated correlation identifier into the trusted Container App telemetry. The matching completion records contained only the identifier, duration, event name, HTTP method, request path, and status code; no authorization headers, tokens, customer payloads, or response bodies were logged.

Layer 3 configures API Management operations for `GET`, `POST`, and `DELETE` on `/mcp` and `GET` on `/health`. Its API policy disables request and response buffering for Streamable HTTP forwarding. Live gateway tests returned HTTP 401 without a subscription key and HTTP 200 with the managed key for both `/health` and MCP initialization, proving subscription enforcement, APIM outbound VNet integration, private DNS resolution, and private backend connectivity. A uniquely tagged health request also produced the same sanitized correlation identifier in the APIM response and private Container App telemetry.

Terraform authenticates through the current Azure CLI session. Terragrunt stores state locally under the repository-root `.terraform-state/` directory, which is excluded from source control. The operator must verify the selected Azure account before every plan, apply, or destroy.

## Security Boundary

MCMC001 provides private Container Apps environment isolation, private DNS, APIM outbound VNet reachability, and an API-scoped subscription key on the trusted APIM route. It does not yet make APIM the exclusive authenticated path to both backends. `MCMC002` owns the governed bearer-token pass-through route to `mcmc-mcp-entra`, the APIM `validate-jwt` route to `mcmc-mcp-trusted`, and enforcement that prevents bypassing APIM authentication for the trusted backend.

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
terragrunt plan -out=/tmp/mcmc-foundation.tfplan
terragrunt apply /tmp/mcmc-foundation.tfplan
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
terragrunt plan -out=/tmp/mcmc-application.tfplan
terragrunt apply /tmp/mcmc-application.tfplan
cd -
```

## Operation

Inspect both app revisions and confirm the immutable images match:

```bash
for app in mcmc-mcp-trusted mcmc-mcp-entra; do
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
	--name mcmc-mcp-entra \
	--tail 50 \
	--format text
```

Verify the trusted health endpoint through APIM without printing its subscription key:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
subscription_key="$(terragrunt output -raw api_management_subscription_primary_key)"
health_url="$(terragrunt output -raw api_management_health_url)"
curl --fail --silent --show-error \
	-H "Ocp-Apim-Subscription-Key: ${subscription_key}" \
	"${health_url}"
unset subscription_key
cd -
```

Use a VNet-connected client for the private Entra endpoint. For disposable validation, `az containerapp exec` can open a management-plane shell in a running replica without changing ingress. Pass only the CLI's allowlisted tenant, public-client, scope, UPN, and OID values; never transfer initial passwords, access tokens, or the complete root `.env`.

## Verification

Run static Terraform checks and confirm live application state has converged:

```bash
terraform -chdir=msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/01-foundation validate
terraform -chdir=msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application validate

cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
terragrunt plan -detailed-exitcode
cd -
```

Exit code `0` from the final command means live infrastructure matches configuration; exit code `2` means a nonempty plan requires review. Both Container App FQDNs must fail public DNS resolution outside the private network path. Missing or invalid APIM subscription keys must fail, while the managed key must return `200` from `/health`.

## Teardown

Destroy the application layer before Foundation so Container Apps, APIM application configuration, managed identity, and `AcrPull` assignment are removed before their dependencies. Save the nonsensitive identity handles needed for post-destroy verification before destroying Foundation:

```bash
cd msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/03-application
terragrunt plan -destroy -out=/tmp/mcmc-application-destroy.tfplan
terragrunt apply /tmp/mcmc-application-destroy.tfplan
cd ../01-foundation

api_client_id="$(terragrunt output -raw entra_mcp_api_client_id)"
cli_client_id="$(terragrunt output -raw entra_mcp_cli_client_id)"
demo_upns="$(terragrunt output -json entra_demo_user_principal_names)"

terragrunt plan -destroy -out=/tmp/mcmc-foundation-destroy.tfplan
terragrunt apply /tmp/mcmc-foundation-destroy.tfplan
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
rm -f .terraform-state/smoke-application.terraform.tfstate*
rm -f .terraform-state/smoke-foundation.terraform.tfstate*
rm -f msft-mcmc-deployment/msft-mcmc-deployment-infra/terraform/02-container/image.json
unset api_client_id cli_client_id demo_upns
```
