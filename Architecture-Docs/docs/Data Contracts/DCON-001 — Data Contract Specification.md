  

DCON-001 — Data Contract Specification

  

  

Status: For Board Review

Owner: Data Architecture

Applies to: Neurocipher Data Pipeline and AuditHound module

Last Updated: 2025-11-06

Region: ca-central-1

  

  

  

  

1. Purpose

  

  

Define the normative data-contract framework that all producers and consumers must follow across events, files, tables, feature vectors, and public APIs. Contracts standardize schemas, versioning, compatibility, validation, provenance, and lifecycle so changes ship safely with auditability and zero ambiguous behavior. 

  

  

2. Scope

  

  

In scope: event payloads, S3 file layouts, Iceberg table specs, Weaviate classes, and OpenAPI surfaces. Includes registry integration, lifecycle states, IAM and encryption rules, observability, and runbooks. Out of scope: UI view models. 

  

  

3. References

  

  

- SRG-001 Schema Registry (authoritative storage, APIs, and lifecycle)  
- DM-004 Event Schemas & Contracts (envelope, validation, compatibility)  
- DM-005 Governance, Versioning & Migrations (process, gates, deprecation windows)  
- CI/CL-001..003 (CI gates, delivery, change control)      
- OBS-001..003 (telemetry, dashboards, SLOs, incident process)      

  

  

  

4. Definitions

  

  

- Schema URN: urn:nc:schema:{namespace}:{name}:{kind} where namespace={domain}.{subdomain}, name=snake_case, kind ∈ {event|file|table|feature|api}. Regex in SRG-001.  
- Version: SemVer MAJOR.MINOR.PATCH for schema documents. Contract compatibility defined by mode.  
- Compatibility Modes: backward|forward|full|none with allowed change matrix.  
- Lifecycle: draft → active → deprecated → retired.  

  

  

  

5. Normative Requirements

  

  

6. Every ingested record must carry a valid {schema_urn, version}; ingress rejects noncompliant payloads.  
7. Compatibility mode must be declared per stream/table and enforced on publish and read.  
8. All schema blobs are immutable, content-addressed by SHA-256, and signed with KMS.  
9. Provenance is recorded for every version: {repo_url, commit_sha, change_ticket, build_id}.  
10. Access decisions use ABAC tags: nc:tenant, nc:region, nc:classification.  

  

  

  

11. Contract Types

  

  

  

6.1 Event Contracts

  

  

- Envelope: Events share a canonical envelope; detail carries domain payload. Required fields include ULID id, account_id, type, schema_version, event_version, timestamps, trace_id, checksum.  
- Registry Layout: s3://nc-<env>-schema/events/{type}/v{schema_version}/schema.json (+ examples).  
- Compatibility: Additive optional fields with defaults are backward compatible; renames/removals are breaking; event_version increments when business meaning changes without schema break.  
- Validation: Publishers validate before emit; consumers validate and reject to DLQ if invalid.  

  

  

  

6.2 File Contracts (S3)

  

  

- Kinds: file schemas describe normalized file layouts and metadata for ingestion buckets.
- Storage Layout: Stored in SRG with URN and SemVer under schemas/{namespace}/{name}/file/vX.Y.Z/schema.json.  
- Required Meta: checksum_sha256, mime, pii_flags, policy, timestamps, as recorded in DDB metadata (contract links to DM-003).  

  

  

  

6.3 Table Contracts (Iceberg)

  

  

- Format: format=iceberg schema documents define columns, partition spec, sort order, primary keys, and null policy. Validated by the registry’s table validator.  
- Compatibility: Tables default to full compatibility; no removal of columns or key changes without major version and cutover plan.  

  

  

  

6.4 Feature Vector Contracts

  

  

- Class Naming: Weaviate classes versioned as NcChunkV{n} for incompatible vector layouts.  
- Compatibility: New class per incompatible change; dual-read window during cutover governed by DM-005.  

  

  

  

6.5 API Contracts

  

  

- Format: format=openapi for public service surfaces. Changes follow compatibility_mode=none unless explicitly relaxed; clients pin exact versions.  

  

  

  

