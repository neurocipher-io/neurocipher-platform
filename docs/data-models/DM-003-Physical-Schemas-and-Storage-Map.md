
id: DM-003
title: Physical Schemas & Storage Map
owner: Data Architecture
status: Ready for review
last_reviewed: 2025-10-28

# **DM-003 Physical Schemas & Storage Map**

  

**Document Type:** Physical Data Specification

**System:** Neurocipher Data Pipeline (see docs/integrations/)

**Version:** 1.2

**Status:** Ready for review

**Owner:** Data Architecture

**Reviewers:** Platform, Security, Compliance

**Effective Date:** 2025-10-28

  

## **1. Purpose**

  

Define the authoritative physical design for PostgreSQL, S3, and Weaviate. Cover DDL, indexing, partitioning, lifecycle, security, backup and restore, data quality, migration procedures, performance SLOs, and retention enforcement.

  

## **2. Scope and assumptions**

In scope: all DM-001 entities. Storage targets: PostgreSQL 15+, S3 with SSE-KMS, Weaviate 1.24+ multi-tenant.

Out of scope: BI semantic models, UI view models.

Assumptions: ULIDs as text, UTC timestamps, RLS for tenancy, PgBouncer in front of Postgres.

Tenant context validation and quota guardrails align with docs/security-controls/SEC-005-Multitenancy-Policy.md.

## **2.1 Metadata store**

- Per ADR-001 and DM-001, the canonical metadata catalog (asset, source_document, ingestion_job, scan, finding, evidence, etc.) lives in PostgreSQL (`nc.*` schema) with RLS enforcing tenant identity.
- This Postgres metadata store is the single view for control-plane signals, lineage, and operational reporting; DynamoDB hosts auxiliary workloads (idempotency guard, temporary caches) but is not the canonical metadata engine.

## **2.2 Vector store contract**

- **Weaviate class naming**: The canonical vector class is `NcChunkV1`. Each incompatible schema bump increments the suffix (`NcChunkV2`, etc.), and all references (DM-005 §8.10, PROC-003 §68, DCON-001 §202) must cite the newest `NcChunkV{n}` value. The class stores embedding vectors and metadata mirrored from `nc.document_chunk` rows (see §6.8).
- **Index naming**: Production, staging, and dev deployments publish a consistent alias (`nc_chunk_v1_index`) per environment (for example `weaviate-prod-nc-chunk-v1-index`). Authors and instrumentation refer to this alias when describing query routing, shards, and metrics so dashboards stay in sync.
- **Metadata linkage**: `nc.embedding_ref` rows reference the active Weaviate class via `weaviate_class` (for example `NcChunkV1`, `NcChunkV2`). The class version is encoded in the `weaviate_class` name; there is no separate `class_version` column in the table schema.
- **Observability & metrics**: Dashboards, SLOs, and alerts track `weaviate_query_duration_seconds`, `weaviate_upsert_latency_seconds`, and `weaviate_replica_health` (see `OBS-002` and `REL-002`). Vector store quotas depend on this class and the API Gateway `X-RateLimit-*` headers.

## **2.3 Implementation status**

- Core ingestion metadata tables are implemented in draft form by `migrations/postgres/0001_nc_core_metadata.sql` on the feature branch used for DM-003 v1.2 (`feat/db-physical-schemas-v1`).
- Tables covered: `nc.account`, `nc.data_source`, `nc.source_document`, `nc.document_chunk`, and `nc.ingestion_job` with RLS and tenant-context triggers as defined in §5–§7.
- Remaining tables, vector schemas, and search index artifacts follow in subsequent migrations and schema JSON files referenced later in this document.

## **3. Non-functional requirements**

- Availability DB: 99.9 percent per month
    
- RPO: 15 minutes. RTO: 60 minutes
    
- P95 read latency hot queries: 50 ms in VPC
    
- P95 single row insert: 40 ms
    
- Max tenant asset current rows: 5 million
    
- Max monthly events per tenant: 50 million
    

  

## **4. Conventions**

- Schema: nc
    
- ULIDs: text
    
- Time: timestamptz
    
- Soft delete flag where applicable: is_deleted boolean default false
    
- SCD2 window fields: valid_from, valid_to, is_current
    
- Tenant key on tenant tables: account_id text not null
    
- All DDL idempotent and fenced
    

  

## **5. PostgreSQL foundation**

