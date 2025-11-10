# Document ID: SVC-002
**Title:** Offline Export Contract Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Platform SRE  
**Applies to:** Neurocipher Core and AuditHound Module  
**Last Reviewed:** 2025-11-09  
**References:** PROC-001–003, DM-001–005, DCON-001, LAK-001, DQ-001, LIN-001, CAP-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the governed interface and lifecycle for offline data exports from the Neurocipher Core Lakehouse and serving layers.  
Ensures compliance, auditability, and reproducibility for all bulk data deliveries across internal and external consumers.

---

## 2. Scope
**In scope:**  
- Batch export pipelines for analytical workloads and regulatory reporting.  
- Delivery mechanisms via S3, HTTPS presigned URLs, or Snowflake external tables.  
- Schema versioning, encryption, and checksum validation per **DCON-001** and **SRG-001**.  
- Integration with DQ, lineage, and capacity models for export observability.  

**Out of scope:**  
- Real-time or query-based delivery (covered by **SVC-001 Online Serving Contract**).  

---

## 3. Export Model
Offline exports operate under governed **Export Contracts**, defining dataset, schema, format, encryption, and retention policies.  
Each contract is stored in `schema-registry/export/` and validated in CI.

| Field | Description | Example |
|-------|--------------|----------|
| **export_id** | Unique export contract ID | `urn:nc:svc:export:user_activity_v3` |
| **dataset_ref** | Source dataset from DM-003 | `urn:nc:dataset:proc-001-user-activity` |
| **schema_ref** | Registered schema digest | `urn:nc:schema:user_activity:v3` |
| **format** | Output format (parquet, csv, json) | `parquet` |
| **compression** | Codec for compression | `snappy` |
| **destination** | Target S3 prefix or external system | `s3://nc-prod-export/user_activity/` |
| **encryption** | KMS key alias | `alias/nc-prod-data` |
| **retention_days** | Retention period | `90` |
| **delivery_method** | `s3`, `presigned`, `snowflake` | `s3` |

---

## 4. Architecture
**Pattern:** Batch-driven export orchestrated by Step Functions and ECS Fargate, with optional Snowflake data share integration.

| Layer | Component | Standard |
|--------|------------|----------|
| **Orchestration** | AWS Step Functions (`svc_export_state_machine`) | CI/CL-001 |
| **Compute** | ECS Fargate containers | CAP-001 |
| **Storage** | S3 Iceberg export zone (`s3://nc-<env>-export/`) | LAK-001 |
| **Metadata Registry** | DynamoDB `export_registry` | DM-003 |
| **Delivery** | S3 presigned URL, Snowflake external table, or HTTPS download API | SVC-002 |
| **Observability** | ADOT collector + Prometheus | OBS-002 |

---

## 5. Execution Flow
1. **Trigger:** Manual invocation, scheduled cron, or downstream signal from PROC-001/002.  
2. **Contract Load:** Pipeline loads export definition from Registry (`export_id`).  
3. **Schema Validation:** Validate export schema digest against SRG-001.  
4. **Data Extraction:** Query from Iceberg / RDS using DCON-001 contract filters.  
5. **Transformation:** Optional redaction or aggregation per policy.  
6. **Write:** Write data to S3 export prefix with encryption and checksum manifest.  
7. **Verification:** Generate manifest file (`_SUCCESS`, checksum, record count).  
8. **Delivery:** Create presigned URL or register external table (Snowflake).  
9. **Notify:** Emit lineage and audit events to EventBridge (`lineage-updates`).  

---

## 6. IAM and Security Controls
| Domain | Implementation |
|--------|----------------|
| **Authentication** | GitHub OIDC for deployment; IAM roles for ECS/Lambda. |
| **Authorization** | Least-privilege IAM; ABAC tags for tenant/resource scoping. |
| **Encryption** | KMS-CMK encryption for S3, manifest, and logs. |
| **Secrets** | AWS Secrets Manager for external credentials (e.g., Snowflake). |
| **Audit Logging** | CloudTrail and S3 access logs enabled for all exports. |
| **Compliance** | SOC 2 Type II export control and GDPR Article 32 enforced by GOV-002. |

---

## 7. Observability and SLOs
| Metric | Target | Alert Threshold | Source |
|---------|---------|----------------|---------|
| **Export Success Rate** | ≥ 99 % | < 97 % (rolling 24 h) | CloudWatch |
| **Export Latency** | ≤ 15 min | > 20 min | Step Functions |
| **Manifest Validation Error Rate** | ≤ 0.1 % | ≥ 1 % | ECS logs |
| **Checksum Mismatch** | 0 | > 0 | Lambda validation |
| **Storage Utilization** | ≤ 80 % | ≥ 90 % | S3 metrics |

---

## 8. CI/CD Integration
- **CI (CI/CL-001):** Validate export YAMLs and manifest schemas.  
- **CD (CI/CL-002):** Deploy ECS and Step Functions definitions.  
- **Change Control (CI/CL-003):** CAB approval for new export contracts or destinations.  
- **Rollback:** Automatic rollback on manifest validation or checksum failure.  

---

## 9. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|-----------|
| Export Contracts | SRG-001 | Immutable versioned |
| Export Manifests | DM-003 | 90 days |
| Export Files | LAK-001 | 90 days (default) |
| Export Logs | OBS-001 | 90 days |
| Audit Records | GOV-001 | 7 years |

---

## 10. Acceptance Criteria
1. All export contracts validated and published under SRG-001.  
2. Manifest generation and checksum verification succeed for every export.  
3. SLO targets (latency ≤ 15 min, success ≥ 99 %) met continuously.  
4. No schema drift between export contract and deployed pipeline.  
5. CAB ticket includes SBOM, metrics, lineage snapshot, and checksum manifest.  

---

## 11. Change Log
| Version | Date | Description | Author |
|----------|------|-------------|--------|
| 1.0 | 2025-11-09 | Initial board-ready release validated against REF-001 | Data Platform Lead / Platform SRE |
