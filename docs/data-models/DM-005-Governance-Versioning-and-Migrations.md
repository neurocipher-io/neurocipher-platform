id: DM-005
title: Governance, Versioning & Migrations
owner: Data Architecture
status: Ready for review
last_reviewed: 2025-10-28

# **DM-005 Governance, Versioning & Migrations**

  

**Document type:** Data Governance and Change Management Spec

**System:** Neurocipher Data Pipeline (see docs/integrations/)

**Version:** 1.0

**Status:** Ready for review

**Owner:** Data Architecture

**Reviewers:** Platform, Security, Compliance

**Effective date:** 2025-10-28

  

## **1. Purpose**

  

Define how data models, physical schemas, events, and vector indexes evolve safely. Provide a single, auditable process for proposing, approving, implementing, validating, and rolling back changes without tenant impact or downtime.

  

## **2. Scope**

  

In scope: PostgreSQL schemas in nc.*, S3 schemas and layouts, Weaviate classes, Event schemas and routing, RLS policies, data classification and retention coupling, migrations and backfills, change approval and releases across environments.

Out of scope: BI semantic layers and product analytics eventing.

  

## **3. References**

- DM-001 Canonical Data Model
    
- DM-002 Logical Entity Relationship Model
    
- DM-003 Physical Schemas & Storage Map
    
- DM-004 Event Schemas & Contracts
    
- ADR-007 Data Lifecycle & Retention
    
- ADR-010 Disaster Recovery & Backups
   
- SEC-001..004 Security suite
   
- SEC-005 Multitenancy policy

- REL-001 High Availability & Fault Tolerance
    

  

## **4. Definitions**

- **Schema version**: version of a JSON Schema or table contract.
    
- **Event version**: version of business semantics for an event type.
    
- **Compatibility levels**:
    
    - **Compatible**: additive optional fields or new tables.
        
    - **Soft breaking**: requires dual write or dual read during a deprecation window.
        
    - **Breaking**: cannot be deployed without cutover steps and backfills.
        
    

  

## **5. Versioning policy**

  

### **5.1 Semantic versioning**

- **Major**: breaking change.
    
- **Minor**: backward compatible additions.
    
- **Patch**: corrections without contract changes.
    

  

### **5.2 Version domains and identifiers**

|**Domain**|**Version id**|**Stored where**|**Notes**|
|---|---|---|---|
|Canonical entities|DM.MAJOR.MINOR.PATCH|DM-001 header|Bumped when entity contracts change.|
|Physical schema|monotonic migration id|migrations repo|Each migration has id, author, description, checksum.|
|Event schemas|schema_version int|S3 registry path|event_version int for business meaning.|
|Vector classes|NcChunkV{n}|Weaviate class name|New class per incompatible vector layout.|
|S3 file schema|v{n} folders|S3 prefix|Registry JSON checked in repo.|

### **5.3 Deprecation windows**

- Minimum two releases for soft breaking changes.
    
- Dual emit and dual read during window.
    
- Removal only after deprecation checklist passes.
    

  

## **6. Change governance workflow**

  

### **6.1 Proposal**

- Author raises a Change Proposal with:
    
    - Problem statement and goals.
        
    - Compatibility level.
        
    - Impacted stores and services.
        
    - Rollout and rollback plan.
        
    - Data backfill or reindex plan.
        
    - Security and PII review.
        
    - Retention-class effects.
        
    

  

### **6.2 Review and approval**

- Required approvals: Data Architecture (A), Platform (C), Security (C), Compliance for PII or retention (C).
    
- Risk rating: Low, Medium, High.
    
- High risk requires a timed change window and on-call staffing.
    

  

### **6.3 Pre-deploy gates**

- Green build and migrations dry run on staging.
    
- RLS test matrix passes.
    
- Backups verified within last 24 hours for Postgres and last 7 days for S3 and Weaviate export.
    
- Event contract tests pass for all affected types.
    

  

### **6.4 Deployment**

- Production rollout follows the migration playbook in section 8.
    
- Feature flags guard new paths in application.
    
- Phased tenant enablement optional via allowlist.
    

  

### **6.5 Post-deploy validation**

- Health checks, slow query budget, and event DLQ alarms clean.
    
