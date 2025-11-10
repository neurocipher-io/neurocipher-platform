# LAK-001 — Lakehouse Layout (Iceberg/S3)

**Document ID:** LAK-001  
**Title:** Lakehouse Layout (Iceberg/S3)  
**Status:** Final v1.0  
**Owner:** Data Platform Engineering / Data Architecture Lead  
**Applies to:** Neurocipher Core Platform and AuditHound module  
**Last Reviewed:** 2025-11-07  
**Classification:** Internal – Data Architecture  
**References:** DM-001–005, ING-001–003, SRG-001, CI/CL-001–003, OBS-001–003, GOV-001–002, ADR-009–011  

---

## 1. Purpose
Define the canonical layout, governance model, and operational controls for the Neurocipher Lakehouse environment using **Apache Iceberg on Amazon S3**.  
This document ensures consistent table structure, partitioning, metadata retention, and security controls for analytical and machine learning workloads.

---

## 2. Scope

**In Scope**
- Iceberg table design and namespace layout  
- Partitioning, metadata, and manifest management  
- Object lifecycle and retention policies  
- Versioning and rollback strategies  
- Integration with Athena / Glue / EMR / Bedrock consumers  
- Data access governance and S3 IAM configuration  

**Out of Scope**
- Upstream ingestion (ING-001–003)  
- Downstream model serving (SVC-001/002)  
- Visualization or BI tool definitions  

---

## 3. Architecture Overview

### 3.1 Logical Components

| Component | Description |
|------------|-------------|
| **S3 Bucket `nc-lake-<env>`** | Primary storage for Iceberg tables (Parquet + metadata) |
| **AWS Glue Catalog** | Hive-compatible metastore for table definitions |
| **Athena / EMR** | Query execution and ad-hoc analytics |
| **Lake API Layer (ECS service)** | Internal REST API for table registration and commit operations |
| **CI/CD Integration** | Automated DDL migration and schema evolution pipeline |
| **Observability Stack** | CloudWatch + Prometheus exporter for Iceberg metrics |

### 3.2 Data Zones

| Zone | Purpose | Example Bucket Prefix |
|-------|----------|----------------------|
| **Raw** | Immutable payloads from ING-001 | `s3://nc-raw-prd/ten=acme/...` |
| **Clean** | Canonical validated records (ING-002) | `s3://nc-clean-prd/...` |
| **Lake** | Enriched Iceberg tables (ING-003) | `s3://nc-lake-prd/...` |
| **Derived** | Aggregates / feature stores | `s3://nc-lake-prd/derived/...` |

---

## 4. Physical Layout and Partitioning

### 4.1 Naming Conventions
```
s3://nc-lake-<env>/<tenant>/<domain>/<dataset>/<table>/
```
Example:  
`s3://nc-lake-prd/acme/security/audit_events/v1/`

### 4.2 Partition Strategy

| Dataset Type | Partition Keys | Notes |
|---------------|----------------|-------|
| Audit Events | `dt`, `hr`, `region` | Hourly query efficiency |
| IAM Changes | `dt`, `tenant_id` | Tenant segmentation |
| Vulnerability Findings | `year`, `month`, `severity` | Optimized for reporting |
| Logs and Metrics | `dt`, `service` | Aligned with OBS dashboards |

### 4.3 Table Format
- File Format: **Parquet** (Snappy compression)  
- Manifest Format: **Iceberg v2** with manifest list checksum  
- Snapshot Retention: Last 30 snapshots or 30 days whichever greater  
- Metadata Retention: 7 days (automatic cleanup via `expire_snapshots`)  

---

## 5. Schema and Versioning

- All Iceberg schemas derive from canonical models (DM-001–005).  
- Schema evolution managed via CI/CD migration workflow.  
- Version stored in table metadata:  
  ```
  "schema_version": "v1.2.0",
  "schema_urn": "com.nc.audit.enriched.v1"
  ```
- Backward compatible additions allowed; breaking changes require ADR and new table version.

---

## 6. Lifecycle and Retention Policy

| Zone | Retention | Lifecycle Action |
|-------|------------|------------------|
| Raw | 180 days | Transition to Glacier Deep Archive |
| Clean | 365 days | Transition to IA after 90 days |
| Lake | 730 days | Expire snapshots > 2 years |
| Derived | 365 days | Auto purge stale derived tables |

Lifecycle rules enforced through S3 Lifecycle Policies and validated quarterly under GOV-002.

---

## 7. Access and Security

- **IAM Segregation:** Read/Write roles per zone (`lake-writer`, `lake-reader`).  
- **Encryption:** KMS CMK per environment.  
- **Networking:** Private VPC endpoints for S3 and Glue.  
- **Data Classification Tags:** `{tenant, domain, classification, schema_urn}`.  
- **Audit Logging:** S3 Server Access Logs + CloudTrail Data Events.  
- **Compliance:** CIS AWS Foundations 1.5, ISO 27001 A.12, SOC 2 CC6.6.

---

## 8. Operational Controls

### 8.1 CI/CD Integration
- CI Pipeline executes DDL checks and `iceberg-migrate` scripts.  
- Pre-merge validation via Glue Data Catalog API.  
- Post-deploy validation verifies manifest consistency and object count.  

### 8.2 Monitoring and Metrics
- `iceberg_commit_latency_seconds`  
- `manifest_files_total`  
- `snapshot_expire_events_total`  
- `orphan_files_detected_total`  
- Dashboard: “Lakehouse Health – <env>”  
- Page SRE if commit latency > 5 s (p95) or orphan files > 10.

### 8.3 Backup and Recovery
- Daily catalog backups to `s3://nc-backups-<env>/glue/`  
- Disaster Recovery validated per DR-001 annually.  
- Cross-region replication optional (`ca-central-1` ↔ `us-east-1`).

---

## 9. Governance and Compliance

- **Data Ownership:** Data Platform Team (primary), Audit Team (secondary).  
- **Change Management:** ADR approval for partitioning or lifecycle rule changes.  
- **Access Review:** Quarterly under GOV-001.  
- **Version Control:** All DDL scripts tracked in `/lake/schema/`.  
- **Evidence Pack:** Generated automatically post-deployment (`/ci/artifacts/lak-001/<build_id>/`).

---

## 10. Runbooks

| ID | Name | Description |
|----|------|-------------|
| RB-LAK-001-A | Snapshot Expiration Procedure | Manual cleanup of obsolete snapshots |
| RB-LAK-001-B | Orphan File Remediation | Detect and delete unreferenced Parquet files |
| RB-LAK-001-C | Catalog Rebuild | Restore Glue Catalog from S3 backup |
| RB-LAK-001-D | Lifecycle Policy Verification | Validate retention rules and object transitions |

---

## 11. Acceptance Criteria
- ✅ All Iceberg tables registered and queryable via Glue and Athena.  
- ✅ Retention policies active and verified in GOV-002 audit.  
- ✅ SLOs met: p95 commit latency < 5 s, success rate ≥ 99.9 %.  
- ✅ Disaster recovery validated per DR-001.  
- ✅ CI/CD promotion pipeline green with evidence attached.

---

## 12. Revision History

| Version | Date | Author | Summary |
|----------|------|---------|----------|
| v1.0 | 2025-11-07 | Data Platform Lead | Initial full release aligned with CI/CL-003 and OBS-003 |

---

**End of Document**
