id: SRG-001
title: Schema Registry
owner: Data Platform Lead
status: For Board Review
last_reviewed: 2025-10-30

# SRG-001 Schema Registry

## Document control

- Version: 1.0.0
- Status: For Board Review
- Owner: Data Platform Lead
- Approvers: Architecture Board, Security Lead, SRE Lead, Data Steward
- Applies to: Neurocipher Data Pipeline
- Last updated: 2025-10-30

## Purpose

Define a single authoritative registry for all schemas used across ingestion, processing, and serving. Enforce reject on violation at ingress, safe schema evolution, provenance, audit, and discoverability.

## Scope

- In scope: event, file, table, feature, and public API schemas. Validation services, storage layout, lifecycle and governance, IAM and encryption, observability, and runbooks.
- Out of scope: UI presentation view models and documentation-only diagrams.

## References

- REF-001 Glossary and Standards Catalog
- GOV-001 Documentation Governance
- GOV-002 Change Control and Release Governance
- DM-001 Canonical Data Model
- DM-002 Logical Entity Relationship Model
- DM-003 Physical Schemas and Storage Map
- DM-004 Event Schemas and Contracts
- DM-005 Governance, Versioning and Migrations
- SEC-001 Threat Model and Mitigation Matrix
- SEC-002 IAM Policy and Trust Relationship Map
- SEC-003 Network Policy and Segmentation
- SEC-004 Secrets and KMS Rotation Playbook
- TEST-001 Testing and Quality Gates
- TEST-002 Continuous Integration and Test Automation
- TEST-003 Quality Assurance and Release Validation
- REL-001 High Availability and Fault Tolerance
- REL-002 Monitoring, Alerting and Incident Response
- OBS-001 Observability Strategy and Telemetry Standards
- OBS-002 Monitoring, Dashboards and Tracing
- OBS-003 Alerting, SLOs and Incident Response
- API-001 Edge and Gateway Architecture
- API-002 Service Contracts and Versioning

## Context and assumptions

- Multi-tenant pipeline. Strong tenant isolation.
- Cloud provider: AWS. Data lake on S3 with Apache Iceberg. Control plane is regional with optional multi-region failover.
- All documentation uses the term artifact. The term artefact is deprecated.

## Normative requirements

1. Every ingested record carries a valid `{schema_urn, version}`. Noncompliant payloads are rejected at ingress.
2. Compatibility mode is declared per stream or table and enforced at publish and read time.
3. Provenance captures `repo_url`, `commit_sha`, `change_ticket`, `build_id` for every version.
4. Schema blobs are immutable and content addressed by SHA-256 and signed with KMS.
5. Access control uses ABAC with tags for `tenant`, `region`, and `classification`.
6. p99 lookup latency for active versions ≤ 50 ms in prod.
7. Time to deactivate a faulty version ≤ 5 minutes using admin API.
8. Changes pass GOV-002 readiness gates before promotion.

## Architecture overview

### Components

- Registry API: CRUD, search, lifecycle, and validation endpoints.
- Validation service: format-aware validators for JSON Schema 2020-12, Avro 1.11, Protobuf 3, Iceberg table spec, and OpenAPI 3.1.
- Signer: digest signing with KMS CMKs. Deterministic signing pipeline.
- Storage: S3 versioned bucket for schema blobs and attachments.
- Metadata: DynamoDB tables for index, tags, lifecycle state, and audit pointers.
- Cache: API Gateway cache and Lambda extension LRU.
- Eventing: EventBridge bus for lifecycle events.
- Bridges: writers to Glue Data Catalog and OpenLineage.

### High level flow

1. Producer submits a schema PR and test vectors.
2. CI validates and publishes through Registry API.
3. Registry stores the blob in S3, signs the digest, writes metadata in DynamoDB, caches hot keys, and emits a lifecycle event.
4. Consumers resolve the schema URN and version at runtime or deploy-time using the read API or a pinned manifest.

## Storage layout

- S3 bucket: `nc-registry-{env}-{region}`
  - `schemas/{namespace}/{name}/{kind}/v{major}.{minor}.{patch}/schema.json`
  - `schemas/.../digest.sha256`
  - `schemas/.../signature.cms`
  - `attachments/{schema_id}/*`
- DynamoDB tables
  - `SchemaIndex` with keys `(pk=schema_id, sk=semver)`
  - GSI1 `ByNameKind` `(pk=namespace#name#kind, sk=version_sort)`
  - GSI2 `ActiveByNamespace` `(pk=namespace, sk=name#kind#active)`
- S3 object lock enabled for immutability. Versioning enabled.