- Row counts, index usage, and constraint validation queries pass.
    
- Sign off recorded in nc.audit_log with action schema.change.approved.
    

  

### **6.6 Rollback strategy**

- Prefer roll forward with corrective migrations.
    
- If immediate rollback needed, use down migration for additive objects only and switch feature flags off.
    
- For destructive steps, restore via PITR as per ADR-010.
    

  

## **7. Data classification and retention coupling**

- P1 fields must not be added without Security approval.
    
- Retention class changes must include purge procedure updates and S3 lifecycle tags.
    
- Any schema change that introduces P1 requires masked views for nc_readonly.
    

  

## **8. Migration playbooks**

  

The patterns below are zero downtime for Postgres 15+ when followed.

  

### **8.1 Add a nullable column**

1. ALTER TABLE ... ADD COLUMN new_col type NULL;
    
2. Backfill in batches if needed.
    
3. Application reads the column with defaults.
    

  

### **8.2 Add NOT NULL column safely**

1. Add column as NULL with default in code only.
    
2. Backfill in batches.
    
3. Add NOT NULL constraint with NOT VALID, then VALIDATE CONSTRAINT.
    

```
ALTER TABLE nc.finding ADD COLUMN reason text;
UPDATE nc.finding SET reason = '' WHERE reason IS NULL;
ALTER TABLE nc.finding
  ADD CONSTRAINT finding_reason_not_null CHECK (reason IS NOT NULL) NOT VALID;
ALTER TABLE nc.finding VALIDATE CONSTRAINT finding_reason_not_null;
```

### **8.3 Rename a column**

1. Add new_col.
    
2. Dual write old_col and new_col.
    
3. Backfill new_col from old_col.
    
4. Switch reads to new_col.
    
5. Drop old_col in a later release.
    

  

### **8.4 Change data type**

1. Add new_col type2.
    
2. Backfill with UPDATE ... SET new_col = CAST(old_col AS type2).
    
3. Switch reads.
    
4. Drop old_col later.
    

  

### **8.5 Add foreign key without blocking**

```
ALTER TABLE nc.finding
  ADD CONSTRAINT fk_find_scan FOREIGN KEY (scan_id) REFERENCES nc.scan(id) NOT VALID;
-- Backfill or clean orphans, then:
ALTER TABLE nc.finding VALIDATE CONSTRAINT fk_find_scan;
```

### **8.6 Add index without blocking writes**

```
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_find_status
  ON nc.finding(account_id, status, last_seen_at DESC);
```

### **8.7 Partition add or rotate**

- Create next month partitions with the procedure in DM-003.
    
- Never drop active partitions. Detach only after archive verification.
    

  

### **8.8 Enum evolution**

- Only add enum values. Map legacy values in application or with a lookup table during transition.
    
- Removing values requires a remap and validation before update.
    

  

### **8.9 RLS policy change**

- Create new policy side by side, test with session setting, then replace.
    
- Always keep enforce_tenant_context trigger active.
    

  

### **8.10 Weaviate class upgrade**

- Create NcChunkV{n+1} with desired properties.
    
- Dual write embedding_ref pointing to new class.
    
- Backfill vectors to V{n+1}.
    
- Switch read queries to class V{n+1}.
    
- After window, delete old class and rows.
    

  

### **8.11 Event schema evolution**

- Add optional fields to schema v1 is compatible.
    
- For breaking changes, publish schema_version = 2, dual emit v1 and v2 during window, then retire v1 route rules.
    

  

### **8.12 S3 file evolution**

- Add fields with defaults.
    
- For breaking layout, write to .../v{n+1}/ and keep v{n} during window.
    

  

## **9. Backfill execution standard**

- Backfills run under nc_admin with RLS disabled but must filter by account_id.
    
- Batching: 10k rows per step with 200 ms sleeps.
    
- Idempotent upserts with primary keys.
    
- Observability: progress and ETA written to nc.job and nc.audit_log.
    

  

**Template**

```
-- Example batched backfill
WITH cte AS (
  SELECT id FROM nc.document_chunk
  WHERE created_at < now() - interval '30 days'
  ORDER BY id LIMIT 10000
)
UPDATE nc.document_chunk dc
SET token_count = length(text) / 4
FROM cte WHERE dc.id = cte.id;
```

