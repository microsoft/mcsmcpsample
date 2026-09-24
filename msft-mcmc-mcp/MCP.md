# MCP

The MCP module owns the configurable Model Context Protocol server, its Azure Functions application package, its demonstration CLI, and application tests.

The module coordinate is `msft-mcmc-mcp`, derived from the repository organization, product, and module identity files.

## Runtime and SDK

The module targets Python 3.12 on Azure Functions runtime v4 using the Python v2 programming model. It uses the official MCP Python SDK v2 for Streamable HTTP protocol handling and `uv` for local dependency and environment management.

Production dependencies are pinned in `requirements.txt` for Azure Functions remote builds and mirrored in `pyproject.toml`. Development dependencies and tool configuration are defined in `pyproject.toml`.

## Structure

- `src/mcmc_mcp/` contains reusable application code.
- `tests/` contains unit and protocol tests.
- `host.json` configures the Azure Functions host with no route prefix so the MCP transport can be served at `/mcp`.

## HTTP Application

The Azure Functions v2 entry point adapts the SDK's ASGI application directly. It exposes stateless Streamable HTTP at `POST /mcp` and an unauthenticated `GET /health` endpoint. The superseded SSE transport is not registered.

Every HTTP response includes `x-correlation-id`. A caller-supplied identifier is retained only when it contains 1-128 ASCII letters, digits, dots, underscores, or hyphens; otherwise the server generates a UUID. Completion logs contain only this identifier, method, route, status, and duration. Request headers, authorization values, customer payloads, and response bodies are not logged.

## Authentication Modes

`AUTH_MODE` is required and accepts only `trusted` or `entra`. `MCP_ALLOWED_HOSTS` is a comma-separated DNS-rebinding allowlist and defaults to local development hosts.

In `trusted` mode, the application rejects native OAuth configuration and returns the complete fictitious catalog because APIM owns authentication and authorization. This mode must eventually be reachable only through APIM; private ingress enforcement is delivered by the deployment and APIM tickets.

In `entra` mode, application creation requires both MCP OAuth settings and a token verifier. Tool authorization consumes only the verifier-produced access token and maps its immutable `oid` claim to customer numbers. A missing, malformed, or unmapped `oid` receives an empty access set. Entra JWT verification and environment-backed object mappings are intentionally completed in Phase 3 of `MCMC001`.

## Customer Tools

`list_accessible_customers` takes no tool arguments and returns an object with a `customers` array. `get_accessible_customer` requires a `customer_number` string and returns an object whose `customer` field contains a customer or `null`. Each customer contains `customer_number`, `name`, `phone_number`, and `email` strings.

List results use stable catalog order. A lookup for an inaccessible or nonexistent number produces the same generic not-found outcome so the caller cannot distinguish the two cases.

The local demonstration access matrix is:

| User | Accessible customers |
| --- | --- |
| James | `CUST-1001`, `CUST-1002` |
| Jane | `CUST-1003`, `CUST-1004` |
| Bill | None |

These names identify test profiles only. In `entra` mode, a later infrastructure phase maps each profile to the corresponding validated Entra `oid`; display names are never authorization subjects. In `trusted` mode, APIM owns authorization and the server exposes the complete fictitious catalog.