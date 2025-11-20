id: DM-002
title: Logical Entity-Relationship Model
owner: Data Architecture
status: Ready for review
last_reviewed: 2025-10-28

DM-002 Logical Entity-Relationship Model

  

**Document Type:** Data Model Specification

**System:** Neurocipher Data Pipeline (see docs/integrations/)

**Version:** 1.0

**Status:** Ready for review

**Owner:** Data Architecture

**Reviewers:** Platform, Security, Compliance

**Effective Date:** 2025-10-28

  

## **1. Purpose**

  

Define the logical entities and relationships. Specify cardinalities, optionality, integrity, tenancy, and scale. Anchor mappings to physical schemas and events.

  

## **2. Scope**

  

Covers tenant identity, integrations, ingest, indexing, scanning, policy, controls, findings, evidence, remediation, notifications, jobs, and the canonical event ledger.

  

## **3. References**

  

DM-001 Canonical Data Model

DM-003 Physical Schemas & Storage Map

DM-004 Event Schemas & Contracts

DM-005 Governance, Versioning & Migrations

ADR-007 Data Lifecycle & Retention

SEC-001..004

SEC-005 Multitenancy policy

  

## **4. Conventions**

  

Identifiers: ULID text.

Timestamps: UTC ISO 8601 ms.

Tenant boundary: account with account_id on tenant-scoped rows.

Windows: SCD2 use valid_from, valid_to, is_current.

Cardinality notation: 1, 0..1, 0..*, 1..*.

Deletes: logical soft delete unless stated.

All FKs are ON DELETE RESTRICT unless stated.

  

## **5. ER diagram**

```
erDiagram
ACCOUNT ||--o{ USER : has
ACCOUNT ||--o{ ROLE : defines
USER ||--o{ ROLE_ASSIGNMENT :assigned
ROLE ||--o{ ROLE_ASSIGNMENT :assigned
ACCOUNT ||--o{ CLOUD_ACCOUNT :owns
ACCOUNT ||--o{ DATA_SOURCE :configures
ACCOUNT ||--o{ ASSET :contains
CLOUD_ACCOUNT ||--o{ ASSET :groups
DATA_SOURCE ||--o{ SOURCE_DOCUMENT :emits
SOURCE_DOCUMENT ||--o{ DOCUMENT_CHUNK :splits
DOCUMENT_CHUNK ||--|| EMBEDDING_REF :indexes
ACCOUNT ||--o{ INGESTION_JOB :runs
ACCOUNT ||--o{ SCAN :executes
SCAN ||--o{ FINDING :produces
ASSET ||--o{ FINDING :scopes
FINDING ||--o{ EVIDENCE :has
FINDING ||--o{ REMEDIATION :drives
FINDING ||--o{ TICKET :links
ACCOUNT ||--o{ INTEGRATION :has
ACCOUNT ||--o{ NOTIFICATION :sends
ACCOUNT ||--o{ AUDIT_LOG :records
ACCOUNT ||--o{ JOB :schedules
ACCOUNT ||--o{ EVENT :records
POLICY ||--o{ POLICY_CONTROL :includes
CONTROL ||--o{ POLICY_CONTROL :member
SCAN }o--|| POLICY :uses
```

## **6. Entity roles and keys**

- **account**: tenant root. PK id.
    
- **user**: identity. PK id. FK account_id.
    
- **role**: role. PK id. FK account_id.
    
- **role_assignment**: join. PK id. FK account_id, user_id, role_id. Unique (account_id, user_id, role_id).
    
- **cloud_account**: external cloud tenancy. SCD2. PK id. FKs account_id.
    
- **data_source**: connector config. SCD2. PK id. FK account_id.
    
- **asset**: normalized resource. SCD2. PK id. FKs account_id, optional cloud_account_id.
    
- **source_document**: raw ingest blob meta. PK id. FKs account_id, data_source_id.
    
- **document_chunk**: tokenized text. PK id. FK source_document_id, account_id. Unique (source_document_id, ord).
    
- **embedding_ref**: vector index pointer. PK id. FKs document_chunk_id, account_id. Unique (document_chunk_id).
    
- **ingestion_job**: ingest batch. PK id. FK account_id, data_source_id.
    
- **scan**: evaluation run. PK id. FK account_id, control_set_id→policy.id.
    