7. Identification and Naming

  

  

- Namespaces: {domain}.{subdomain} e.g., security.auth, billing.invoice.  
- Schema URN: urn:nc:schema:{namespace}:{name}:{kind}; regex and examples in SRG-001.  

  

  

  

8. Versioning and Compatibility

  

  

- SemVer Rules: Patch = safe metadata changes only; Minor = additive fields with defaults; Major = breaking.  
- Modes:  
    

- backward default for events.
- full default for tables.
- none default for APIs.  
    Allowed changes per matrix in SRG-001.  

-   
    
- Deprecation Windows: Minimum two releases for soft-breaking changes with dual emit/read.  

  

  

  

9. Validation, Test Vectors, and CI Gates

  

  

- Supported Formats: JSON Schema 2020-12, Avro 1.11, Protobuf 3, Iceberg 1.4, OpenAPI 3.1. Required checks include syntax, types, defaults, enums, PK/partition presence, and semantic guards from DM-001.  
- Test Vectors: Producers must supply minimal and maximal payload sets; stored under attachments/{schema_id}/tests/v{semver}/.  
- CI/CL Enforcement: Contract tests run on PRs; registry presence and checksums validated; event contracts verified against JSON Schemas; Weaviate class diffs dry-run; failures block merges.  

  

  

  

10. Registry Integration

  

  

- Authoritative Store: S3 versioned bucket with object lock; metadata in DynamoDB indices; CMS signature and SHA-256 digest stored with blobs.  
- Entities: Schema, Version, AuditEvent with provenance and validation matrix.  
- Lifecycle Flow: Propose → Validate → Approve → Publish → Promote → Deprecate → Retire, with EventBridge lifecycle events.  

  

  

  

11. Error Model

  

  

Services return RFC-7807 Problem JSON for validation failures; include invalid_params detailing specific schema violations. 

  

  

12. Security and IAM

  

  

- ABAC: nc:tenant, nc:region, nc:classification tags drive access to read/write endpoints. Producers are restricted to owned namespaces; admins manage activation, deprecation, retirement, and rollback.  
- Encryption: S3 SSE-KMS per tenant; signer uses dedicated CMK rotated every 12 months; previous keys retained for verification.  

  

  

  

13. Performance and SLOs

  

  

- Read API availability ≥ 99.95%. p95 read of GET /schemas/{id}/versions/{v} ≤ 20 ms, p99 ≤ 50 ms. Throughput ≥ 2k reads/s and 50 writes/s per region. Provisioned concurrency on hot read paths.  
- Registry p99 lookup latency for active versions ≤ 50 ms. Faulty version deactivation ≤ 5 minutes via admin API.  

  

  

  

14. Observability

  

  

- Metrics: registry.read.latency_ms p50/p95/p99, read/write TPS, validation.failures.rate, active version counts, cache hit rate, DDB RCUs/WCUs.  
- Dashboards & Alerts: Conform to OBS-001..003 golden signals and burn-rate policies.    

  

  

  

15. Change Governance

  

  

- Process: Proposal with compatibility level, impact, rollout/rollback, backfills, and retention effects; CAB approvals per GOV-002; evidence archived.    
- Gates: Contract tests, registry checksum validation, vector class diff checks, SLO checks (p95, DLQ depth), and migration lint.    

  

  

  

16. Rollback and Recovery

  

  

- Schema Rollback: Admin :rollback to prior semver, flush caches, verify consumers. Region failover uses DynamoDB global tables and S3 CRR.  
- Operational Triggers: SLO breach, error-budget burn, or incompatible change detected. Follow incident workflow in OBS-003/REL-002.    

  

  

  

17. Acceptance Criteria

  

  

- 100% of ingested records include valid {schema_urn, version} and pass validation.  
- All contracts live in SRG with signed digests, provenance, and validation matrix.  
- CI gates enforce contract tests and checksum presence; failures block merges.  
- Dashboard shows registry latency, error rates, cache hit rate, and active versions; alerts wired to on-call.  
- Change requests show approvals and evidence per GOV-002.  

  

  

  

  

  