```
CREATE SCHEMA IF NOT EXISTS nc;

DO $$
BEGIN
  CREATE TYPE nc.status_account   AS ENUM ('ACTIVE','SUSPENDED','DELETED');
  CREATE TYPE nc.status_user      AS ENUM ('INVITED','ACTIVE','DISABLED');
  CREATE TYPE nc.auth_provider    AS ENUM ('OIDC','SAML','LOCAL');
  CREATE TYPE nc.status_toggle    AS ENUM ('ACTIVE','DISABLED');
  CREATE TYPE nc.status_job       AS ENUM ('QUEUED','RUNNING','FAILED','COMPLETED');
  CREATE TYPE nc.status_scan      AS ENUM ('QUEUED','RUNNING','FAILED','COMPLETED');
  CREATE TYPE nc.severity         AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL');
  CREATE TYPE nc.status_finding   AS ENUM ('OPEN','ACKNOWLEDGED','SUPPRESSED','RESOLVED');
  CREATE TYPE nc.provider         AS ENUM ('AWS','GCP','AZURE');
  CREATE TYPE nc.ticket_provider  AS ENUM ('JIRA','GITHUB','LINEAR','OTHER');
  CREATE TYPE nc.integration_type AS ENUM ('SLACK','EMAIL','WEBHOOK','OTHER');
  CREATE TYPE nc.retention_class  AS ENUM ('RC1','RC2','RC3','RC4');
  CREATE TYPE nc.source_type      AS ENUM ('CLOUD_SDK','CSV_UPLOAD','API','LOG');
  CREATE TYPE nc.exec_type        AS ENUM ('MANUAL','AUTOMATION');
EXCEPTION WHEN duplicate_object THEN NULL;
END$$;

CREATE OR REPLACE FUNCTION nc.current_account_id()
RETURNS text LANGUAGE sql STABLE
AS $$ SELECT current_setting('app.account_id', true) $$;

-- Guard function to enforce tenant context
CREATE OR REPLACE FUNCTION nc.require_tenant_context()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('app.account_id', true) IS NULL THEN
    RAISE EXCEPTION 'app.account_id not set';
  END IF;
END$$;
```

## **6. Physical tables, indexes, RLS**

  

RLS is enabled on every tenant table with predicate account_id = nc.current_account_id().

  

> Tables 6.1 through 6.23 are unchanged in definition from v1.1 except where noted. Full DDL is reproduced for completeness.

  

### **6.1 account**

```
CREATE TABLE IF NOT EXISTS nc.account (
  id         text PRIMARY KEY,
  name       text NOT NULL,
  status     nc.status_account NOT NULL DEFAULT 'ACTIVE',
  region     text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by text NOT NULL,
  updated_by text NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_account_name ON nc.account(name);
```

### **6.2 user**

```
CREATE TABLE IF NOT EXISTS nc."user" (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  email        text NOT NULL,
  display_name text,
  auth_provider nc.auth_provider NOT NULL,
  status       nc.status_user NOT NULL DEFAULT 'INVITED',
  mfa_enabled  boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  is_deleted   boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_user_email ON nc."user"(account_id, lower(email));
ALTER TABLE nc."user" ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_user_tenant ON nc."user" USING (account_id = nc.current_account_id());
```

### **6.3 role**

```
CREATE TABLE IF NOT EXISTS nc.role (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  name         text NOT NULL,
  permissions  jsonb NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_role_name ON nc.role(account_id, name);
ALTER TABLE nc.role ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_role_tenant ON nc.role USING (account_id = nc.current_account_id());
```

### **6.4 role_assignment**

```
CREATE TABLE IF NOT EXISTS nc.role_assignment (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  user_id      text NOT NULL REFERENCES nc."user"(id),
  role_id      text NOT NULL REFERENCES nc.role(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_role_assignment ON nc.role_assignment(account_id, user_id, role_id);
ALTER TABLE nc.role_assignment ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_role_assignment_tenant ON nc.role_assignment USING (account_id = nc.current_account_id());
```

### **6.5 cloud_account (SCD2)**

```
CREATE TABLE IF NOT EXISTS nc.cloud_account (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  provider     nc.provider NOT NULL,
  external_ref text NOT NULL,
  name         text,
  linked_at    timestamptz NOT NULL,
  valid_from   timestamptz NOT NULL,
  valid_to     timestamptz,
  is_current   boolean NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_cloud_acct_current
  ON nc.cloud_account(account_id, provider, external_ref) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS ix_cloud_acct_hist
  ON nc.cloud_account(account_id, provider, external_ref, valid_from);
ALTER TABLE nc.cloud_account ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_cloud_account_tenant ON nc.cloud_account USING (account_id = nc.current_account_id());
```

### **6.6 data_source (SCD2)**