- **control**: control catalog. SCD2. PK id. Unique current (key, is_current=true).
    
- **policy**: control bundle. SCD2. PK id. FK account_id.
    
- **policy_control**: logical join of policy to control. PK id. FKs policy_id, control_id. Unique (policy_id, control_id). May be implemented physically as JSON in policy.controls; relationship remains logical.
    
- **finding**: control result. PK id. FKs account_id, scan_id, optional asset_id.
    
- **evidence**: artifact link. PK id. FKs account_id, finding_id.
    
- **remediation**: plan or action. PK id. FKs account_id, finding_id.
    
- **ticket**: external issue. PK id. FKs account_id, finding_id. Unique (provider, external_key).
    
- **integration**: outbound channel. SCD2. PK id. FK account_id.
    
- **notification**: sent message. PK id. FK account_id.
    
- **audit_log**: immutable action log. PK id. FK account_id.
    
- **job**: async job. PK id. FK account_id.
    
- **event**: domain event ledger. PK id. FK account_id.
    

  

## **7. Relationship table**

|**From**|**To**|**Cardinality**|**Optional**|**Integrity rule**|
|---|---|---|---|---|
|user.account_id|account.id|many-to-one|no|user cannot exist without account|
|role.account_id|account.id|many-to-one|no|role scoped to tenant|
|role_assignment.user_id|user.id|many-to-one|no|user must exist|
|role_assignment.role_id|role.id|many-to-one|no|role must exist|
|cloud_account.account_id|account.id|many-to-one|no|tenant owns external account|
|data_source.account_id|account.id|many-to-one|no|connector scoped to tenant|
|asset.account_id|account.id|many-to-one|no|tenant owns asset|
|asset.cloud_account_id|cloud_account.id|many-to-one|yes|nullable for on-prem|
|source_document.data_source_id|data_source.id|many-to-one|no|produced by connector|
|source_document.account_id|account.id|many-to-one|no|tenant scoped|
|document_chunk.source_document_id|source_document.id|many-to-one|no|derived from one doc|
|embedding_ref.document_chunk_id|document_chunk.id|one-to-one|no|exactly one ref per chunk|
|ingestion_job.data_source_id|data_source.id|many-to-one|no|job targets connector|
|scan.account_id|account.id|many-to-one|no|tenant scoped|
|scan.control_set_id|policy.id|many-to-one|yes|nullable for ad-hoc sets|
|finding.scan_id|scan.id|many-to-one|no|produced by one scan|
|finding.asset_id|asset.id|many-to-one|yes|null for account-level|
|evidence.finding_id|finding.id|many-to-one|no|evidence must bind|
|remediation.finding_id|finding.id|many-to-one|no|remediation bound|
|ticket.finding_id|finding.id|many-to-one|no|ticket bound|
|integration.account_id|account.id|many-to-one|no|tenant scoped|
|notification.account_id|account.id|many-to-one|no|tenant scoped|
|audit_log.account_id|account.id|many-to-one|no|tenant scoped|
|job.account_id|account.id|many-to-one|no|tenant scoped|
|event.account_id|account.id|many-to-one|no|tenant scoped|
|policy_control.policy_id|policy.id|many-to-one|no|join row valid|
|policy_control.control_id|control.id|many-to-one|no|join row valid|

## **8. Optionality and nullability rules**

- Nullable only when stated in the table above.
    
- asset.cloud_account_id nullable for non-cloud assets.
    
- finding.asset_id nullable for account-level findings.
    
- scan.control_set_id nullable for custom runs.
    
- All other FKs not null.
    

  

## **9. Tenancy and isolation**

- Every tenant-scoped table includes account_id.
    
- Cross-tenant joins are disallowed.
    
- Logical isolation: row level security will enforce account_id = current_setting('app.account_id').
    
- System tables without tenant scope: none.
    

  

## **10. Integrity constraints**

- Uniqueness:
    
    - user: (account_id, email) unique.
        
    - role: (account_id, name) unique.
        
    - asset: (account_id, urn, is_current=true) unique.
        
    - control: (key, is_current=true) unique.
        
    - document_chunk: (source_document_id, ord) unique.
        
    - embedding_ref: (document_chunk_id) unique.
        
    - ticket: (provider, external_key) unique.
        
    
