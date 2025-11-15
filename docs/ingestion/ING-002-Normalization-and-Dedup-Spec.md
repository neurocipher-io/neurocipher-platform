id: ING-002
title: Normalization, Deduplication, and Canonicalization
owner: Data Platform Engineering / Data Engineering
status: Final v1.0
last_reviewed: 2025-11-07

# ING-002 — Normalization, Deduplication, and Canonicalization

**Document ID:** ING-002  
**Title:** Normalization, Deduplication, and Canonicalization  
**Status:** Final v1.0  
**Owner:** Data Platform Engineering / Data Engineering  
**Applies to:** Neurocipher Core Platform (see docs/integrations/)  
**Last Reviewed:** 2025-11-07  
**Classification:** Internal – Platform Architecture  
**References:** DM-001–005, SRG-001, CI/CL-001–003, OBS-001–003, GOV-001–002, ADR-009–011  

---

## 1. Purpose

Define the process for converting heterogeneous raw payloads into canonicalized, validated JSON representations within the data ingestion pipeline.  
This stage enforces schema conformity, deduplicates data, redacts sensitive information, and ensures compatibility for downstream enrichment and analytics.

---

## 2. Scope

**In Scope**  
- Format decoding and data type normalization  
- Mapping raw payloads to canonical schema  
- Deduplication (hash and time-window-based)  
- Validation against Schema Registry (SRG-001)  
- PII redaction and field standardization  
- Emission to clean topic (EventBridge/SNS)  

**Out of Scope**  
- Enrichment and routing logic (ING-003)  
- Data modeling definitions (DM-001–005)  
- Raw ingestion API or batch delivery (ING-001)

---

## 3. Architectural Overview

### 3.1 Pipeline Components

| Component | Description |
|------------|-------------|
| **SQS ingest-raw-queue** | Source of messages from ING-001 stage |
| **ECS Normalizer Task / Lambda Worker** | Consumes raw messages, performs validation + canonicalization |
| **Schema Registry (SRG-001)** | Provides schema compatibility checks |
| **S3 Clean Zone** | Stores validated canonical JSON documents |
| **EventBridge (ingest-clean-topic)** | Publishes canonicalized event notifications |
| **Weaviate / Analytics Lake** | Downstream consumers of canonicalized data (read-only access) |

### 3.2 Flow

```
SQS ingest-raw-queue → ECS Normalizer → Schema Validation → Canonical Mapping
→ Dedup Store → Clean S3 Bucket → EventBridge ingest-clean-topic
```

---

## 4. Data Processing Stages

### 4.1 Source Decoding

- Detect content type (JSON, CSV, Avro, Protobuf, XML, binary).  
- Convert to UTF-8 normalized JSON structure.  
- Log metadata: file size, encoding, source system.

### 4.2 Canonical Mapping

- Field mapping based on DM-001 Canonical Data Model.  
- Auto-apply transformations (timestamp parsing, numeric coercion, field renaming).  
- Inject provenance fields:
  ```json
  {
    "source": "aws:cloudtrail",
    "schema_urn": "com.nc.audit.raw.v1",
    "ingest_time": "2025-11-07T19:23:41Z",
    "commit_sha": "5b6e3f9"
  }
  ```

### 4.3 Deduplication

- **Hash Key:** SHA-256 of normalized payload (excluding volatile fields).  
- **Window:** 24-hour rolling window per tenant and source.  
- **Store:** DynamoDB table `nc-dedup-index` with TTL = 36h.  
- **Actions:**
  - Duplicate found → drop silently with metric increment.  
  - First occurrence → persist hash and continue.

### 4.4 Validation

- Query Schema Registry for `schema_urn_canonical`.  
- Validate JSON fields and data types.  
- Violations trigger DLQ + CloudWatch alert.  
- On success, object written to S3 Clean Zone and published to topic.

### 4.5 Redaction

- Apply regex-based redaction for classified fields (email, phone, IP).  
- Pseudonymize IDs using SHA-256(salt + value).  
- Redaction rules maintained in `obs/redaction-policy.json` (OBS-001).

---

## 5. Storage Model

### 5.1 Clean Zone (S3)

- **Bucket:** `nc-clean-<env>`  
- **Versioning:** Enabled  
- **Encryption:** KMS (AES-256)  
- **Key Pattern:**  
  ```
  ten=<tenant>/src=<source>/dt=<YYYY-MM-DD>/hr=<HH>/clean=<ulid>.json
  ```