Appendix A — Examples

  

  

  

A.1 Event Contract 

$id

 and Envelope

  

{

  "$id": "https://schemas.neurocipher.io/events/finding.created/v1/schema.json",

  "$schema": "https://json-schema.org/draft/2020-12/schema",

  "title": "finding.created",

  "type": "object",

  "additionalProperties": false,

  "required": ["id", "account_id", "type", "schema_version", "event_version", "occurred_at", "emitted_at", "trace_id", "detail"],

  "properties": {

    "id": { "type": "string", "pattern": "^[0-9A-HJKMNP-TV-Z]{26}$" },

    "account_id": { "type": "string" },

    "type": { "const": "finding.created" },

    "schema_version": { "const": 1 },

    "event_version": { "const": 1 },

    "occurred_at": { "type": "string", "format": "date-time" },

    "emitted_at": { "type": "string", "format": "date-time" },

    "trace_id": { "type": "string" },

    "checksum_sha256": { "type": "string" },

    "detail": { "$ref": "#/$defs/detail" }

  },

  "$defs": {

    "detail": {

      "type": "object",

      "required": ["id", "asset_urn", "severity", "status"],

      "properties": {

        "id": { "type": "string" },

        "asset_urn": { "type": "string" },

        "severity": { "enum": ["LOW", "MEDIUM", "HIGH", "CRITICAL"] },

        "status": { "enum": ["OPEN", "IN_PROGRESS", "RESOLVED"] }

      },

      "additionalProperties": false

    }

  }

}

Conforms to the envelope and validation rules in DM-004.   

  

  

A.2 Schema URN and Version Metadata

  

{

  "schema_id": "urn:nc:schema:security.finding:finding_created:event",

  "semver": "1.0.0",

  "compatibility_mode": "backward",

  "blob_uri": "s3://nc-registry-prod-ca-central-1/schemas/security.finding/finding_created/event/v1.0.0/schema.json",

  "digest_sha256": "4d8c...fa",

  "provenance": {

    "repo_url": "https://github.com/neurocipher-io/neurocipher-core",

    "commit_sha": "9c1b3d7",

    "change_ticket": "CHG-20251106-042",

    "build_id": "gh-1234567890"

  },

  "validation_matrix": {

    "required_checks": ["syntax", "types", "defaults", "enum", "primary_key"],

    "optional_checks": ["value_distribution"],

    "test_vectors_uri": "s3://nc-registry-prod-ca-central-1/attachments/urn%3Anc%3Aschema%3Asecurity.finding%3Afinding_created%3Aevent/tests/v1.0.0/"

  }

}

Fields align with SRG-001 Version entity. 

  

  

A.3 Problem JSON on Validation Failure

  

{

  "type": "https://neurocipher.io/problems/validation-error",

  "title": "Validation failed",

  "status": 422,

  "detail": "Field 'severity' is required",

  "invalid_params": [{"name": "severity", "reason": "required"}]

}

Matches SRG-001 error model. 

  

  

  

  

Appendix B — API Surface (Registry excerpts)

  

  

- POST /schemas create schema metadata.
- POST /schemas/{schema_id}/versions publish version with Idempotency-Key.
- GET /schemas/{schema_id}/versions/{semver} fetch signed blob metadata.
- Admin operations: :deprecate, :retire, :rollback, POST /admin/cache:flush.    

  

  

  

  

  

Appendix C — Operational Runbooks

  

  

- Publish new version, hotfix/rollback, deprecate with grace period, cache flush, region failover.  

  

  

  

  

  

Appendix D — Observability Panel Checklist

  

  

Include latency histograms, TPS, validation failure rate, cache hit, DDB throttles, KMS sign latency, and event delivery failures. Wire alerts to on-call per OBS-002/003.   

  

  

  

Compliance note: All documentation uses the term “artifact.” “Artefact” is deprecated. 

  

Ready for board review: This DCON-001 spec binds producers and consumers to SRG-001 and DM-004 rules, enforces CI/CL gates, and defines measurable SLOs and rollback procedures with evidence trails.