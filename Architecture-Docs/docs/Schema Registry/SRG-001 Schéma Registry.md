  

SRG-001 Schema Registry

  

  

  

Document control

  

  

- Version: 1.0.0
- Status: For Board Review
- Owner: Data Platform Lead
- Approvers: Architecture Board, Security Lead, SRE Lead, Data Steward
- Applies to: Neurocipher Data Pipeline
- Last updated: 2025-10-30

  

  

  

Purpose

  

  

Define a single authoritative registry for all schemas used across ingestion, processing, and serving. Enforce reject on violation at ingress, safe schema evolution, provenance, audit, and discoverability.

  

  

Scope

  

  

- In scope: event, file, table, feature, and public API schemas. Validation services, storage layout, lifecycle and governance, IAM and encryption, observability, and runbooks.
- Out of scope: UI presentation view models and documentation-only diagrams.

  

  

  

References

  

  

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

  

  

  

Context and assumptions

  

  

- Multi-tenant pipeline. Strong tenant isolation.
- Cloud provider: AWS. Data lake on S3 with Apache Iceberg. Control plane is regional with optional multi-region failover.
- All documentation uses the term artifact. The term artefact is deprecated.

  

  

  

Normative requirements

  

  

1. Every ingested record carries a valid {schema_urn, version}. Noncompliant payloads are rejected at ingress.
2. Compatibility mode is declared per stream or table and enforced at publish and read time.
3. Provenance captures repo_url, commit_sha, change_ticket, build_id for every version.
4. Schema blobs are immutable and content addressed by SHA-256 and signed with KMS.
5. Access control uses ABAC with tags for tenant, region, and classification.
6. p99 lookup latency for active versions ≤ 50 ms in prod.
7. Time to deactivate a faulty version ≤ 5 minutes using admin API.
8. Changes pass GOV-002 readiness gates before promotion.

  

  

  

Architecture overview

  

  

  

Components

  

  

- Registry API: CRUD, search, lifecycle, and validation endpoints.
- Validation service: format-aware validators for JSON Schema 2020-12, Avro 1.11, Protobuf 3, Iceberg table spec, and OpenAPI 3.1.
- Signer: digest signing with KMS CMKs. Deterministic signing pipeline.
- Storage: S3 versioned bucket for schema blobs and attachments.
- Metadata: DynamoDB tables for index, tags, lifecycle state, and audit pointers.
- Cache: API Gateway cache and Lambda extension LRU.
- Eventing: EventBridge bus for lifecycle events.
- Bridges: writers to Glue Data Catalog and OpenLineage.

  

  

  

High level flow

  

  

1. Producer submits a schema PR and test vectors.
2. CI validates and publishes through Registry API.
3. Registry stores the blob in S3, signs the digest, writes metadata in DynamoDB, caches hot keys, and emits a lifecycle event.
4. Consumers resolve the schema URN and version at runtime or deploy-time using the read API or a pinned manifest.

  

  

  

Storage layout

  

  

- S3 bucket: nc-registry-{env}-{region}  
    

