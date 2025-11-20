id: DM-001
title: Canonical Data Model
owner: Data Architecture
status: Ready for review
last_reviewed: 2025-10-28

# **DM-001 Canonical Data Model**

  

**Document Type:** Data Model Specification

**System:** Neurocipher Data Pipeline (see docs/integrations/)

**Version:** 1.0

**Status:** Ready for review

**Owner:** Data Architecture

**Reviewers:** Platform, Security, Compliance

**Effective Date:** 2025-10-28

  

## **1. Purpose**

  

Define the canonical business entities, attributes, semantics, and invariants. Create a stable logical contract that maps to physical schemas, vector classes, events, and retention rules.

  

## **2. Scope**

  

In scope: multi-tenant identity, inventory, scanning, compliance, findings, remediation, integrations, audit.

Out of scope: UI view models, per-cloud raw provider payloads, pricing and billing details.

  

## **3. References**

- DM-002 Logical ER Model
    
- DM-003 Physical Schemas and Storage Map
    
- DM-004 Event Schemas and Contracts
    
- DM-005 Governance, Versioning and Migrations
    
- ADR-007 Data Lifecycle and Retention
    
- SEC-001..004 Security series
- SEC-005 Multitenancy policy
    
  
  

## **4. Conventions**

  

**Identifiers**

- id: ULID text, immutable.
    
- Foreign keys use {entity}_id.
    
- All timestamps UTC ISO 8601 with millisecond precision.
    

  

**Naming**

- Tables and columns: snake_case.
    
- Enums: UPPER_SNAKE.
    
- JSON keys at edges may be lowerCamelCase; canonical uses snake_case.
    

  

**Common fields**

- id, account_id, created_at, updated_at, created_by, updated_by, source, is_deleted (soft delete), version (integer).
    

  

**PII classification**

- P0 secret. Breach requires immediate regulatory action.
    
- P1 sensitive. Breach high risk.
    
- P2 internal. Limited risk.
    
- P3 public.
    

  

**Retention classes** (see ADR-007)

- RC1 long term 7 years minimum
    
- RC2 medium 2 years
    
- RC3 short 90 days
    
- RC4 transient 24 hours
    

  

**SCD policy**

- Type 2 for slowly changing dimensions: asset, policy, control, integration.
    
- Point-in-time fields: valid_from, valid_to, is_current.
    

  

**Integrity**

- All FKs are ON DELETE RESTRICT unless stated.
    
- Tenant isolation by account_id on all tenant-scoped entities.
    

  

## **5. Canonical entity catalog**

|**Entity**|**Summary**|**Retention**|**SCD**|**Emits events**|
|---|---|---|---|---|
|account|Customer tenant|RC1|No|account.created, account.updated|
|user|Human or service user|RC1|No|user.invited, user.role_changed|
|role|Role definition|RC1|No|role.created|
|role_assignment|User to role link|RC1|No|role_assignment.created|
|cloud_account|AWS, GCP, Azure subscription|RC2|Type 2|cloud_account.linked|
|data_source|Connector configuration|RC2|Type 2|data_source.created|
|asset|Cloud resource or endpoint|RC2|Type 2|asset.discovered, asset.changed|
|source_document|Raw ingest blob metadata|RC3|No|source_document.ingested|
|document_chunk|Tokenized content|RC3|No|chunk.indexed|
|embedding_ref|Reference to vector index|RC3|No|embeddingRef.created|
|ingestion_job|Logical ingest batch|RC3|No|ingestion.started, ingestion.completed|
|scan|A scan execution|RC2|No|scan.started, scan.completed|
|control|Control definition|RC1|Type 2|control.created, control.updated|
|policy|Policy bundle|RC1|Type 2|policy.published|
|finding|Control evaluation result|RC1|No|finding.created, finding.status_changed|
|evidence|Artifact supporting finding|RC1|No|evidence.attached|
|remediation|Proposed or executed fix|RC1|No|remediation.created, remediation.completed|
|ticket|External tracker link|RC1|No|ticket.created|
|notification|Outbound message|RC3|No|notification.sent|
|audit_log|Immutable action log|RC1|Append-only|audit_log.recorded|
|job|Async platform job|RC3|No|job.queued, job.completed|
|event|Canonical domain event ledger|RC1|Append-only|event.recorded|

## **6. Entity definitions**

  

### **6.1 account**

  

Purpose: tenant boundary.

|**Field**|**Type**|**Req**|**PII**|**Notes**|
|---|---|---|---|---|
|id|ulid|✔|P2|tenant id|
|name|text|✔|P2|legal or display name|
|status|enum{ACTIVE,SUSPENDED,DELETED}|✔|P2||
|region|text|✔|P2|data residency label|
|created_at, updated_at|timestamp|✔|P2||
|created_by, updated_by|ulid|✔|P2|user ids|

Constraints: name unique within system.

Events: account.created, account.updated.

  

### **6.2 user**

  

Purpose: identity within tenant.

