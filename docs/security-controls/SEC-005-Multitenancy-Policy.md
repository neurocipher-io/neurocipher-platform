id: SEC-005
title: Multitenancy policy
owner: Platform
status: Final v1.0
last_reviewed: 2025-11-20

SEC-005 Multitenancy policy

## Purpose and scope

Define the canonical tenant identifier, what it protects, and how it flows through the Neurocipher Data Pipeline so every layer can make consistent isolation, quota, and observability decisions. This policy governs control-plane interactions (API, admin, and tooling), data-plane storage/compute (Postgres, S3, vector indexes), and the observability/control channels (logs, events, traces, metrics).

## References

- REF-001 Documentation Standard
- API-001 Edge and Gateway Architecture
- OBS-001 Observability Strategy and Telemetry Standards
- SRG-001 Schema Registry

## Tenant identifier contract

- The canonical identifier is the `Tenant-Id` header and claim, always formatted as a ULID (26 characters, Crockford base32, uppercase). The gateway normalizes casing, validates the checksum, and rejects any request that fails the ULID pattern or that is missing the header.
- Token-based flows (OIDC/JWT) embed `tenant_id` as a claim and the gateway asserts the header matches the claim before routing. SigV4 flows copy the role-mapped tenant via gateway policies and fail fast when the header deviates.
- Internal services may also accept `X-Tenant-Id` for legacy adapters, but they must copy it into the canonical `Tenant-Id` field before downstream calls and log the canonical value.
- `Tenant-Id` must be present on ingested events, control-plane requests, administrative tooling, metrics, and audit events; do not infer tenant context from other headers.

## Isolation guarantees

### Data plane

- Row-level isolation via Postgres RLS triggers that require `current_setting('app.tenant_id')` to match the tenant column; the triggers are defined for every tenant-scoped table described in DM-001..DM-004.
- S3 and object stores use tenant-specific prefixes/buckets with least-privilege IAM policies, envelope encryption via per-tenant KMS data keys, and S3 bucket policies keyed by the tenant ULID.
- Vector indexes and other caches are sharded per tenant when possible; indexes that must be shared enforce `tenant_id` filters in the query layer and do not allow cross-tenant joins.

### Control plane

- API Gateway and ALB policies enforce tenant-scoped access and pass tenant identifiers to services via headers; service-side policy engines (OPA/Cedar) double-check tenant claims before acting.
- Administrative consoles, CLI tooling, and automation workspaces have dedicated tenant contexts and audit trails; cross-tenant operations require explicit consent through the data-model governance process described in DM-005 and GOV-001.
- Secrets, IAM roles, and artifact registries are partitioned by tenant or marked as read-only for shared roles; any control-plane cross-tenant audit must reference `Tenant-Id` and be logged.

### Network plane

- Public APIs expose only the `Tenant-Id` context; backend-to-backend communication happens over SigV4 with IAM roles whose trust policies include the tenant ULID.
- Private VPC endpoints isolate tenant workloads inside AWS subnets; multi-tenant traffic between accounts uses VPC peering or PrivateLink with tenant-aware routing filters.
- mTLS is optional for partner-integrations, but when enabled the certs carry SCID/tenant identifiers that are validated against the header before the request is promoted.

## Quotas and throttling

- Every tenant inherits a plan (`Free`, `Pro`, `Enterprise`) with documented rate limits, burst windows, and daily quotas defined in API-001 §9. The gateway enforces per-tenant token buckets and annotates responses with `X-RateLimit-Limit`, `-Remaining`, and `-Reset`.
- Tenants may request temporary overrides for burst needs; the request must annotate the target `Tenant-Id` and include justification. Overrides are timeboxed and recorded for auditing.
- Retry budgets are tenant-scoped too: the gateway tracks 5xx and 429 responses per tenant. When a tenant exceeds retry thresholds, throttling escalates and the tenant receives `429 RATE_LIMITED` with `retry_after_seconds` in the payload defined by the API error catalog.

## Tenant identifier propagation

- Ingest pipelines and SDKs must attach `Tenant-Id` to every HTTP request, EventBridge/ECS events (e.g., `tenant_id` field), and message topics/queues metadata (headers for Kafka/SQS/SNS) so downstream services see the same ULID.
- Logs (structured JSON) include `tenant_id` in every record; metrics (Prometheus/OpenTelemetry) tag high-cardinality metrics with `tenant_id` and low-cardinality metrics emit aggregated tenant counts anchored by the ULID.
- Traces carry `Tenant-Id` via B3 or W3C baggage; when telemetry flows cross services, each segment copies the header into span attributes and logs.
- Audit events, schema change records, and governance actions include the originating `Tenant-Id` field so the schema registry, data quality gates, and lineage records can tie back to the tenant policy.
