# ING-001 — Raw Ingestion Specification

**Document ID:** ING-001  
**Title:** Raw Ingestion Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Engineering / SRE  
**Applies to:** Neurocipher Core Platform and AuditHound module  
**Last Reviewed:** 2025-11-07  
**Classification:** Internal – Platform Architecture  
**References:** CI/CL-001-003, SRG-001, DM-001-005, OBS-001-003, GOV-001-002, ADR-009-011  

---

## 1. Purpose

Define the standardized process and architecture for receiving, validating, and storing raw source data in a secure, durable, and auditable manner before normalization and enrichment.  
The specification ensures consistent handling across ingestion sources and enables traceability from source event to downstream analytical and compliance outputs.

---

## 2. Scope

**In Scope**  
- REST API ingestion endpoints  
- S3 pre-signed upload and batch ingestion  
- EventBridge/SQS event capture and queueing  
- Schema validation (SRG-001)  
- Dead-letter routing and retry logic  
- Observability instrumentation  

**Out of Scope**  
- Normalization and deduplication (ING-002)  
- Enrichment and routing (ING-003)  
- Schema authoring and publication (SRG-001)

---

## 3. Architectural Overview

### 3.1 Components

| Component | Description |
|------------|-------------|
| **API Gateway (AWS)** | Public ingestion entrypoint for authenticated requests |
| **Lambda / Fargate Service** | Validates payloads, extracts metadata, and writes to S3 + SQS |
| **S3 (Raw Zone)** | Primary object storage for immutable raw payloads |
| **SQS Queues** | Reliable delivery to downstream normalization processes |
| **DynamoDB Metadata Table** | Index of ingestion events keyed by correlation_id |
| **EventBridge** | Emits ingestion lifecycle events (accepted, validated, failed) |
| **CloudWatch / X-Ray** | Observability stack with traces, metrics, and alarms |

### 3.2 Flow Diagram

```
Client/API → API Gateway → Ingest Lambda/Fargate → S3 (Raw Zone)
                                            ↓
                                         SQS Queue
                                            ↓
                                       EventBridge (lifecycle)
```

---

## 4. Ingestion Channels

### 4.1 REST API

- **Endpoint:** `POST /v1/ingest/documents`  
- **Authentication:** API Key + Tenant Token (JWT, ABAC)  
- **Headers:**  
  - `X-Tenant-Id`  
  - `X-Schema-URN`  
  - `X-Schema-Version`  
  - `traceparent` (OpenTelemetry)  
- **Payload:** Binary or JSON (≤ 10 MB)  
- **Response:**
  ```json
  {
    "correlation_id": "01JAB3X6W5Z2YP9YH2V6KJ3XKQ",
    "storage_key": "ten=acme/src=aws/dt=2025-11-07/hr=19/ing=01JAB3X6W5Z2YP9YH2V6KJ3XKQ.json",
    "accepted": true
  }
  ```

### 4.2 Pre-Signed Uploads

- **Endpoint:** `POST /v1/ingest/uploads`  
- Returns pre-signed PUT URL for S3 object under path pattern:
  ```
  s3://nc-raw-<env>/ten=<tenant>/src=<source>/yyyy/mm/dd/hh/<ulid>.blob
  ```
- After upload, metadata POST confirms schema details and triggers validation.

### 4.3 Batch Drop Integration

- Partner or automated systems drop files into `s3://nc-ingest-drop-<env>/…`  
- EventBridge rule detects `ObjectCreated` → queues message to `ingest-raw-queue`.

### 4.4 External Pull Connectors

- Scheduled ECS tasks retrieve data from third-party APIs.  
- Rate limited (5 req/sec default) with per-tenant concurrency caps.  
- Raw payloads written to S3 using same path convention.

---

## 5. Data Contract Validation

- Every ingestion payload **must** specify a `schema_urn` and `version`.  
- The validation layer queries the **Schema Registry (SRG-001)** for the canonical contract.  
- Supported formats: JSON Schema 2020-12, Avro 1.11, Protobuf 3, or binary + sidecar JSON.  
- Validation results logged as structured JSON:
  ```json
  { "status": "validated", "schema_urn": "com.nc.audit.event.v1", "violations": [] }
  ```
- On violation:
  - Object written to DLQ with full trace context.
  - Alert triggered via CloudWatch metric filter.

---

## 6. Storage Model

### 6.1 S3 Raw Zone

- **Bucket Naming:** `nc-raw-<env>`  
- **Versioning:** Enabled  
- **Encryption:** AES-256 (KMS-CMK per environment)  
- **Key Format:**
  ```
  ten=<tenant>/src=<source>/dt=<YYYY-MM-DD>/hr=<HH>/ing=<ulid>/part=<n>.<ext>
  ```
