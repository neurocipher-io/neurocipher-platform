-- 0001_nc_core_metadata.sql
-- Core nc schema foundation and ingestion metadata tables

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

-- 6.1 account
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

-- 6.6 data_source (SCD2)
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

-- 6.8 source_document
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

-- 6.9 document_chunk (partition on demand)
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

-- 6.10 embedding_ref
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

-- 6.11 ingestion_job
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

-- Tenant-context enforcement triggers
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