|**Field**|**Type**|**Req**|**PII**|**Notes**|
|---|---|---|---|---|
|id|ulid|✔|P1||
|account_id|ulid|✔|P2|FK account|
|email|text|✔|P1|unique per account, lowercased|
|display_name|text||P2||
|auth_provider|enum{OIDC,SAML,LOCAL}|✔|P2||
|status|enum{INVITED,ACTIVE,DISABLED}|✔|P2||
|mfa_enabled|bool|✔|P2||
|created_at, updated_at|timestamp|✔|P2||

Unique: (account_id, email).

Events: user.invited, user.role_changed.

  

### **6.3 role**

|**Field**|**Type**|**Req**|**PII**|**Notes**|
|---|---|---|---|---|
|id|ulid|✔|P2||
|account_id|ulid|✔|P2||
|name|text|✔|P2|unique per account|
|permissions|json|✔|P2|list of grants|

### **6.4 role_assignment**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|user_id|ulid|✔|
|role_id|ulid|✔|

Unique: (account_id, user_id, role_id).

  

### **6.5 cloud_account**

|**Field**|**Type**|**Req**|**Notes**|
|---|---|---|---|
|id|ulid|✔||
|account_id|ulid|✔||
|provider|enum{AWS,GCP,AZURE}|✔||
|external_ref|text|✔|e.g., AWS account number|
|name|text|||
|linked_at|timestamp|✔||
|valid_from, valid_to, is_current|timestamp, timestamp, bool|✔|SCD2 window|

Unique current: (account_id, provider, external_ref, is_current=true).

  

### **6.6 data_source**

  

Connector settings.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|type|enum{CLOUD_SDK,CSV_UPLOAD,API,LOG}|✔|
|config|json|✔|
|status|enum{ACTIVE,DISABLED}|✔|
|valid_from, valid_to, is_current|as above|✔|

### **6.7 asset**

  

Cloud resource abstraction.

|**Field**|**Type**|**Req**|**Notes**|
|---|---|---|---|
|id|ulid|✔||
|account_id|ulid|✔||
|cloud_account_id|ulid||optional if on-prem|
|urn|text|✔|urn:{provider}:{type}:{region}:{account}:{resource}|
|type|text|✔|normalized resource type|
|region|text|||
|tags|json||key value|
|state|enum{ACTIVE,DELETED}|✔||
|discovered_at|timestamp|✔||
|valid_from, valid_to, is_current|window|✔|SCD2|

Unique current: (account_id, urn, is_current=true).

Events: asset.discovered, asset.changed.

  

### **6.8 source_document**

  

Raw payload metadata.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|data_source_id|ulid|✔|
|content_uri|text|✔|
|content_type|text|✔|
|byte_size|bigint|✔|
|checksum_sha256|text|✔|
|collected_at|timestamp|✔|
|retention_class|enum{RC1,RC2,RC3,RC4}|✔|

### **6.9 document_chunk**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|source_document_id|ulid|✔|
|ord|int|✔|
|text|text|✔|
|token_count|int|✔|

Unique: (source_document_id, ord).

  

### **6.10 embedding_ref**

  

Reference into Weaviate.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|document_chunk_id|ulid|✔|
|weaviate_class|text|✔|
|weaviate_uuid|text|✔|
|vector_dim|int|✔|

Unique: (document_chunk_id).

  

### **6.11 ingestion_job**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|data_source_id|ulid|✔|
|status|enum{QUEUED,RUNNING,FAILED,COMPLETED}|✔|
|started_at, ended_at|timestamp||
|stats|json||

### **6.12 scan**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|scope|json|✔|
|status|enum{QUEUED,RUNNING,FAILED,COMPLETED}|✔|
|started_at, ended_at|timestamp||
|control_set_id|ulid|✔|

### **6.13 control**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|key|text|✔|
|title|text|✔|
|description|text|✔|
|severity|enum{LOW,MEDIUM,HIGH,CRITICAL}|✔|
|category|text|✔|
|rationale|text||
|references|json||
|valid_from, valid_to, is_current|window|✔|

Unique current: (key, is_current=true).

  

### **6.14 policy**

  

Bundle of controls.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|name|text|✔|
|controls|json|✔|
|version_label|text|✔|
|valid_from, valid_to, is_current|window|✔|

### **6.15 finding**

  

Result of evaluating one control against one asset or scope.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|scan_id|ulid|✔|
|control_key|text|✔|
|asset_id|ulid||
|status|enum{OPEN,ACKNOWLEDGED,SUPPRESSED,RESOLVED}|✔|
|severity|enum{LOW,MEDIUM,HIGH,CRITICAL}|✔|
|evidence_score|numeric(5,2)||
|summary|text|✔|
|details|json||
|first_seen_at|timestamp|✔|
|last_seen_at|timestamp|✔|

Indexes: (account_id, status, severity), (asset_id).

Events: finding.created, finding.status_changed.

  

### **6.16 evidence**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|finding_id|ulid|✔|
|content_uri|text|✔|
|content_type|text|✔|
|hash_sha256|text|✔|
|captured_at|timestamp|✔|