- **Object Tags:** `{ tenant, source, schema_urn, version, classification }`

### 6.2 Metadata Index (DynamoDB)

| Field | Type | Notes |
|--------|------|-------|
| `correlation_id` | String (PK) | ULID or UUIDv7 |
| `tenant_id` | String | ABAC boundary |
| `source` | String | Logical system of origin |
| `schema_urn` | String | Validated contract reference |
| `storage_key` | String | Full S3 key |
| `ingest_timestamp` | ISO-8601 | UTC |
| `status` | ENUM | accepted \| validated \| failed |

---

## 7. Queueing and Retry Policy

| Queue | Purpose | Retry | DLQ | Visibility Timeout |
|--------|----------|-------|-----|--------------------|
| `ingest-raw-queue` | Primary pipeline handoff | 5 attempts | `ingest-raw-dlq` | 6× p99 processing time |
| `ingest-error-queue` | Contract violations | none | n/a | n/a |

- Redrive to DLQ after final attempt.  
- SRE alert on `OldestMessageAge > 120 s`.  
- DLQ monitored with CloudWatch Alarm → OpsGenie page.

---

## 8. Observability and Metrics

- **Tracing:** OpenTelemetry (`traceparent` propagation).  
- **Metrics:**
  - `ingest_requests_total`
  - `ingest_failures_total`
  - `ingest_latency_seconds{quantile="p95"}`
  - `s3_write_latency_seconds`
- **Logs:** Structured JSON shipped to CloudWatch Logs `/nc/ingest/raw/<env>`  
- **Dashboards:** CloudWatch + Grafana board “Ingestion Overview”:
  - RED metrics
  - Error rate trend
  - DLQ message backlog
  - Deploy markers from CI/CL pipeline

### SLO Targets
| Metric | Target | Breach Action |
|---------|---------|---------------|
| API availability | 99.9 % | Pager alert |
| p95 latency | ≤ 300 ms | Create ticket |
| End-to-end freshness | ≤ 5 min | Trigger replay workflow |
| Error rate | < 1 % sustained | Rollback if > 2 % |

---

## 9. Security Controls

- **Authentication:** API Gateway JWT Authorizer; per-tenant policy.  
- **Authorization:** ABAC on `tenant_id` and `classification`.  
- **Encryption:**  
  - In transit: TLS 1.3  
  - At rest: KMS-CMK per environment  
- **Secrets Management:** AWS Secrets Manager.  
- **Config Storage:** AWS SSM Parameter Store path `/nc/<env>/ingest/…`.  
- **Audit Logging:** CloudTrail logs every object PUT and Lambda invoke.  
- **Compliance:** Aligned to CIS AWS Foundations 1.5 and ISO 27001 A.12 controls.

---

## 10. Deployment, Promotion, and Rollback

- **CI Validation (CI/CL-001):** Unit + contract tests, SBOM, provenance attestation.  
- **CD Promotion (CI/CL-002):** Blue-green ECS/Lambda deployments.  
- **Rollback Policy (CI/CL-003):** Automatic rollback on SLO breach or DLQ > 1000.  
- **Environment Sequence:** `dev → stg → prd` via gated promotion.  
- **Change Evidence:** Every release stores build manifest and Terraform plan in S3 `/ci/artifacts/<build_id>/`.

---

## 11. Governance & Compliance

- **Data Retention:**  
  - Raw zone – 180 days (immutable)  
  - Metadata – 365 days (minimum)  
- **Access Review:** Quarterly IAM review (GOV-001).  
- **Versioning Control:** Each ingestion component semantically versioned (SemVer).  
- **Operational Ownership:** Data Platform + SRE joint ownership.  
- **Change Control:** All schema or pipeline changes require ADR approval.

---

## 12. Runbooks

| ID | Name | Description |
|----|------|-------------|
| RB-ING-001 | Ingest Backlog Remediation | Step-by-step replay and redrive from DLQ |
| RB-ING-002 | Schema Violation Handling | How to triage failed validation and redeploy registry |
| RB-ING-003 | S3 Event Loss Recovery | Use Dynamo index to re-emit missing EventBridge events |

---

## 13. Acceptance Criteria

- ✅ Schema validation integrated and enforced via SRG-001.  
- ✅ DLQs wired and alarmed.  
- ✅ All metrics visible in dashboard with deploy markers.  
- ✅ CI/CD pipeline fully automated and rollback tested.  
- ✅ Manual board review verified alignment with GOV-001 standards.  

---

## 14. Revision History

| Version | Date | Author | Change Summary |
|----------|------|---------|----------------|
| v1.0 | 2025-11-07 | Data Platform Lead | Initial full release, aligned with CI/CL-003 and OBS-003 |

---

**End of Document**