```
CREATE TABLE IF NOT EXISTS nc.data_source (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  type         nc.source_type NOT NULL,
  config       jsonb NOT NULL,
  status       nc.status_toggle NOT NULL DEFAULT 'ACTIVE',
  valid_from   timestamptz NOT NULL,
  valid_to     timestamptz,
  is_current   boolean NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_data_source_current
  ON nc.data_source(account_id, type) WHERE is_current = true;
ALTER TABLE nc.data_source ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_data_source_tenant ON nc.data_source USING (account_id = nc.current_account_id());
```

### **6.7 asset (SCD2)**

```
CREATE TABLE IF NOT EXISTS nc.asset (
  id               text PRIMARY KEY,
  account_id       text NOT NULL REFERENCES nc.account(id),
  cloud_account_id text REFERENCES nc.cloud_account(id),
  urn              text NOT NULL,
  type             text NOT NULL,
  region           text,
  tags             jsonb,
  state            text NOT NULL CHECK (state IN ('ACTIVE','DELETED')),
  discovered_at    timestamptz NOT NULL,
  valid_from       timestamptz NOT NULL,
  valid_to         timestamptz,
  is_current       boolean NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_asset_current ON nc.asset(account_id, urn) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS ix_asset_lookup ON nc.asset(account_id, type, is_current, region);
ALTER TABLE nc.asset ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_asset_tenant ON nc.asset USING (account_id = nc.current_account_id());
```

### **6.8 source_document**

```
CREATE TABLE IF NOT EXISTS nc.source_document (
  id               text PRIMARY KEY,
  account_id       text NOT NULL REFERENCES nc.account(id),
  data_source_id   text NOT NULL REFERENCES nc.data_source(id),
  content_uri      text NOT NULL,
  content_type     text NOT NULL,
  byte_size        bigint NOT NULL,
  checksum_sha256  text NOT NULL,
  collected_at     timestamptz NOT NULL,
  retention_class  nc.retention_class NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_source_doc_ds ON nc.source_document(account_id, data_source_id, collected_at);
ALTER TABLE nc.source_document ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_source_document_tenant ON nc.source_document USING (account_id = nc.current_account_id());
```

### **6.9 document_chunk  (partition on demand)**

```
CREATE TABLE IF NOT EXISTS nc.document_chunk (
  id                 text PRIMARY KEY,
  account_id         text NOT NULL REFERENCES nc.account(id),
  source_document_id text NOT NULL REFERENCES nc.source_document(id),
  ord                int  NOT NULL,
  text               text NOT NULL,
  token_count        int  NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_chunk_ord ON nc.document_chunk(source_document_id, ord);
CREATE INDEX IF NOT EXISTS ix_chunk_doc ON nc.document_chunk(account_id, source_document_id);
ALTER TABLE nc.document_chunk ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_document_chunk_tenant ON nc.document_chunk USING (account_id = nc.current_account_id());
```

### **6.10 embedding_ref**

```sql
CREATE TABLE IF NOT EXISTS nc.embedding_ref (
  id                text PRIMARY KEY,
  account_id        text NOT NULL REFERENCES nc.account(id),
  document_chunk_id text NOT NULL REFERENCES nc.document_chunk(id),
  weaviate_class    text NOT NULL,
  weaviate_uuid     text NOT NULL,
  model_key         text NOT NULL,
  vector_dim        int  NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_embedding_chunk
  ON nc.embedding_ref(document_chunk_id);

CREATE INDEX IF NOT EXISTS ix_embedding_tenant
  ON nc.embedding_ref(account_id, weaviate_class);

CREATE INDEX IF NOT EXISTS ix_embedding_model
  ON nc.embedding_ref(account_id, model_key);

ALTER TABLE nc.embedding_ref ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_embedding_ref_tenant
  ON nc.embedding_ref USING (account_id = nc.current_account_id());
```

### **6.11 ingestion_job**

```
CREATE TABLE IF NOT EXISTS nc.ingestion_job (
  id             text PRIMARY KEY,
  account_id     text NOT NULL REFERENCES nc.account(id),
  data_source_id text NOT NULL REFERENCES nc.data_source(id),
  status         nc.status_job NOT NULL DEFAULT 'QUEUED',
  started_at     timestamptz,
  ended_at       timestamptz,
  stats          jsonb,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_ing_job_status ON nc.ingestion_job(account_id, status, started_at);
ALTER TABLE nc.ingestion_job ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_ingestion_job_tenant ON nc.ingestion_job USING (account_id = nc.current_account_id());
```

### **6.12 scan**

```
CREATE TABLE IF NOT EXISTS nc.scan (
  id             text PRIMARY KEY,
  account_id     text NOT NULL REFERENCES nc.account(id),
  scope          jsonb NOT NULL,
  status         nc.status_scan NOT NULL DEFAULT 'QUEUED',
  started_at     timestamptz,
  ended_at       timestamptz,
  control_set_id text REFERENCES nc.policy(id),
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_scan_status ON nc.scan(account_id, status, started_at);
ALTER TABLE nc.scan ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_scan_tenant ON nc.scan USING (account_id = nc.current_account_id());
```

