id: ING-003
title: Enrichment, Routing, and Persistence
owner: Data Platform Engineering / Platform SRE / Vector Team
status: Final v1.0
last_reviewed: 2025-11-07

# ING-003 — Enrichment, Routing, and Persistence

**Document ID:** ING-003  
**Title:** Enrichment, Routing, and Persistence  
**Status:** Final v1.0  
**Owner:** Data Platform Engineering / Platform SRE / Vector Team  
**Applies to:** Neurocipher Core Platform (see docs/integrations/)  
**Last Reviewed:** 2025-11-07  
**Classification:** Internal – Platform Architecture  
**References:** DM-001–005, SRG-001, CI/CL-001–003, OBS-001–003, GOV-001–002, ADR-009–011  

---

## 1. Purpose

Define the standardized process for enriching canonical data with reference information, applying computed fields, routing events to their appropriate downstream systems, and ensuring reliable, idempotent persistence into analytical and vector stores.

---

## 2. Scope

**In Scope**  
- Reference data lookups and joins  
- Computed field enrichment and scoring  
- Rule-based routing to sinks (vector store, analytics lake, search index)  
- Idempotent write patterns and retry policies  
- Observability and SLO compliance  
- DR/rollback procedures for sink failures  

**Out of Scope**  
- Upstream ingestion and normalization (ING-001/002)  
- Schema authoring (SRG-001)  
- Data model evolution (DM-005)

---

## 3. Architectural Overview

### 3.1 Pipeline Components

| Component | Description |
|------------|-------------|
| **EventBridge ingest-clean-topic** | Input stream from canonical layer (ING-002) |
| **ECS Enricher Task / Lambda Worker** | Performs lookups, scoring, and routing |
| **Reference Data Cache (DynamoDB + S3)** | Tenant-specific reference data used for enrichment |
| **Vector Store (Weaviate)** | Semantic search index for enriched documents |
| **Analytics Lake (S3 / Iceberg)** | Long-term analytical storage for query and BI workloads |
| **OpenSearch Serverless (optional)** | Real-time search layer for investigative queries |
| **CloudWatch + X-Ray** | Metrics, traces, and alerts across sinks |

### 3.2 Flow Diagram

```
EventBridge ingest-clean-topic
        ↓
     ECS Enricher
   ┌──────────────┬──────────────────────┐
   │              │                      │
 Vector Store   Analytics Lake       Search Index
   │              │                      │
   └─────Observability + Metrics──────────┘
```

---

## 4. Enrichment Stages

### 4.1 Reference Lookups

- Reference sources cached per tenant:
  - `tenant_config` (S3 JSON)
  - `geo_lookup` (GeoIP2 DB, weekly refresh)
  - `taxonomy_map` (DynamoDB table)
- Caches warmed at container startup.
- Lookup failures log warnings but do not halt processing.

### 4.2 Computed Fields

- Derived metrics such as `risk_score`, `severity_level`, or `confidence_index`.  
- Versioned in `/config/compute/functions.json` with checksum validation.  
- Formula example:
  ```json
  {
    "field": "risk_score",
    "function": "(threat_count * 0.6) + (vulnerability_weight * 0.4)",
    "version": "1.0.3"
  }
  ```

### 4.3 PII Minimization

- Remove or hash personally identifiable fields prior to external persistence.  
- Enforced policy per OBS-001 redaction catalog.  
- Vector embeddings exclude any classified fields.
- The PII classification table in `docs/governance/REF-001-Glossary-and-Standards-Catalog.md §8` and DQ-001 masking rules determine what constitutes P1/P2 content; Macie/regex scans drive the detection hooks that trigger hashing or rejection.

### 4.4 Schema Validation

- Validate enriched payloads against downstream schema `schema_urn_enriched` via SRG-001.  
- Reject and route to DLQ on schema mismatch.

---

## 5. Routing and Persistence

| Destination | Service | Purpose | Write Pattern |
|--------------|----------|----------|----------------|
| **Vector Store** | Weaviate | Semantic storage for cognitive search | `objects.create` with tenant tagging |
| **Analytics Lake** | S3 / Iceberg | Analytical queries and BI integration | Append-only Iceberg commit |
| **Search Index (optional)** | OpenSearch Serverless | Real-time investigative search | Bulk upsert via API |
| **DLQ** | SQS | Sink failure isolation | Dead-letter storage for reprocessing |

### 5.1 Idempotency