## Data model

### Entity: Schema

- `schema_id` string URN
- `namespace` string `{domain}.{subdomain}`
- `name` string `snake_case`
- `kind` enum `event | file | table | feature | api`
- `format` enum `jsonschema | avro | protobuf | iceberg | openapi`
- `owner` team id
- `classification` enum `public | internal | confidential | restricted`
- `tags` map string to string. Required: `tenant_scope`, `region_scope`
- `state` enum `draft | active | deprecated | retired`
- `created_at`, `updated_at`, `created_by`, `approved_by`
- `lineage_ref` OpenLineage run id

### Entity: Version

- `schema_id`
- `semver` `MAJOR.MINOR.PATCH`
- `compatibility_mode` `backward | forward | full | none`
- `blob_uri` S3 path
- `digest_sha256`
- `kms_key_id`
- `provenance` `{repo_url, commit_sha, change_ticket, build_id}`
- `validation_matrix` `{required_checks[], optional_checks[], test_vectors_uri}`
- `effective_at`, `deprecated_at?`

### Entity: AuditEvent

- `event_id` UUIDv7
- `occurred_at` timestamp
- `actor` `{user_id|client_id}`
- `action` enum `create_schema | publish_version | activate | deprecate | retire | rollback`
- `target_schema_id`, `semver?`
- `details` object

## Naming and identifiers

### Namespaces

`{domain}.{subdomain}` such as `security.auth` or `billing.invoice`.

### Schema URN

`urn:nc:schema:{namespace}:{name}:{kind}` Regex: `^urn:nc:schema:[a-z0-9]+(\.[a-z0-9]+)*:[a-z0-9_]+:(event|file|table|feature|api)$`

### Security Engine schemas

The following contracts are authoritative for the Security Engine integration and live under `schemas/events/`:

| URN | File | Purpose |
| --- | --- | --- |
| `urn:nc:schema:security:finding:event.security.finding.v1` | `schemas/events/event.security.finding.v1.json` | Policy violations emitted by the pipeline. |
| `urn:nc:schema:security:anomaly:event.security.anomaly.v1` | `schemas/events/event.security.anomaly.v1.json` | Heuristic/anomaly signals to the Security Engine. |
| `urn:nc:schema:security:command:cmd.security.quarantine.v1` | `schemas/events/cmd.security.quarantine.v1.json` | Command for quarantining assets. |
| `urn:nc:schema:security:command:cmd.security.ticket.create.v1` | `schemas/events/cmd.security.ticket.create.v1.json` | Command to create SOC tickets. |
| `urn:nc:schema:security:command:cmd.security.notify.v1` | `schemas/events/cmd.security.notify.v1.json` | Command to push notifications. |
| `urn:nc:schema:security:status:event.security.action_status.v1` | `schemas/events/event.security.action_status.v1.json` | Callback describing action status with idempotent semantics. |

### Versioning

Semantic versioning. Patch for safe metadata changes. Minor for additive optional fields with defaults. Major for breaking changes.

## Compatibility policy

- Events default to `backward`. Older consumers can parse newer events.
- Tables default to `full`. Readers and writers remain compatible.
- APIs default to `none`. Clients pin exact versions.

### Allowed by mode

| Change                              | backward | forward | full |
| ----------------------------------- | -------- | ------- | ---- |
| Add optional field with default     | yes      | yes     | yes  |
| Widen numeric type                  | yes      | yes     | yes  |
| Add enum value with default mapping | yes      | yes     | yes  |
| Remove field                        | no       | no      | no   |
| Change primary or partition key     | no       | no      | no   |
| Incompatible type change            | no       | no      | no   |

## Lifecycle and workflow

### States

`draft` → `active` → `deprecated` → `retired`.

### Workflow

1. Propose: PR includes schema file, test vectors, and change ticket.
2. Validate: CI runs format validators, contract tests, data quality checks.
3. Approve: code owners sign.
4. Publish: Registry API writes version, stores blob, signs digest, emits EventBridge event.
5. Promote: mark active with `effective_at`.
6. Deprecate: set `deprecated_at` with grace period and consumer impact note.
7. Retire: block usage and archive.

## API specification

### Conventions

- Base path `/v1`
- JSON payloads. Snake case fields.
- Idempotency-Key header for mutating operations.
- Errors use RFC 7807 Problem JSON.

### Endpoints

- `POST /schemas`
  - Body: `{namespace, name, kind, format, owner, classification, tags}`
  - 201 `{schema_id}`
- `GET /schemas?namespace=&name=&kind=&state=&tag.k=v`
  - 200 list of schemas