### **6.13 control (SCD2)**

```
CREATE TABLE IF NOT EXISTS nc.control (
  id          text PRIMARY KEY,
  key         text NOT NULL,
  title       text NOT NULL,
  description text NOT NULL,
  severity    nc.severity NOT NULL,
  category    text NOT NULL,
  rationale   text,
  "references"  jsonb,
  valid_from  timestamptz NOT NULL,
  valid_to    timestamptz,
  is_current  boolean NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_control_current ON nc.control(key) WHERE is_current = true;
```

### **6.14 policy (SCD2 with embedded controls)**

```
CREATE TABLE IF NOT EXISTS nc.policy (
  id            text PRIMARY KEY,
  account_id    text NOT NULL REFERENCES nc.account(id),
  name          text NOT NULL,
  controls      jsonb NOT NULL,  -- array of { key, weight, params }
  version_label text NOT NULL,
  valid_from    timestamptz NOT NULL,
  valid_to      timestamptz,
  is_current    boolean NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_policy_name_current
  ON nc.policy(account_id, name) WHERE is_current = true;
ALTER TABLE nc.policy ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_policy_tenant ON nc.policy USING (account_id = nc.current_account_id());
```

### **6.15 finding**

```
CREATE TABLE IF NOT EXISTS nc.finding (
  id             text PRIMARY KEY,
  account_id     text NOT NULL REFERENCES nc.account(id),
  scan_id        text NOT NULL,
  control_key    text NOT NULL,
  asset_id       text REFERENCES nc.asset(id),
  status         nc.status_finding NOT NULL DEFAULT 'OPEN',
  severity       nc.severity NOT NULL,
  evidence_score numeric(5,2),
  summary        text NOT NULL,
  details        jsonb,
  first_seen_at  timestamptz NOT NULL,
  last_seen_at   timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
-- Zero downtime FK pattern
ALTER TABLE nc.finding
  ADD CONSTRAINT fk_finding_scan
  FOREIGN KEY (scan_id) REFERENCES nc.scan(id) NOT VALID;
ALTER TABLE nc.finding VALIDATE CONSTRAINT fk_finding_scan;

CREATE INDEX IF NOT EXISTS ix_finding_open
  ON nc.finding(account_id, status, severity, last_seen_at DESC);
CREATE INDEX IF NOT EXISTS ix_finding_asset ON nc.finding(asset_id);
ALTER TABLE nc.finding ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_finding_tenant ON nc.finding USING (account_id = nc.current_account_id());
```

### **6.16 evidence**

```
CREATE TABLE IF NOT EXISTS nc.evidence (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  finding_id   text NOT NULL REFERENCES nc.finding(id),
  content_uri  text NOT NULL,
  content_type text NOT NULL,
  hash_sha256  text NOT NULL,
  captured_at  timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_evidence_finding ON nc.evidence(finding_id);
ALTER TABLE nc.evidence ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_evidence_tenant ON nc.evidence USING (account_id = nc.current_account_id());
```

### **6.17 remediation**

```
CREATE TABLE IF NOT EXISTS nc.remediation (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  finding_id   text NOT NULL REFERENCES nc.finding(id),
  plan         jsonb NOT NULL,
  executor     nc.exec_type NOT NULL,
  status       nc.status_job NOT NULL DEFAULT 'QUEUED',
  started_at   timestamptz,
  completed_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_remediation_finding ON nc.remediation(finding_id, status);
ALTER TABLE nc.remediation ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_remediation_tenant ON nc.remediation USING (account_id = nc.current_account_id());
```

### **6.18 ticket**

```
CREATE TABLE IF NOT EXISTS nc.ticket (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  finding_id   text NOT NULL REFERENCES nc.finding(id),
  provider     nc.ticket_provider NOT NULL,
  external_key text NOT NULL,
  url          text NOT NULL,
  status       text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_ticket_ext ON nc.ticket(provider, external_key);
ALTER TABLE nc.ticket ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_ticket_tenant ON nc.ticket USING (account_id = nc.current_account_id());
```

### **6.19 integration (SCD2)**

```
CREATE TABLE IF NOT EXISTS nc.integration (
  id          text PRIMARY KEY,
  account_id  text NOT NULL REFERENCES nc.account(id),
  type        nc.integration_type NOT NULL,
  config      jsonb NOT NULL,
  status      nc.status_toggle NOT NULL DEFAULT 'ACTIVE',
  valid_from  timestamptz NOT NULL,
  valid_to    timestamptz,
  is_current  boolean NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_integration_current
  ON nc.integration(account_id, type) WHERE is_current = true;
ALTER TABLE nc.integration ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_integration_tenant ON nc.integration USING (account_id = nc.current_account_id());
```