## **10. Tooling and CI gates**

- Migrations stored under /migrations/postgres/ with NNNN_description.sql and optional _down.sql.
    
- Linter checks: forbidden statements list (table rewrite, drop column without window, create index without CONCURRENTLY).
    
- CI runs:
    
    - Apply migrations to a disposable Postgres and validate DDL.
        
    - Run RLS matrix tests.
        
    - Run event contract tests against JSON Schemas.
        
    - Validate S3 registry presence and checksums.
        
    - Validate Weaviate class diffs in dry run.
        
    

  

## **11. Change request template (summary)**

- Title and id
    
- Compatibility level
    
- Impacted artifacts (tables, classes, schemas, events)
    
- Risk rating and blast radius
    
- Deployment steps
    
- Validation plan and metrics
    
- Rollback plan
    
- Owner and approvers
    
- Target windows and on-call
    

  

## **12. Observability and SLO checks**

- P95 query latency budgets remain under DM-003 limits.
    
- DLQ depth under 10 messages average.
    
- Partition procedure executed for current and next month.
    
- Storage watermarks under 85 percent.
    

  

## **13. Audit and compliance**

- Every migration writes an audit_log row with:
    
    - id, description, author, environment, git sha, start, end, outcome, rows touched.
        
    
- Quarterly proof:
    
    - PITR restore test report.
        
    - Event replay drill report.
        
    - Weaviate export restore report.
        
    

  

## **14. Risk register and mitigations**

|**Risk**|**Trigger**|**Mitigation**|
|---|---|---|
|Table rewrite during peak|Adding large default incorrectly|Use two phase add and backfill, schedule off peak|
|Long validation on FK|Very large tables|Pre-clean orphans, validate during low traffic|
|Hot index build|Missing CONCURRENTLY|CI linter blocks non-concurrent builds|
|Event consumer breakage|Uncoordinated change|Dual emit and contract tests mandatory|
|Vector class mismatch|App reading mixed classes|Dual read abstraction and cutover checklist|

## **15. Example change end to end**

  

**Goal:** add risk_accepted to finding status.

1. Proposal: Soft breaking, enum add, app UI and consumer changes.
    
2. Migrations:
    

```
ALTER TYPE nc.status_finding ADD VALUE IF NOT EXISTS 'RISK_ACCEPTED';
```

3. Event schema: add value to enum in finding.status_changed schema v1 (compatible).
    
4. App: allow transitions to RISK_ACCEPTED.
    
5. Contracts: update tests.
    
6. Deploy: staging, then prod in window.
    
7. Validate: counts by status, transitions matrix, DLQ clean.
    
8. Sign off and record.
    

  

## **16. Acceptance Criteria**

- A governed process exists and is followed for all changes.
    
- Versioning is consistent across DM, Postgres, events, Weaviate, and S3.
    
- Migration patterns and runbooks are present for all common changes.
    
- CI gates enforce safety rules and contract tests.
    
- Backfills and retention jobs are defined and observable.
    
- Audits produce evidence of changes and quarterly drills.
    
- No references to systems out of scope.
    
- RLS remains enforced and tenant context triggers remain active.
    

  

## **17. RACI**

- Responsible: Data Architecture
    
- Accountable: Head of Platform
    
- Consulted: Security, Compliance
    
- Informed: Product, Support
    

  

## **18. Appendices**

  

### **18.1 Forbidden statements (CI linter)**

- DROP TABLE on tenant tables.
    
- ALTER TABLE ... SET DATA TYPE on large tables without ghost column pattern.
    
- CREATE INDEX without CONCURRENTLY.
    
- ALTER TABLE ... ADD COLUMN ... DEFAULT <non-constant> on large tables.
    
- DROP COLUMN without deprecation window.
    

  

### **18.2 Verification queries**

```
-- RLS still on
SELECT relname, relrowsecurity FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'nc' AND relkind = 'r' AND relrowsecurity = true;

-- Partition for current month exists
SELECT to_regclass(format('nc.event_%s', to_char(date_trunc('month', now()), 'YYYY_MM')));
```