- **Key:** `correlation_id` or content digest  
- **Rule:** Upsert if exists, else insert  
- **Guarantee:** At-least-once semantics; downstream must handle idempotency tokens

### 5.2 Transactional Integrity

- Lake writes wrapped in Iceberg transactions with commit manifest.  
- Failures emit rollback event to EventBridge `lake-rollback-topic`.

### 5.3 Ordering

- Maintain partial ordering by tenant + event timestamp.  
- Late arrivals accepted within 15-minute window; watermark persisted to DynamoDB.

---

## 6. Failure Handling

| Failure Type | Handling | Recovery Path |
|---------------|-----------|----------------|
| Reference Lookup Failure | Log + continue with defaults | Daily retry refresh |
| Schema Violation | Route to DLQ + alert | Manual replay post fix |
| Sink Timeout | Retry (3× exponential backoff) | Circuit breaker if > threshold |
| Vector Write Conflict | Upsert by digest | Auto-resolve with last write wins |
| Iceberg Commit Failure | Emit rollback event | DR procedure per ROL-001 |

---

## 7. Observability

- **Tracing:** OpenTelemetry across all sinks (`traceparent`, `span_id`).  
- **Metrics:**
  - `enrichment_duration_seconds`
  - `vector_write_latency_seconds`
  - `lake_commit_latency_seconds`
  - `routing_failures_total`
  - `slo_breach_events_total`
- **Dashboards:**  
  - End-to-end throughput  
  - Sink latency comparison  
  - DLQ size trend  
  - Error budget consumption  
- **SLO Targets**

| Metric | Target | Breach Action |
|---------|---------|---------------|
| End-to-end success rate | ≥ 99.5 % | Pager alert |
| p95 vector write latency | ≤ 200 ms | Ticket creation |
| p95 lake commit latency | ≤ 2 s | Auto-scale ECS task |
| Enrichment error rate | < 1 % | Rollback deployment |

---

## 8. Security Controls

- **IAM Separation:** Dedicated roles per sink with minimal permissions.  
- **Network Isolation:** All services within private subnets; NAT egress disabled.  
- **Encryption:** TLS 1.3 in transit; KMS CMK per bucket and Weaviate collection.  
- **Secrets Management:** AWS Secrets Manager; rotated quarterly.  
- **Access Control:** ABAC by tenant tag at object and metric level.  
- **Audit Trail:** CloudTrail + S3 Access Logs retained 365 days.  

---

## 9. Deployment, Promotion, and Rollback

- **Build:** Docker image with versioned configuration checksum.  
- **Promotion:** CI/CD through `dev → stg → prd`, subject to SLO verification.  
- **Rollback:** Triggered if error rate > 2 % sustained for 10 minutes.  
- **Feature Flags:** Managed via AWS AppConfig for routing toggles.  
- **Evidence Pack:** Stored in `/ci/artifacts/ing-003/<build_id>/evidence.json`.  

---

## 10. Governance and Compliance

- **Retention:**  
  - Vector data = 365 days (extendable)  
  - Lake data = 730 days (Iceberg table versioning)  
- **Access Review:** Quarterly IAM audits (GOV-001).  
- **Change Approval:** ADR updates for routing or schema changes.  
- **Compliance:** ISO 27001 A.14, SOC 2 Type II Data Retention.  
- **Operational Ownership:** Shared between Data Platform and SRE.  

---

## 11. Runbooks

| ID | Name | Description |
|----|------|-------------|
| RB-ING-003-A | Sink Failure Recovery | Steps for replaying failed writes from DLQ |
| RB-ING-003-B | Iceberg Commit Rollback | Manual rollback of failed Iceberg commits |
| RB-ING-003-C | Vector Store Sync Audit | Procedure to reconcile vector store vs lake |
| RB-ING-003-D | Reference Data Refresh | Process for rotating and validating cached data |

---

## 12. Acceptance Criteria

- ✅ All enriched payloads validate against SRG-001 schemas.  
- ✅ Idempotent writes confirmed via replay tests.  
- ✅ SLOs within thresholds across all sinks.  
- ✅ Rollback tested under simulated sink failure.  
- ✅ Audit and compliance artifacts available in CI evidence pack.  

---

## 13. Revision History

| Version | Date | Author | Summary |
|----------|------|---------|----------|
| v1.0 | 2025-11-07 | Data Platform Lead | Initial full release aligned with CI/CL-003 and OBS-003 |

---

**End of Document**