### **6.20 notification**

```
CREATE TABLE IF NOT EXISTS nc.notification (
  id           text PRIMARY KEY,
  account_id   text NOT NULL REFERENCES nc.account(id),
  channel      nc.integration_type NOT NULL,
  template_key text NOT NULL,
  payload      jsonb NOT NULL,
  sent_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_notification_time ON nc.notification(account_id, sent_at DESC);
ALTER TABLE nc.notification ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_notification_tenant ON nc.notification USING (account_id = nc.current_account_id());
```

### **6.21 audit_log  (monthly partitions)**

```
CREATE TABLE IF NOT EXISTS nc.audit_log (
  id            text NOT NULL,
  account_id    text NOT NULL REFERENCES nc.account(id),
  actor_user_id text,
  action        text NOT NULL,
  target        jsonb NOT NULL,
  ip            text,
  occurred_at   timestamptz NOT NULL,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE IF NOT EXISTS nc.audit_log_2025_10
  PARTITION OF nc.audit_log FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE INDEX IF NOT EXISTS ix_audit_log_time_2025_10
  ON nc.audit_log_2025_10(account_id, occurred_at DESC);

ALTER TABLE nc.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_audit_log_tenant ON nc.audit_log USING (account_id = nc.current_account_id());
```

### **6.22 job**

```
CREATE TABLE IF NOT EXISTS nc.job (
  id         text PRIMARY KEY,
  account_id text NOT NULL REFERENCES nc.account(id),
  type       text NOT NULL,
  status     nc.status_job NOT NULL DEFAULT 'QUEUED',
  payload    jsonb NOT NULL,
  result     jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_job_status ON nc.job(account_id, status, created_at DESC);
ALTER TABLE nc.job ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_job_tenant ON nc.job USING (account_id = nc.current_account_id());
```

### **6.23 event  (monthly partitions)**

```
CREATE TABLE IF NOT EXISTS nc.event (
  id              text NOT NULL,
  account_id      text NOT NULL REFERENCES nc.account(id),
  type            text NOT NULL,
  schema_version  int  NOT NULL,
  event_version   int  NOT NULL,
  occurred_at     timestamptz NOT NULL,
  payload         jsonb NOT NULL,
  checksum_sha256 text NOT NULL,
  PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE IF NOT EXISTS nc.event_2025_10
  PARTITION OF nc.event FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');

CREATE INDEX IF NOT EXISTS ix_event_time_2025_10
  ON nc.event_2025_10(account_id, type, occurred_at DESC);

ALTER TABLE nc.event ENABLE ROW LEVEL SECURITY;
CREATE POLICY p_event_tenant ON nc.event USING (account_id = nc.current_account_id());
```

## **7. Tenant-context enforcement triggers**

```
CREATE OR REPLACE FUNCTION nc.enforce_tenant_context()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM nc.require_tenant_context();
  IF TG_OP IN ('INSERT','UPDATE') THEN
    IF NEW.account_id IS DISTINCT FROM current_setting('app.account_id') THEN
      RAISE EXCEPTION 'account_id mismatch';
    END IF;
  END IF;
  RETURN NEW;
END$$;

DO $$
DECLARE t regclass;
BEGIN
  FOR t IN
    SELECT c.oid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'nc'
      AND c.relkind = 'r'
      AND c.relname IN ('user','role','role_assignment','cloud_account','data_source',
                        'asset','source_document','document_chunk','embedding_ref',
                        'ingestion_job','scan','policy','finding','evidence','remediation',
                        'ticket','integration','notification','audit_log','job','event')
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_tenant_guard ON %s', t);
    EXECUTE format($f$
      CREATE TRIGGER trg_tenant_guard
      BEFORE INSERT OR UPDATE ON %s
      FOR EACH ROW EXECUTE FUNCTION nc.enforce_tenant_context()
    $f$, t);
  END LOOP;
END$$;
```

## **8. Partition management**