### **6.17 remediation**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|finding_id|ulid|✔|
|plan|json|✔|
|executor|enum{MANUAL,AUTOMATION}|✔|
|status|enum{PLANNED,IN_PROGRESS,FAILED,COMPLETED}|✔|
|started_at, completed_at|timestamp||

### **6.18 ticket**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|finding_id|ulid|✔|
|provider|enum{JIRA,GITHUB,LINEAR,OTHER}|✔|
|external_key|text|✔|
|url|text|✔|
|status|text|✔|

Unique: (provider, external_key).

  

### **6.19 integration**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|type|enum{SLACK,EMAIL,WEBHOOK,OTHER}|✔|
|config|json|✔|
|status|enum{ACTIVE,DISABLED}|✔|
|valid_from, valid_to, is_current|window|✔|

### **6.20 notification**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|channel|enum{SLACK,EMAIL,WEBHOOK}|✔|
|template_key|text|✔|
|payload|json|✔|
|sent_at|timestamp||

### **6.21 audit_log**

  

Append-only, immutable.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|actor_user_id|ulid||
|action|text|✔|
|target|json|✔|
|ip|text||
|occurred_at|timestamp|✔|

Constraint: no updates. Only inserts.

  

### **6.22 job**

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|type|text|✔|
|status|enum{QUEUED,RUNNING,FAILED,COMPLETED}|✔|
|payload|json|✔|
|result|json||

### **6.23 event**

  

Canonical domain events ledger.

|**Field**|**Type**|**Req**|
|---|---|---|
|id|ulid|✔|
|account_id|ulid|✔|
|type|text|✔|
|schema_version|int|✔|
|event_version|int|✔|
|occurred_at|timestamp|✔|
|payload|json|✔|
|checksum_sha256|text|✔|

## **7. Relationship summary**

- user.account_id → account.id
    
- role.account_id → account.id
    
- role_assignment.user_id → user.id, role_assignment.role_id → role.id
    
- cloud_account.account_id → account.id
    
- data_source.account_id → account.id
    
- asset.account_id → account.id, asset.cloud_account_id → cloud_account.id
    
- source_document.account_id → account.id, source_document.data_source_id → data_source.id
    
- document_chunk.source_document_id → source_document.id
    
- embedding_ref.document_chunk_id → document_chunk.id
    
- ingestion_job.data_source_id → data_source.id
    
- scan.account_id → account.id
    
- finding.scan_id → scan.id, finding.asset_id → asset.id
    
- evidence.finding_id → finding.id
    
- remediation.finding_id → finding.id
    
- ticket.finding_id → finding.id
    
- integration.account_id → account.id
    
- notification.account_id → account.id
    
- audit_log.account_id → account.id
    
- job.account_id → account.id
    
- event.account_id → account.id
    

  

## **8. Validation rules**

- Emails lowercased.
    
- ULIDs are canonical text.
    
- finding.severity must equal control.severity unless a policy override exists in policy.controls.
    
- asset.urn must be unique current per account_id.
    
- audit_log rows are append-only.
    
- All timestamps must be non-decreasing for an entity history window.
    

  

## **9. Event mapping (to DM-004)**

- Create events on insert.
    
- Update events on meaningful field changes.
    
- Status transitions always emit.
    
- Event payload includes id, account_id, occurred_at, schema_version, event_version, and entity snapshot.
    

  

## **10. Data classification matrix**

|**Entity**|**Fields P0**|**Fields P1**|**Fields P2**|**Fields P3**|
|---|---|---|---|---|
|user|none|email, mfa settings|ids, timestamps|status|
|account|none|none|name, region|status|
|asset|none|none|urn, tags|type, region|
|finding|none|none|summary, details|severity, status|
|audit_log|none|ip maybe P1 if policy mandates|actor ids, action|occurred_at|

PII handling rules:

- P0 never leaves encrypted storage. Not used here.
    
- P1 masked in analytics and exports by default.
    
- P2 allowed in exports with tenant consent.
    
- P3 unrestricted.
    

  

## **11. Retention mapping (to ADR-007)**

- RC1: account, user, role, role_assignment, control, policy, finding, evidence, ticket, audit_log, event.
    
- RC2: asset, cloud_account, data_source, scan.
    
- RC3: source_document, document_chunk, embedding_ref, ingestion_job, job, notification.
    
- RC4: none.
    

  

## **12. Acceptance Criteria**

- All entities include common fields and account_id where tenant-scoped.
    
- SCD2 implemented for asset, control, policy, integration with exact window fields.
    
- Enumerations are closed sets documented above.
    
- Event mapping exists for create, update, and status transitions.
    
- Data classification and retention assigned per entity.
    
- No DynamoDB references. Physical targets are PostgreSQL, S3, Weaviate (via embedding_ref).
    
    

  

## **13. Glossary**

- Account: tenant organization.
    
- Asset: normalized resource under management.
    
- Control: check that evaluates posture.
    
- Finding: result of a control evaluation.
    
- Evidence: proof supporting a finding.
    
- Policy: bundle of controls with configuration.
    
- Scan: execution that evaluates a scope.
    
- SCD2: slowly changing dimensions type 2.
    

---