- Status transitions:
    
    - finding.status allowed transitions: OPEN→ACKNOWLEDGED|SUPPRESSED|RESOLVED; ACKNOWLEDGED→RESOLVED|SUPPRESSED; SUPPRESSED→OPEN; RESOLVED→OPEN.
        
    
- Append-only:
    
    - audit_log only inserts. No updates or deletes.
        
    
- SCD2 windows:
    
    - For entities flagged SCD2, new current rows must set prior is_current=false and valid_to = new.valid_from.
        
    

  

## **11. Derived relations and denormalization**

- policy.controls may be stored as JSON. Logical policy_control defines the M:N for analytics and lineage.
    
- Materialized views:
    
    - mv_current_assets(account_id, urn, type, region, tags, discovered_at) sourcing current asset rows.
        
    - mv_open_findings(account_id, control_key, severity, asset_id, first_seen_at, last_seen_at).
        
    

  

## **12. Scale assumptions**

- Per tenant typical:
    
    - users 5–50
        
    - cloud_accounts 1–10
        
    - assets 50k–5M
        
    - source_documents 10k–500k per month
        
    - document_chunks 100k–5M per month
        
    - findings active 1k–200k
        
    - audit_log 100k–5M per month
        
    
- Hot paths:
    
    - lookups by account_id + status or time window
        
    - asset current by URN
        
    - open findings by severity and asset
        
    

  

## **13. Indexing guidance (logical)**

  

Primary compound patterns:

- (account_id, is_current, urn) on asset current view.
    
- (account_id, status, severity, last_seen_at desc) on finding.
    
- (account_id, source_document_id, ord) on document_chunk.
    
- (account_id, occurred_at desc) on audit_log and event.
    
- (account_id, provider, external_ref, is_current) on cloud_account.
    
- (document_chunk_id) unique on embedding_ref.
    

  

## **14. Event lineage mapping**

- Each mutating action emits a domain event of the matching type.
    
- event.payload.id references the mutated entity PK.
    
- event.schema_version tracks DM-004 JSON Schema version.
    
- Events are append-only and reference account_id.
    

  

## **15. Weaviate linkage**

- embedding_ref stores weaviate_class and weaviate_uuid.
    
- Class naming convention: nc_chunk_v{n} where n is embedding schema version.
    
- Cross-refs in Weaviate are not the source of truth. The RDBMS relations define truth.
    

  

## **16. RLS model (logical)**

- Policy: USING (account_id = current_setting('app.account_id')::text) for tenant tables.
    
- Admin bypass allowed only on a secured role for backfills.
    
- audit_log and event follow the same predicate.
    

  

## **17. Validation queries**

```
-- exactly one current asset row per URN
SELECT urn
FROM asset
WHERE is_current
GROUP BY account_id, urn
HAVING COUNT(*) = 1;

-- window closure for SCD2 entities
SELECT id
FROM control c
WHERE is_current = false AND valid_to IS NULL;

-- no orphan findings
SELECT f.id
FROM finding f
LEFT JOIN scan s ON s.id = f.scan_id
WHERE s.id IS NULL;

-- embedding one-to-one
SELECT document_chunk_id
FROM embedding_ref
GROUP BY document_chunk_id
HAVING COUNT(*) = 1;
```

## **18. Change impact rules**

- Adding optional FK: compatible.
    
- Tightening optional to required: breaking. Requires backfill and DM-005 gate.
    
- Splitting JSON field to join table: compatible if old JSON remains during deprecation window.
    
- New entity with outbound refs: compatible.
    
- Renaming entity or PK type: breaking. Requires migration plan and event version bump.
    

  

## **19. Acceptance Criteria**

- All tenant-scoped entities carry account_id.
    
- All relationships and optionalities match the table in section 7.
    
- SCD2 entities include window fields and uniqueness across current rows.
    
- RLS predicate definable from this model.
    
- Logical model maps one-to-one with DM-003 physical tables or documented exceptions.
    
- No DynamoDB references. Physical targets are PostgreSQL, S3, Weaviate.
    
- No references to external projects not in scope.
    

  

## **20. Traceability**

- Each entity maps to one physical table in DM-003 with the same name.
    
- policy_control maps to either a physical join table or policy.controls JSON with lineage notes in DM-003.
    
- Events for each entity map to DM-004 schemas with the same base name.