```
CREATE OR REPLACE PROCEDURE nc.ensure_month_partitions(month_start date)
LANGUAGE plpgsql AS $$
DECLARE next_start date := (month_start + INTERVAL '1 month')::date;
BEGIN
  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS nc.audit_log_%s PARTITION OF nc.audit_log FOR VALUES FROM (%L) TO (%L)',
    to_char(month_start,'YYYY_MM'), month_start, next_start
  );
  EXECUTE format(
    'CREATE INDEX IF NOT EXISTS ix_audit_log_time_%s ON nc.audit_log_%s(account_id, occurred_at DESC)',
    to_char(month_start,'YYYY_MM'), to_char(month_start,'YYYY_MM')
  );

  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS nc.event_%s PARTITION OF nc.event FOR VALUES FROM (%L) TO (%L)',
    to_char(month_start,'YYYY_MM'), month_start, next_start
  );
  EXECUTE format(
    'CREATE INDEX IF NOT EXISTS ix_event_time_%s ON nc.event_%s(account_id, type, occurred_at DESC)',
    to_char(month_start,'YYYY_MM'), to_char(month_start,'YYYY_MM')
  );
END$$;
```

**Triggering policy**

- Run nc.ensure_month_partitions(date_trunc('month', now())) on day 1 monthly
    
- Promote document_chunk to monthly partitions if monthly inserts exceed 3 million rows for two consecutive months
    

  

## **9. S3 storage map**

  

Bucket per environment: nc-prod-data, nc-stg-data. SSE-KMS CMK alias/nc-data. Versioning on. Public access blocked.

  

**Prefix**

```
s3://nc-<env>-data/{account_id}/{entity}/{yyyy}/{MM}/{dd}/{ulid}.jsonl
```

**Lifecycle**

```
{
  "Rules": [
    { "ID": "RC1", "Filter": { "Tag": { "Key": "rc", "Value": "RC1" } },
      "Status": "Enabled", "Expiration": { "Days": 2555 } },
    { "ID": "RC2", "Filter": { "Tag": { "Key": "rc", "Value": "RC2" } },
      "Status": "Enabled", "Expiration": { "Days": 730 } },
    { "ID": "RC3", "Filter": { "Tag": { "Key": "rc", "Value": "RC3" } },
      "Status": "Enabled", "Expiration": { "Days": 90 } },
    { "ID": "RC4", "Filter": { "Tag": { "Key": "rc", "Value": "RC4" } },
      "Status": "Enabled", "Expiration": { "Days": 1 } }
  ]
}
```

**Bucket policy**

```
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::nc-*-data","arn:aws:s3:::nc-*-data/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } } }
  ]
}
```

**Object tags**

- Tag each object with rc=RC{1..4} to bind to lifecycle rules.
    

  

## **10. KMS key policy**

```
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "RootAdmin",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::<ACCOUNT>:root" },
      "Action": "kms:*",
      "Resource": "*" },
    { "Sid": "AppUse",
      "Effect": "Allow",
      "Principal": { "AWS": ["arn:aws:iam::<ACCOUNT>:role/nc_app_rw"] },
      "Action": ["kms:Encrypt","kms:Decrypt","kms:GenerateDataKey*"],
      "Resource": "*" }
  ]
}
```

## **11. Weaviate classes and HA tuning**

Multi-tenancy enabled. Tenant equals account_id. NcChunkV1 does not store account_id as a property; tenant isolation is enforced exclusively via `multiTenancyConfig` with tenant name = account_id.

Canonical machine-readable schema lives at `schemas/weaviate/nc-chunk-v1.json`.

```
{
  "class": "NcChunkV1",
  "multiTenancyConfig": { "enabled": true },
  "replicationConfig": { "factor": 3 },
  "shardingConfig": { "virtualPerPhysical": 128 },
  "vectorIndexType": "hnsw",
  "vectorIndexConfig": { "efConstruction": 128, "maxConnections": 64, "ef": 64 },
  "vectorizer": "none",
  "properties": [
    { "name": "chunk_id", "dataType": ["text"] },
    { "name": "source_document_id", "dataType": ["text"] },
    { "name": "ord", "dataType": ["int"] },
    { "name": "text", "dataType": ["text"] },
    { "name": "token_count", "dataType": ["int"] },
    { "name": "retention_class", "dataType": ["text"] },
    { "name": "created_at", "dataType": ["date"] }
  ]
}
```

Indexing contract

- Vectors pushed by application
    
- embedding_ref stores weaviate_class and weaviate_uuid
    
- Delete in Weaviate only after embedding_ref delete
    

### **11.1 Search index (OpenSearch nc-chunk-v1)**

OpenSearch hosts a chunk-level keyword/text index that mirrors a subset of `nc.document_chunk`, `nc.source_document`, and `nc.embedding_ref` for BM25 search and filtering.

- **Index pattern**

  - Index name pattern: `nc-chunk-v1-*`
  - Template: `schemas/opensearch/chunk-v1.json`
  - ILM / ISM policy: `schemas/opensearch/policies/chunk-v1-ilm.json`