- `GET /schemas/{schema_id}`
  - 200 schema metadata
- `POST /schemas/{schema_id}/versions`
  - Headers: `Idempotency-Key`
  - Body: `{semver, compatibility_mode, schema_blob_base64, provenance, validation_matrix}`
  - 201 `{schema_id, semver}`
- `GET /schemas/{schema_id}/versions/{semver}`
  - 200 version payload and metadata
- `POST /schemas/{schema_id}/versions/{semver}:activate`
  - Body: `{effective_at}`
  - 204
- `POST /schemas/{schema_id}/versions/{semver}:deprecate`
  - Body: `{deprecated_at, grace_days, note}`
  - 204
- `POST /schemas/{schema_id}/versions/{semver}:retire`
  - 204
- `POST /schemas/{schema_id}/versions/{semver}:rollback`
  - Body: `{target_semver}`
  - 202

### Error model

```json
{
  "type": "https://neurocipher.io/problems/validation-error",
  "title": "Validation failed",
  "status": 422,
  "detail": "Field 'user_id' is required",
  "instance": "urn:uuid:0f111c6e-8f45-4a9c-9e0b-11f1b5d2d9f7",
  "invalid_params": [{"name": "user_id", "reason": "required"}]
}
```

## Validation and data quality

- Formats supported: JSON Schema 2020-12, Avro 1.11, Protobuf 3, Iceberg 1.4, OpenAPI 3.1.
- Required checks: syntax, type constraints, default validity, enum coverage, primary key presence where applicable, partition key definition for tables, null policy, and semantic guards from DM-001.
- Optional checks: value distributions against provided test vectors.
- Test vectors: producers supply a minimal and maximal payload set. Stored under `attachments/{schema_id}/tests/v{semver}/`.

## Security and IAM

### ABAC tag schema

- `nc:tenant` string
- `nc:region` string
- `nc:classification` enum `public | internal | confidential | restricted`

### IAM policy highlights

- Producers may call `POST /schemas` and `POST /schemas/{id}/versions` only for namespaces they own.
- Consumers may call `GET` endpoints scoped by tags.
- Admins may activate, deprecate, retire, and rollback.

### Encryption

- S3 bucket with SSE-KMS using per-tenant CMKs. Object level KMS key id recorded on version metadata.
- Signer uses a dedicated CMK for CMS signatures. Rotation every 12 months. Previous keys retained for verification.

## Performance and SLOs

- Availability: 99.95 percent monthly for read APIs.
- Latency: p95 `GET /schemas/{id}/versions/{v}` ≤ 20 ms, p99 ≤ 50 ms in prod VPC.
- Throughput: sustain 2k reads per second and 50 writes per second per region.
- Cold start budget: Lambda max 300 ms. Provisioned concurrency for read paths in prod.

## Operations and runbooks

### Publish a new version

1. Open PR with schema and test vectors.
2. CI validates and signs off.
3. Merge triggers publish job to Registry API.
4. Verify EventBridge `SchemaVersionPublished` event.

### Hot fix and rollback

1. Call `:rollback` with `target_semver`.
2. Invalidate caches with `Cache-Flush` admin endpoint.
3. Verify consumers using latest active version.

### Deactivate a version

1. Call `:deprecate` with grace period.
2. Page owners of dependent consumers via ownership map.

### Cache flush

- Admin endpoint `POST /admin/cache:flush` or TTL expiry. Expect propagation within 60 seconds.

### Region failover

- Secondary deployment in paired region. DynamoDB global table for metadata. S3 cross-region replication for blobs. Route traffic via weighted DNS.

## Observability

- Metrics: `registry.read.latency`, `registry.read.throughput`, `registry.write.latency`, `validation.failures`, \`active\_v

## Acceptance Criteria

- All ingested records carry `{schema_urn, version}` and noncompliant payloads are rejected at ingress, with failures exposed via metrics and logs.
- Registry API and storage layout (S3, DynamoDB) are deployed with KMS signing, immutability, and tagging as defined in the storage and security sections.
- Compatibility modes for events, tables, and APIs are enforced according to the compatibility matrix, with CI contract tests covering each mode.
- Provenance metadata (`repo_url`, `commit_sha`, `change_ticket`, `build_id`) is recorded for each schema version and retrievable for audit.
- Read SLOs for `GET /schemas/{schema_id}/versions/{semver}` (availability and latency) are met in staging and production environments.
- At least one end-to-end publish/activate/deprecate/rollback workflow has been exercised in a non-production environment with evidence attached to a change ticket.