- schemas/{namespace}/{name}/{kind}/v{major}.{minor}.{patch}/schema.json
- schemas/.../digest.sha256
- schemas/.../signature.cms
- attachments/{schema_id}/*

-   
    
- DynamoDB tables  
    

- SchemaIndex with keys (pk=schema_id, sk=semver)
- GSI1 ByNameKind (pk=namespace#name#kind, sk=version_sort)
- GSI2 ActiveByNamespace (pk=namespace, sk=name#kind#active)

-   
    
- S3 object lock enabled for immutability. Versioning enabled.

  

  

  

Data model

  

  

  

Entity: Schema

  

  

- schema_id string URN
- namespace string {domain}.{subdomain}
- name string snake_case
- kind enum event | file | table | feature | api
- format enum jsonschema | avro | protobuf | iceberg | openapi
- owner team id
- classification enum public | internal | confidential | restricted
- tags map string to string. Required: tenant_scope, region_scope
- state enum draft | active | deprecated | retired
- created_at, updated_at, created_by, approved_by
- lineage_ref OpenLineage run id

  

  

  

Entity: Version

  

  

- schema_id
- semver MAJOR.MINOR.PATCH
- compatibility_mode backward | forward | full | none
- blob_uri S3 path
- digest_sha256
- kms_key_id
- provenance {repo_url, commit_sha, change_ticket, build_id}
- validation_matrix {required_checks[], optional_checks[], test_vectors_uri}
- effective_at, deprecated_at?

  

  

  

Entity: AuditEvent

  

  

- event_id UUIDv7
- occurred_at timestamp
- actor {user_id|client_id}
- action enum create_schema | publish_version | activate | deprecate | retire | rollback
- target_schema_id, semver?
- details object

  

  

  

Naming and identifiers

  

  

  

Namespaces

  

  

{domain}.{subdomain} such as security.auth or billing.invoice.

  

  

Schema URN

  

  

urn:nc:schema:{namespace}:{name}:{kind} Regex: ^urn:nc:schema:[a-z0-9]+(\.[a-z0-9]+)*:[a-z0-9_]+:(event|file|table|feature|api)$

  

  

Versioning

  

  

Semantic versioning. Patch for safe metadata changes. Minor for additive optional fields with defaults. Major for breaking changes.

  

  

Compatibility policy

  

  

- Events default to backward. Older consumers can parse newer events.
- Tables default to full. Readers and writers remain compatible.
- APIs default to none. Clients pin exact versions.

  

  

  

Allowed by mode

  

|   |   |   |   |
|---|---|---|---|
|Change|backward|forward|full|
|Add optional field with default|yes|yes|yes|
|Widen numeric type|yes|yes|yes|
|Add enum value with default mapping|yes|yes|yes|
|Remove field|no|no|no|
|Change primary or partition key|no|no|no|
|Incompatible type change|no|no|no|

  

Lifecycle and workflow

  

  

  

States

  

  

draft → active → deprecated → retired.

  

  

Workflow

  

  

1. Propose: PR includes schema file, test vectors, and change ticket.
2. Validate: CI runs format validators, contract tests, data quality checks.
3. Approve: code owners sign.
4. Publish: Registry API writes version, stores blob, signs digest, emits EventBridge event.
5. Promote: mark active with effective_at.
6. Deprecate: set deprecated_at with grace period and consumer impact note.
7. Retire: block usage and archive.

  

  

  

API specification

  

  

  

Conventions

  

  

- Base path /v1
- JSON payloads. Snake case fields.
- Idempotency-Key header for mutating operations.
- Errors use RFC 7807 Problem JSON.

  

  

  

Endpoints

  

  

- POST /schemas  
    

- Body: {namespace, name, kind, format, owner, classification, tags}
- 201 {schema_id}

-   
    
- GET /schemas?namespace=&name=&kind=&state=&tag.k=v  
    

- 200 list of schemas

-   
    
- GET /schemas/{schema_id}  
    

- 200 schema metadata

-   
    
- POST /schemas/{schema_id}/versions  
    

- Headers: Idempotency-Key
- Body: {semver, compatibility_mode, schema_blob_base64, provenance, validation_matrix}
- 201 {schema_id, semver}

-   
    
- GET /schemas/{schema_id}/versions/{semver}  
    

- 200 version payload and metadata

-   
    
- POST /schemas/{schema_id}/versions/{semver}:activate  
    

- Body: {effective_at}
- 204

-   
    
- POST /schemas/{schema_id}/versions/{semver}:deprecate  
    

- Body: {deprecated_at, grace_days, note}
- 204

-   
    
- POST /schemas/{schema_id}/versions/{semver}:retire  
    

- 204

-   
    
- POST /schemas/{schema_id}/versions/{semver}:rollback  
    

- Body: {target_semver}
- 202

-   
    

  

  

  

Error model

  
```

{

  "type": "https://neurocipher.io/problems/validation-error",

  "title": "Validation failed",

  "status": 422,

  "detail": "Field 'user_id' is required",

  "instance": "urn:uuid:0f111c6e-8f45-4a9c-9e0b-11f1b5d2d9f7",

  "invalid_params": [{"name": "user_id", "reason": "required"}]

}

```
  

Validation and data quality

  

  

- Formats supported: JSON Schema 2020-12, Avro 1.11, Protobuf 3, Iceberg 1.4, OpenAPI 3.1.
- Required checks: syntax, type constraints, default validity, enum coverage, primary key presence where applicable, partition key definition for tables, null policy, and semantic guards from DM-001.
- Optional checks: value distributions against provided test vectors.
- Test vectors: producers supply a minimal and maximal payload set. Stored under attachments/{schema_id}/tests/v{semver}/.

  

  

  

Security and IAM

  

  

  

ABAC tag schema

  

  

- nc:tenant string
- nc:region string
- nc:classification enum public | internal | confidential | restricted

  

  

  

IAM policy highlights

  

  

- Producers may call POST /schemas and POST /schemas/{id}/versions only for namespaces they own.
- Consumers may call GET endpoints scoped by tags.
- Admins may activate, deprecate, retire, and rollback.

  

  

  

Encryption

  

  

- S3 bucket with SSE-KMS using per-tenant CMKs. Object level KMS key id recorded on version metadata.
- Signer uses a dedicated CMK for CMS signatures. Rotation every 12 months. Previous keys retained for verification.

  

  

  

Performance and SLOs

  

  

- Availability: 99.95 percent monthly for read APIs.
- Latency: p95 GET /schemas/{id}/versions/{v} ≤ 20 ms, p99 ≤ 50 ms in prod VPC.
- Throughput: sustain 2k reads per second and 50 writes per second per region.
- Cold start budget: Lambda max 300 ms. Provisioned concurrency for read paths in prod.

  

  

  

Operations and runbooks

  

  

  

Publish a new version

  

  

1. Open PR with schema and test vectors.
2. CI validates and signs off.
3. Merge triggers publish job to Registry API.
4. Verify EventBridge SchemaVersionPublished event.

  

  

  

Hot fix and rollback

  

  

1. Call :rollback with target_semver.
2. Invalidate caches with Cache-Flush admin endpoint.
3. Verify consumers using latest active version.

  

  

  

Deactivate a version

  

  

1. Call :deprecate with grace period.
2. Page owners of dependent consumers via ownership map.

  

  

  

Cache flush

  

  

- Admin endpoint POST /admin/cache:flush or TTL expiry. Expect propagation within 60 seconds.

  

  

  

Region failover

  

  

- Secondary deployment in paired region. DynamoDB global table for metadata. S3 cross-region replication for blobs. Route traffic via weighted DNS.

  

  

  

Observability

  

  

  

Metrics

  

  

- registry.read.latency_ms p50 p95 p99
- registry.read.tps, registry.write.tps
- validation.failures.rate
- active_versions.count
- cache.hit_rate, cache.evictions
- dynamodb.rcu, dynamodb.wcu, dynamodb.throttles
- s3.errors, s3.req_per_min
- kms.sign.latency_ms, kms.sign.errors
- eventbus.delivery.failures

  

  

  

Logs

  

  

- Structured JSON. Required fields: timestamp, request_id, actor_id, client_ip, user_agent, tenant, region, endpoint, schema_id, semver, status_code, error_code?.
- PII redaction: emails, IPs beyond /24, tokens. Mask with deterministic hash for joinability.
- Retention: 90 days hot, 13 months cold. Encrypted with SSE-KMS.

  

  

  

Traces

  

  

- OpenTelemetry spans for API, validator, signer, S3, DynamoDB, EventBridge.
- Resource attributes: service.name=registry, service.version, deployment.environment.
- Sampling: 10 percent reads, 100 percent writes. Baggage keys: schema_id, semver.

  

  

  

Dashboards and SLOs

  

  

- SLO read availability 99.95 percent monthly.
- SLO latency p95 ≤ 20 ms and p99 ≤ 50 ms for GET /versions/{v}.
- Error budget policy: 28 minutes per 7 days. Page when error budget burn rate > 2x for 15 minutes.

  

  

  

Alerts

  

  

- Page if read availability < 99.9 percent for 10 minutes.
- Page if p99 latency > 100 ms for 15 minutes.
- Ticket if validation failure rate > 2 percent over 30 minutes.
- Ticket on any KMS or DynamoDB throttle spikes beyond auto-retry backoff.

  

  

  

Acceptance criteria

  

  

1. Ingress rejects all nonconforming payloads with RFC 7807 responses.
2. Registry read SLOs met in prod for rolling 30 days.
3. All versions have complete provenance {repo_url, commit_sha, change_ticket, build_id}.
4. Rollback from a bad active version completes in ≤ 5 minutes end to end.
5. OpenLineage events emitted on publish and activate with correct facets.
6. Audit log covers 100 percent of admin actions with actor_id attribution.
7. No plaintext PII in logs or blobs. KMS used for storage and signatures.
8. DR objectives met: RPO and RTO as defined below, validated by quarterly tests.
9. CI enforces compatibility rules per format and blocks violations.
10. Cost per 10k read calls and per 100 publish calls within budget guardrails.

  

  

  

Change control

  

  

- Required artifacts per change:  
    

- ADR link if design impacting
- DCON-001 diff report and migration plan
- Updated test vectors and validation_matrix
- Rollback plan and owner on call
- SLO impact assessment

-   
    
- Gates:  
    

- CI green on validators and contract tests
- Security sign off for classification and tags
- Data Steward approval for namespace and naming
- Architecture Board approval for breaking changes

-   
    

  

  

  

Cost and capacity

  

  

  

Assumptions

  

  

- Target read QPS: prod {{READ_QPS_PROD}}, staging {{READ_QPS_STG}}.
- Write QPS: prod {{WRITE_QPS_PROD}}.
- Average schema blob size: {{AVG_BLOB_KB}} KB.

  

  

  

Sizing

  

  

- DynamoDB SchemaIndex RCUs = ((READ_QPS * item_kb/4KB) / 0.8) provisioned. WCUs on demand.
- API Gateway + Lambda: provisioned concurrency for read path {{PROV_CONCURRENCY}}.
- S3: projected storage = versions_per_year * avg_blob_size * schemas.

  

  

  

Guardrails

  

  

- Budget per month: {{BUDGET_REGISTRY_USD}} USD.
- Alert on cost anomaly > 30 percent month over month.

  

  

  

Risks and mitigations

  

  

- Registry outage blocks publishes. Mitigate with circuit breaker and local schema bundles for critical consumers.
- Bad schema promoted. Mitigate with strict CI, manual approval, canary activation, and fast rollback.
- Hot key contention on popular schemas. Mitigate with caching and jittered cache invalidation.
- KMS failure. Mitigate with multi region key replicas and verify on next attempt.
- DynamoDB throttling. Mitigate with adaptive capacity and exponential backoff.

  

  

  

Lifecycle events catalog

  

  

- detail-type: SchemaCreated  
    

- Detail: {schema_id, namespace, name, kind, owner}

-   
    
- detail-type: SchemaVersionPublished  
    

- Detail: {schema_id, semver, compatibility_mode, digest_sha256, provenance}

-   
    
- detail-type: SchemaVersionActivated  
    

- Detail: {schema_id, semver, effective_at}

-   
    
- detail-type: SchemaVersionDeprecated  
    

- Detail: {schema_id, semver, deprecated_at, grace_days}

-   
    
- detail-type: SchemaVersionRetired  
    

- Detail: {schema_id, semver}

-   
    
- detail-type: SchemaRollbackCompleted  
    

- Detail: {schema_id, from_semver, to_semver}

-   
    

  

  

  

Example

```
  

{

  "detail-type": "SchemaVersionPublished",

  "source": "neurocipher.registry",

  "detail": {

    "schema_id": "urn:nc:schema:security.auth:user_login:event",

    "semver": "1.2.0",

    "compatibility_mode": "backward",

    "digest_sha256": "{{DIGEST}}",

    "provenance": {

      "repo_url": "{{REPO_URL}}",

      "commit_sha": "{{COMMIT_SHA}}",

      "change_ticket": "{{TICKET}}",

      "build_id": "{{BUILD_ID}}"

    }

  }

}
```

  

Lineage emission spec

  

  

- Producer: registry service emits OpenLineage on publish and activate.
- Job naming: registry.publish_version and registry.activate_version.
- Output dataset: s3://nc-registry-{env}-{region}/schemas/{namespace}/{name}/{kind}/v{semver}/schema.json.
- Facets:  
    

- schema facet summarizing top level fields for JSON Schema and Avro
- dataQualityMetrics facet with validator pass counts
- documentation facet linking to SRG-001 and DCON-001
- sourceCodeLocation facet with {repo_url, commit_sha}

-   
    
- Parent run: CI pipeline run id if available.

  

  

  

API operational details

  

  

- Pagination: limit 1..100 default 50, next_token opaque. Sort version_sort desc by default.
- Filters: namespace, name, kind, state, tag.k=v, semver>=, semver<.
- Rate limits: 200 requests per minute per client, burst 400. 429 on excess with Retry-After.
- Auth: IAM SigV4 for internal callers. CI uses OIDC to assume role.
- Idempotency: Idempotency-Key required on publish. Stored 24 hours. Replay returns 201 with same identifiers.
- Error codes table:  
    

- 400 bad request
- 401 unauthorized
- 403 forbidden
- 404 not found
- 409 conflict on duplicate semver
- 412 precondition failed on compatibility breach
- 422 validation error
- 429 rate limited
- 500 internal error

-   
    

  

  

  

Disaster recovery and failover

  

  

- RPO: 5 minutes metadata via DynamoDB global tables.
- RTO: 30 minutes regional failover.
- S3 cross region replication for blobs. Target lag < 15 minutes 95th percentile.
- Game day cadence: quarterly. Record results and corrective actions.
- Runbook reference: see below.

  

  

  

Runbooks

  

  

  

Violation surge

  

  

1. Identify top failing schemas via validation.failures.
2. Enable quarantine for offenders via gateway rule.
3. Notify owners. Attach failure samples.

  

  

  

Rollback a bad version

  

  

1. Call POST /schemas/{id}/versions/{v}:rollback with target_semver.
2. Flush caches.
3. Confirm SchemaRollbackCompleted event.

  

  

  

Cache flush

  

  

- Call POST /admin/cache:flush. Confirm drop in cache.hit_rate then recovery.

  

  

  

DynamoDB throttling

  

  

1. Check dynamodb.throttles and rcu usage.
2. Increase RCUs by {{RCU_STEP}} or switch to on demand for surge window.

  

  

  

KMS signing failure

  

  

1. Retry with exponential backoff.
2. Fail over to replica CMK.
3. Page Security Lead if failures persist beyond 5 minutes.

  

  

  

Naming rules

  

  

- Namespace regex: ^[a-z0-9]+(\.[a-z0-9]+)*$ length 3..63.
- Name regex: ^[a-z][a-z0-9_]{2,63}$.
- Reserved names: default, internal, system.
- Case: lower snake case for names. Lower dot case for namespaces.

  

  

  

Storage retention

  

  

- Deprecated versions retained minimum 18 months.
- Retired versions retained minimum 36 months for audit.
- S3 Object Lock governance retention {{LOCK_DAYS}} days. Legal hold by request.

  

  

  

Appendices

  

  

  

A. IAM policy examples

  

  

- PLACEHOLDER Producer role policy JSON.
- PLACEHOLDER Consumer role policy JSON.
- PLACEHOLDER Admin role policy JSON.

  

  

  

B. Capacity worksheet

  

  

- PLACEHOLDER link to CAP-001 once finalized.

  

  

  

C. Validation matrix templates

  

  

- PLACEHOLDER link to DQ-001 once finalized.