- **Mappings (logical view)**

  The `nc-chunk-v1-*` indices expose the following fields:

  - `account_id`         (`keyword`) – tenant key; **all queries MUST filter by account_id**
  - `chunk_id`           (`keyword`) – maps to `nc.document_chunk.id`
  - `source_document_id` (`keyword`) – maps to `nc.document_chunk.source_document_id`
  - `data_source_id`     (`keyword`) – maps to `nc.source_document.data_source_id`
  - `ord`                (`integer`) – chunk ordinal within a source_document
  - `text`               (`text`) – chunk text, BM25-searchable
  - `tags`               (`keyword`) – optional normalized tags for faceting
  - `created_at`         (`date`) – from `nc.document_chunk.created_at`
  - `retention_class`    (`keyword`) – RC1..RC4, copied from `nc.source_document.retention_class`
  - `model_key`          (`keyword`) – embedding model identifier (e.g. `openai/text-embedding-3-large`)

  The JSON template at `schemas/opensearch/chunk-v1.json` is the canonical machine-readable definition.

- **Retention and ILM**

  - Policy file: `schemas/opensearch/policies/chunk-v1-ilm.json`
  - States:
    - `hot` → `warm` after 60 days.
    - `warm` → `delete` after 90 days total index age.
  - This is **RC3-aligned** and matches the database purge window for `nc.source_document` / `nc.document_chunk` (see §14 Retention enforcement jobs).

- **Query and routing guidance**

  - All search requests **must** include `account_id` as a filter.
  - Where possible, scope by `model_key` to keep search behavior consistent with the embedding model used for Weaviate (`NcChunkV1`).
  - For debugging and correlation:
    - `chunk_id` joins back to `nc.document_chunk`.
    - `source_document_id` joins to `nc.source_document`.
    - `data_source_id` joins indirectly via `nc.source_document.data_source_id` to `nc.data_source`.


## **12. Backup and restore**

- Postgres PITR with WAL to s3://nc-<env>-pg-wal. Base backups daily 01:00 UTC
    
- Restore flow: new instance, restore latest base, replay WAL to timestamp. RTO 60 minutes
    
- S3 rollback via versioning
    
- Weaviate nightly export of NcChunkV1 tenants to S3 with RC2 retention
    

  

## **13. Data quality checks**

  

Run hourly. Failures create OPEN findings in a data quality policy.

```
-- One current row per asset URN per tenant
SELECT account_id, urn
FROM nc.asset WHERE is_current
GROUP BY account_id, urn HAVING COUNT(*) = 1;

-- Window closure
SELECT id FROM nc.control WHERE is_current = false AND valid_to IS NULL;

-- Orphans
SELECT f.id FROM nc.finding f LEFT JOIN nc.scan s ON s.id = f.scan_id WHERE s.id IS NULL;

-- Embedding one to one
SELECT document_chunk_id
FROM nc.embedding_ref GROUP BY document_chunk_id HAVING COUNT(*) = 1;
```

## **14. Retention enforcement jobs**

  

Mirror S3 lifecycle for database rows.

```
-- RC3: 90 days purge for chunks and source docs
CREATE OR REPLACE PROCEDURE nc.purge_rc3_90d()
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM nc.document_chunk dc
  USING nc.source_document sd
  WHERE dc.source_document_id = sd.id
    AND sd.retention_class = 'RC3'
    AND sd.collected_at < now() - INTERVAL '90 days';

  DELETE FROM nc.source_document sd
  WHERE sd.retention_class = 'RC3'
    AND sd.collected_at < now() - INTERVAL '90 days';
END$$;

-- RC2: 2 years purge for asset history and scans
CREATE OR REPLACE PROCEDURE nc.purge_rc2_2y()
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM nc.scan s
  WHERE s.account_id IS NOT NULL
    AND s.created_at < now() - INTERVAL '730 days';

  DELETE FROM nc.asset a
  WHERE a.is_current = false
    AND a.valid_to < now() - INTERVAL '730 days';
END$$;

-- RC4: 24 hours cleanup for transient notifications and jobs
CREATE OR REPLACE PROCEDURE nc.purge_rc4_24h()
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM nc.notification n
  WHERE n.sent_at IS NOT NULL
    AND n.sent_at < now() - INTERVAL '24 hours';

  DELETE FROM nc.job j
  WHERE j.created_at < now() - INTERVAL '24 hours'
    AND j.status IN ('COMPLETED','FAILED');
END$$;
```

Scheduling

- Run purgers daily at 02:10 UTC via the platform job runner
    
- Each run logs rows affected to nc.audit_log under action retention.purge
    

  

## **15. Masked analytics views for P1**