### 5.2 Dedup Index (DynamoDB)

| Field | Type | Description |
|--------|------|-------------|
| `hash_key` | String (PK) | SHA-256 of canonical payload |
| `tenant_id` | String | ABAC boundary |
| `source` | String | Source system |
| `first_seen` | ISO-8601 | Timestamp UTC |
| `ttl` | Number | Epoch expiry (36h) |

---

## 6. Eventing and Output

- **Topic:** `ingest-clean-topic` (EventBridge/SNS)  
- **Schema:** `com.nc.clean.event.v1`  
- **Fields:**
  ```json
  {
    "correlation_id": "01JAB4N6F4MFKYX2BJJRTKPR9G",
    "tenant_id": "acme",
    "schema_urn": "com.nc.clean.v1",
    "s3_key": "ten=acme/src=aws/…/clean.json",
    "validated": true,
    "timestamp": "2025-11-07T19:45:00Z"
  }
  ```

---

## 7. Observability and Metrics

- **Tracing:** OpenTelemetry propagation from ING-001 (`traceparent`).  
- **Metrics:**
  - `normalization_duration_seconds`
  - `dedup_rate`
  - `validation_failures_total`
  - `redacted_fields_total`
- **Logging:** Structured JSON, context fields `{tenant_id, schema_urn, correlation_id}`.  
- **Dashboards:**  
  - Normalization throughput  
  - Dedup success rate  
  - Schema violation trends  
  - p95 normalization latency  

### SLOs

| Metric | Target | Response |
|---------|---------|----------|
| Validation Success | ≥ 99% | Alert if < 98% |
| Dedup Accuracy | ≥ 99% | Trigger dedup job audit |
| p95 Latency | ≤ 1.5 s | Ticket if breached |
| Error Rate | < 1% sustained | Rollback deployment |

---

## 8. Security Controls

- All transformations run within VPC with no public egress.  
- IAM roles least-privilege (one role per service).  
- Secrets pulled from AWS Secrets Manager at runtime.  
- PII redaction enforced pre-publication.  
- S3 Clean Zone write access restricted to ECS TaskRole only.  
- Logs scrubbed for sensitive keys.  
- Encryption in transit (TLS 1.3) and at rest (KMS).  

---

## 9. Deployment, Promotion, and Rollback

- **Build:** Dockerized ECS task built via CI/CL-001 pipeline.  
- **Promotion:** Automated `dev → stg → prd` on green metrics.  
- **Rollback:** Auto rollback when validation error rate > 2 % or dedup drift > 5 %.  
- **Infrastructure:** Terraform IaC modules validated under CI/CL-003.  
- **Artifacts:** Stored under `/ci/artifacts/ing-002/<build_id>/manifest.json`.

---

## 10. Governance and Compliance

- **Retention:** Clean Zone = 365 days, Dedup = 36 h TTL.  
- **IAM Review:** Quarterly as per GOV-001.  
- **Schema Freeze:** Only after CI approval + ADR sign-off.  
- **Change Review:** Schema or mapping changes require ADR update + PR approval.  
- **Compliance:** ISO 27001 A.14, CIS AWS Foundations 3.1.  

---

## 11. Runbooks

| ID | Name | Description |
|----|------|-------------|
| RB-ING-002-A | Validation Failure Remediation | Steps to re-queue invalid messages post schema update |
| RB-ING-002-B | Dedup Drift Investigation | Diagnose dedup false-positive or TTL expiry errors |
| RB-ING-002-C | PII Redaction Audit | Verify redaction coverage per policy (OBS-001) |

---

## 12. Acceptance Criteria

- ✅ Schema validation enforced against SRG-001.  
- ✅ Deduplication accuracy ≥ 99 %.  
- ✅ Redaction policy validated.  
- ✅ Dashboards show RED metrics and deploy markers.  
- ✅ CI/CD rollback tested and validated.  

---

## 13. Revision History

| Version | Date | Author | Summary |
|----------|------|---------|----------|
| v1.0 | 2025-11-07 | Data Platform Lead | Initial full release aligned with CI/CL-003 and OBS-002 |

---

**End of Document**
[ING-003 Enrichment, Routing & Persistence](ING-003-Enrichment-Routing-and-Persistence.md)
