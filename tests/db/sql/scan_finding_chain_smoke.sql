-- scan_finding_chain_smoke.sql
-- Minimal realistic chain for smoke-testing multi-tenant RLS and scan → finding → ticket chain
-- Assumes migrations have been applied and nc_app_rw role exists with proper privileges

-- Insert account
INSERT INTO nc.account (id, name, status, region, created_at, updated_at, created_by, updated_by)
VALUES (
  'acct_scan_1',
  'Test Scan Account',
  'ACTIVE',
  'us-east-1',
  now(),
  now(),
  'system',
  'system'
);

-- Insert control (not tenant-scoped, but required for policy)
INSERT INTO nc.control (id, key, title, description, severity, category, valid_from, is_current, created_at, updated_at)
VALUES (
  'ctrl_001',
  'S3_BUCKET_PUBLIC_ACCESS',
  'S3 Bucket Public Access',
  'Check if S3 bucket has public access enabled',
  'HIGH',
  'DATA_PROTECTION',
  now(),
  true,
  now(),
  now()
);

-- Insert policy (tenant-scoped)
INSERT INTO nc.policy (id, account_id, name, controls, version_label, valid_from, is_current, created_at, updated_at)
VALUES (
  'pol_001',
  'acct_scan_1',
  'Test Policy',
  '[{"key": "S3_BUCKET_PUBLIC_ACCESS", "weight": 1.0, "params": {}}]'::jsonb,
  'v1.0',
  now(),
  true,
  now(),
  now()
);

-- Insert scan (tenant-scoped)
INSERT INTO nc.scan (id, account_id, scope, status, started_at, ended_at, control_set_id, created_at)
VALUES (
  'scan_001',
  'acct_scan_1',
  '{"cloud_accounts": ["aws-123456789"], "regions": ["us-east-1"]}'::jsonb,
  'COMPLETED',
  now() - interval '1 hour',
  now() - interval '30 minutes',
  'pol_001',
  now()
);

-- Insert asset (tenant-scoped)
INSERT INTO nc.asset (id, account_id, cloud_account_id, urn, type, region, tags, state, discovered_at, valid_from, is_current, created_at, updated_at)
VALUES (
  'asset_001',
  'acct_scan_1',
  NULL,
  'arn:aws:s3:::test-bucket-001',
  's3-bucket',
  'us-east-1',
  '{"Environment": "test"}'::jsonb,
  'ACTIVE',
  now() - interval '2 hours',
  now() - interval '2 hours',
  true,
  now(),
  now()
);

-- Insert finding (tenant-scoped)
INSERT INTO nc.finding (id, account_id, scan_id, control_key, asset_id, status, severity, evidence_score, summary, details, first_seen_at, last_seen_at, created_at)
VALUES (
  'find_001',
  'acct_scan_1',
  'scan_001',
  'S3_BUCKET_PUBLIC_ACCESS',
  'asset_001',
  'OPEN',
  'HIGH',
  95.5,
  'S3 bucket test-bucket-001 has public access enabled',
  '{"block_public_acls": false, "ignore_public_acls": false}'::jsonb,
  now() - interval '30 minutes',
  now() - interval '30 minutes',
  now()
);

-- Insert evidence (tenant-scoped)
INSERT INTO nc.evidence (id, account_id, finding_id, content_uri, content_type, hash_sha256, captured_at, created_at)
VALUES (
  'evid_001',
  'acct_scan_1',
  'find_001',
  's3://nc-evidence/acct_scan_1/find_001/screenshot.png',
  'image/png',
  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
  now() - interval '30 minutes',
  now()
);

-- Insert remediation (tenant-scoped)
INSERT INTO nc.remediation (id, account_id, finding_id, plan, executor, status, started_at, completed_at, created_at)
VALUES (
  'rem_001',
  'acct_scan_1',
  'find_001',
  '{"steps": ["Apply bucket policy", "Block public access"], "estimated_duration": "5m"}'::jsonb,
  'MANUAL',
  'QUEUED',
  NULL,
  NULL,
  now()
);

-- Insert ticket (tenant-scoped)
INSERT INTO nc.ticket (id, account_id, finding_id, provider, external_key, url, status, created_at)
VALUES (
  'tick_001',
  'acct_scan_1',
  'find_001',
  'JIRA',
  'SEC-12345',
  'https://jira.example.com/browse/SEC-12345',
  'OPEN',
  now()
);

-- Insert integration (tenant-scoped)
INSERT INTO nc.integration (id, account_id, type, config, status, valid_from, is_current, created_at, updated_at)
VALUES (
  'intg_001',
  'acct_scan_1',
  'SLACK',
  '{"webhook_url": "https://hooks.slack.com/services/XXX", "channel": "#security"}'::jsonb,
  'ACTIVE',
  now(),
  true,
  now(),
  now()
);

-- Insert notification (tenant-scoped)
INSERT INTO nc.notification (id, account_id, channel, template_key, payload, sent_at, created_at)
VALUES (
  'notif_001',
  'acct_scan_1',
  'SLACK',
  'FINDING_ALERT',
  '{"finding_id": "find_001", "severity": "HIGH", "summary": "S3 bucket public access"}'::jsonb,
  now() - interval '25 minutes',
  now()
);
