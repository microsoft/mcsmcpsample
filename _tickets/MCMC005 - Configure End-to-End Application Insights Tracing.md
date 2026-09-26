---
template: "[[Ticket]]"
kind: ticket
tags:
  - ticket
code: MCMC005
aliases:
  - MCMC005
name: Configure End-to-End Application Insights Tracing
ticket_status: "[[Backlog]]"
---
# Specification

Configure workspace-based Azure Application Insights and distributed tracing so an operator can follow a Microsoft Copilot Studio MCP tool invocation through Azure API Management (APIM) to the selected MCP server deployment.

Use W3C Trace Context (`traceparent` and `tracestate`) as the primary trace contract across components that support it. First verify what trace and correlation context Copilot Studio emits, exposes, and forwards for MCP tool calls. If Copilot Studio cannot participate in the same distributed trace, capture the strongest supported Copilot Studio conversation, activity, or tool-invocation identifier and document a deterministic, privacy-safe correlation method to the first APIM trace rather than claiming unsupported parent-child continuity.

Cover both the native token-validation route and the APIM token-validation route created by `MCMC002`, initially through the public-ingress agent from `MCMC003`. Keep the design reusable for the private-ingress agent in `MCMC004`. Telemetry must not record authorization headers, access tokens, client secrets, MCP arguments, customer records, response bodies, or Copilot conversation content.

# Technical Solution

Provision a workspace-based Application Insights resource connected to the existing Log Analytics workspace, using the infrastructure layer that owns shared monitoring resources. Export only the identifiers and connection settings required by APIM and the MCP deployments; do not store secrets or environment-specific connection strings in source control.

Configure APIM Application Insights diagnostics to emit request and backend dependency telemetry for both MCP routes. Preserve valid incoming W3C trace headers, generate standards-compliant context when none is supplied, and propagate trace context to the private Container Apps backends without changing OAuth behavior or exposing tracing headers that contain unsafe values. Retain the existing sanitized `x-correlation-id` as an operational fallback and searchable attribute, but do not use it as a substitute for W3C parent-child relationships where those relationships are supported.

Instrument the Python MCP service with the Azure Monitor OpenTelemetry distribution and supported ASGI instrumentation. Create server spans for MCP HTTP requests, honor valid incoming W3C context, attach only low-cardinality route and deployment attributes, and correlate existing structured completion logs with the active trace and span identifiers. Configure sampling explicitly and consistently enough to preserve complete demonstration traces, with a documented production setting that controls ingestion cost.

Enable the supported Copilot Studio Application Insights integration and determine whether MCP tool invocations expose or propagate W3C context. Map only stable, non-sensitive Copilot Studio identifiers needed for correlation. Where direct propagation is unavailable, document the exact observable boundary and provide a reproducible time-window and identifier-based query that links the Copilot Studio tool invocation to APIM without presenting the result as a single distributed trace.

Provide saved Kusto queries or a workbook view that shows the ordered flow, parent-child relationships, route, backend deployment, result code, and duration. Include diagnostics for broken context propagation and sampling gaps. Use role names and resource attributes that clearly distinguish Copilot Studio, APIM, the native-validation MCP deployment, and the trusted MCP deployment.

# Definition of Done

- Current Microsoft documentation and a live proof establish which Application Insights fields and trace headers Copilot Studio emits, exposes, and forwards for MCP tool calls.
- A workspace-based Application Insights resource is provisioned against the existing Log Analytics workspace without duplicating monitoring resources.
- APIM emits request and backend dependency telemetry for both MCP routes and propagates valid W3C trace context to each MCP backend.
- Both MCP deployments emit correlated OpenTelemetry server spans and structured logs with distinct cloud role names.
- A successful invocation through each authentication route can be followed from the earliest observable Copilot Studio event through APIM to the correct MCP deployment.
- Where Copilot Studio cannot join the W3C trace, its telemetry boundary and the deterministic correlation fallback are demonstrated and documented accurately.
- Failed authentication, APIM rejection, backend failure, and timeout scenarios are distinguishable at the component where each failure occurs.
- Trace and correlation behavior remains reusable when `MCMC004` replaces public ingress with private ingress.
- Sampling is explicitly configured, complete validation traces are retained, and production cost controls are documented.
- Application Insights, Log Analytics, and exported diagnostic settings exclude credentials, tokens, secrets, MCP arguments, customer data, response bodies, and Copilot conversation content.
- Automated tests validate trace-header handling, telemetry configuration, redaction controls, and infrastructure definitions where those behaviors can be tested without live services.
- Saved Kusto queries or a workbook reconstruct the flow and identify missing spans or correlation gaps.
- Deployment, validation, troubleshooting, retention, cost, and teardown procedures are documented.

# Execution Plan

## Phase 1 - Confirm Product Capabilities and Trace Contract

- [ ] Verify current Copilot Studio, APIM, Application Insights, and Azure Monitor OpenTelemetry tracing capabilities against official Microsoft documentation.
- [ ] Run a minimal Copilot Studio MCP invocation and record the available trace headers, telemetry fields, conversation identifiers, and tool-invocation identifiers without retaining sensitive content.
- [ ] Define the W3C propagation contract, the supported Copilot Studio boundary, and the deterministic fallback correlation contract.
- [ ] Define a validation matrix for both authentication routes and successful, rejected, failed, and timed-out requests.

## Phase 2 - Provision Shared Application Insights Resources

- [ ] Add a workspace-based Application Insights resource to the infrastructure layer that owns shared monitoring.
- [ ] Export the non-secret resource identifiers and runtime configuration required by APIM and both MCP deployments.
- [ ] Configure retention, sampling, and cost controls for demonstration and production usage.
- [ ] Format, validate, and review a saved Terraform plan before applying it.

## Phase 3 - Instrument APIM and the MCP Service

- [ ] Configure APIM Application Insights logging and diagnostics for gateway requests and backend dependencies on both MCP routes.
- [ ] Preserve or generate valid W3C trace context in APIM and forward it to the selected private backend while retaining sanitized `x-correlation-id` fallback behavior.
- [ ] Add Azure Monitor OpenTelemetry and supported ASGI instrumentation to the MCP service.
- [ ] Correlate sanitized structured completion logs with active trace and span identifiers and assign distinct cloud role names to both deployments.
- [ ] Add focused tests for trace propagation, invalid-header handling, telemetry settings, and sensitive-data exclusion.

## Phase 4 - Integrate Copilot Studio Telemetry

- [ ] Enable the supported Copilot Studio Application Insights integration for the public-ingress demonstration agent.
- [ ] Configure only the non-sensitive event properties required to identify MCP tool invocation and route selection.
- [ ] Prove W3C parent-child continuity into APIM where supported, or implement and document the verified correlation fallback where it is not supported.
- [ ] Confirm the design and configuration can be applied to the private-ingress agent without changing the trace contract.

## Phase 5 - Validate and Operationalize Tracing

- [ ] Invoke both MCP authentication routes from Copilot Studio and reconstruct each flow from the earliest observable event through APIM to the correct MCP deployment.
- [ ] Validate rejected authentication, APIM failure, backend failure, and timeout traces at their failure boundaries.
- [ ] Inspect collected telemetry for credentials, tokens, MCP arguments, customer data, response bodies, conversation content, and unexpected high-cardinality attributes.
- [ ] Create saved Kusto queries or a workbook for end-to-end flow, latency, errors, missing spans, and correlation gaps.
- [ ] Run service tests and infrastructure validation, then update product, deployment, and affected module documentation with setup, validation, troubleshooting, retention, cost, and teardown guidance.