```
CREATE OR REPLACE VIEW nc.v_user_masked AS
SELECT
  id, account_id,
  regexp_replace(lower(email), '(^.).+(@.+$)', '\1***\2') AS email,
  display_name, auth_provider, status, mfa_enabled,
  created_at, updated_at
FROM nc."user";

GRANT SELECT ON nc.v_user_masked TO nc_readonly;
REVOKE SELECT ON nc."user" FROM nc_readonly;
```

## **16. Maintenance and operations**

- Isolation level: READ COMMITTED
    
- PgBouncer transaction pooling, cap 200 clients
    
- Autovacuum tuned on large partitions
    
- Nightly VACUUM on active partitions, weekly on historical
    
- Monthly REINDEX on largest indexes
    
- Statistics target 250 on finding, asset
    
- Statement timeout 2 seconds on OLTP connections
    
- Slow query log threshold 200 ms
    

  

## **17. Online migration safety**

  

Use NOT VALID and VALIDATE CONSTRAINT for foreign keys. Backfill patterns are batched.

```
ALTER TABLE nc.finding
ADD CONSTRAINT fk_finding_scan
FOREIGN KEY (scan_id) REFERENCES nc.scan(id) NOT VALID;

-- backfill if needed, then validate
ALTER TABLE nc.finding VALIDATE CONSTRAINT fk_finding_scan;
```

## **18. Data dictionary comments**

```
COMMENT ON TABLE  nc.finding IS 'Control evaluation results';
COMMENT ON COLUMN nc.finding.control_key IS 'Key of current nc.control used for evaluation';
COMMENT ON TABLE  nc.asset IS 'Normalized managed resources, SCD2 for history';
COMMENT ON COLUMN nc.asset.urn IS 'Provider neutral URN unique per tenant when is_current=true';
```

## **19. Observability hooks**

- All migrations produce checksums and write to audit_log
    
- Health checks run hourly and write summary counts to audit_log
    
- Storage watermarks alert at 70, 85, 95 percent
    

  

## **20. Crosswalk**

|**DM-001 entity**|**PostgreSQL table**|**S3 prefix**|**Weaviate class**|
|---|---|---|---|
|account|nc.account|n/a|n/a|
|user|nc.user|n/a|n/a|
|role|nc.role|n/a|n/a|
|role_assignment|nc.role_assignment|n/a|n/a|
|cloud_account|nc.cloud_account|n/a|n/a|
|data_source|nc.data_source|n/a|n/a|
|asset|nc.asset|optional export|n/a|
|source_document|nc.source_document|source_document|n/a|
|document_chunk|nc.document_chunk|document_chunk|NcChunkV1|
|embedding_ref|nc.embedding_ref|n/a|refers to NcChunkV1|
|ingestion_job|nc.ingestion_job|n/a|n/a|
|scan|nc.scan|n/a|n/a|
|control|nc.control|n/a|n/a|
|policy|nc.policy|n/a|n/a|
|finding|nc.finding|optional export|n/a|
|evidence|nc.evidence|evidence|n/a|
|remediation|nc.remediation|n/a|n/a|
|ticket|nc.ticket|n/a|n/a|
|integration|nc.integration|n/a|n/a|
|notification|nc.notification|n/a|n/a|
|audit_log|nc.audit_log|optional export|n/a|
|job|nc.job|n/a|n/a|
|event|nc.event|event|n/a|

## **21. Security model**

- Roles
    
    - nc_admin for DDL, RLS bypass, set app.account_id
        
    - nc_app_rw with RLS enforced
        
    - nc_readonly with masked views for P1
        
    
- Secrets in KMS, DB over TLS, S3 with KMS, Weaviate keys per environment
    
- Change logs and access logged to audit_log
    

  

## **22. Backup and disaster recovery SLOs**

- PITR tested quarterly. Evidence recorded in audit_log
    
- S3 restore tested quarterly for a random sample
    
- Weaviate export restore drill twice per year
    

  

## **23. RACI**

- Responsible: Data Architecture
    
- Accountable: Head of Platform
    
- Consulted: Security, Compliance
    
- Informed: Product, Support
    

  

## **24. Acceptance Criteria**

- All tables, indexes, RLS policies exist as defined
    
- Tenant-context triggers deployed on all tenant tables
    
- Partitions for audit_log and event exist for current and next month
    
- Partition procedure scheduled monthly
    
- Retention procedures deployed and scheduled
    
- Masked analytics view v_user_masked created and grants adjusted
    
- S3 lifecycle rules active for RC1 to RC4 with object tags in place
    
- KMS CMK configured with the stated policy
    
- Weaviate class NcChunkV1 created with replication and HNSW tuning
    
- Backup and PITR drill results logged within the last quarter
    
- No DynamoDB references. No references to external projects
