id: SVC-002
title: Offline Export Contract Overview
owner: platform-serving / data platform
status: Draft v0.1
last_reviewed: 2025-11-09

# SVC-002 Offline Export Contract

**References:** SVC-002-Offline-Export-Contract-Specification.md, LAK-001, PROC-001, DR-001

---

## 1. Purpose
Describe the governed interface for scheduled and ad-hoc exports (batch files, lakehouse pulls, customer S3 deliveries) to ensure consistent schemas, encryption, and auditing.

## 2. Export Channels
| Channel | Delivery | Frequency | Schema Source | Notes |
|---------|----------|-----------|---------------|-------|
| Lakehouse Snapshot | Iceberg manifest | Daily | `schemas/events/export.snapshot.v1.json` | Customers query via Athena workgroup |
| Customer S3 Drop | Encrypted Parquet | Hourly | `schemas/events/export.customer_drop.v1.json` | Customer-managed bucket, enforced KMS |
| Partner API Bundle | Signed ZIP via presigned URL | Ad-hoc | `schemas/events/export.partner.zip.v1.json` | Contains OpenAPI + sample payloads |
| Audit Package | GZIP JSON lines | Monthly | `schemas/events/export.audit.v1.json` | Includes hash chain + evidence pack |

## 3. Sample Deliveries
```text
s3://nc-exports-prod/acme/export.discovery.20251109.parquet
s3://nc-exports-prod/acme/export.discovery.20251109.parquet.sha256
```

```json
{
  "dataset": "discovery",
  "generated_at": "2025-11-09T03:30:00Z",
  "encryption": "aws:kms:arn:aws:kms:us-east-1:123456789012:key/acme",
  "records": 125034,
  "schema_version": "export.snapshot.v1"
}
```

```shell
aws s3 cp s3://nc-exports-prod/acme/export.discovery.20251109.parquet .
aws s3 cp s3://nc-exports-prod/acme/export.discovery.20251109.parquet.sha256 .
sha256sum --check export.discovery.20251109.parquet.sha256
```

## 4. Versioning Policy
| Channel | Current Version | Promotion Rule | Sunset Window |
|---------|-----------------|----------------|---------------|
| Lakehouse Snapshot | `snapshot.v1` | Promote after Iceberg schema passes contract suite | 120 days once `v2` announced |
| Customer S3 Drop | `customer_drop.v1` | Promote when dual-delivery succeeds for 7 days | 60 days |
| Partner API Bundle | `partner.zip.v1` | Promote post security review + sample approval | 90 days |
| Audit Package | `audit.v1` | Promote upon compliance sign-off | 180 days |

## 5. Contract Guardrails
- All exports derived from governed tables listed in LAK-001; no ad-hoc SQL without review.  
- Encryption: KMS CMKs per tenant; data classified ≥ Restricted uses customer-provided keys.  
- Naming: `export.<dataset>.<yyyymmdd>.parquet`. No spaces or uppercase.  
- Access provisioning uses `ops/owners.yaml` for approvals and is logged in IAM change tracker.  
- Standard headers on export-control APIs (for example, `/admin/exports`): `Authorization`, `Tenant-Id`, `Correlation-Id`, aligned with API-001; any write-style operations also require `Idempotency-Key`.  
- Export schemas for each channel (snapshot, customer drop, partner bundle, audit package) must be stored in `schemas/events/` and versioned, with changes following the same compatibility and deprecation rules as other contracts.

## 6. SLA & Compliance
- RPO ≤ 60 minutes for scheduled exports; ad-hoc commitments documented per request.  
- Delivery verification: `sha256sum` manifests stored in `s3://nc-audit-artifacts/exports/`.  
- DR-001 requires rehydrating export pipelines within 6 hours post-incident.

## 7. Validation Workflow
1. Modify contract schema → run `npm run spectral` plus JSON schema tests.  
2. Generate sample export via `python tools/export_sample.py --channel <name>`.  
3. Update `docs/serving/SVC-002-Offline-Export-Contract-Specification.md` with change notes.  
4. Obtain approvals from platform-serving + requesting partner team.  
5. Record delivery evidence (hash + timestamp) for every production run.

## 8. Change Log
|| Version | Date | Summary |
||---------|------|---------|
|| v0.1 | 2025-11-09 | Initial overview distilled from SVC-002 specification |

## 9. Acceptance Criteria
- Export channels and schemas are documented in SVC-002 and registered under `schemas/events/` with explicit versions.  
- All production exports are encrypted with the correct CMK (or customer-provided keys for Restricted data) and validated via checksum manifests.  
- Export naming and layout conventions (dataset, date, tenant) match LAK-001 and can be queried consistently by downstream tools.  
- RPO/RTO targets for export pipelines (including DR-001 requirements) are met during DR drills and documented with evidence.  
- Access provisioning for export destinations is traceable via `ops/owners.yaml` and IAM change records.
