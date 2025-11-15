id: PROC-002
title: Stream Processing Job Specification
owner: Data Platform Lead / Pipeline Engineering
status: Final v1.0
last_reviewed: 2025-11-07

# Document ID: PROC-002
**Title:** Stream Processing Job Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Pipeline Engineering  
**Applies to:** Neurocipher Core Data Pipeline  
**Last Reviewed:** 2025-11-07  
**References:** ING-001–003, DCON-001, DM-001–005, SRG-001, LAK-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the standardized stream-processing framework used for low-latency ingestion, enrichment, and indexing of event-based data within the Neurocipher Core Pipeline. Ensures near-real-time updates with strong governance, observability, and security alignment.

---

## 2. Scope
**In scope:** Continuous processing of webhook, API, or queue-based events through normalized data pipelines with latency SLO ≤ 5 minutes.  
**Out of scope:** Scheduled batch operations (PROC-001) and embedding/indexing (PROC-003).

---

## 3. Inputs and Triggers
| Input Type | Description | Source | Validation |
|-------------|-------------|---------|-------------|
| **Webhook Events** | JSON payloads from authorized external or internal systems | API Gateway / ALB | Contract check via SRG-001 |
| **S3 Event Notifications** | Object-create triggers for incremental loads | S3 EventBridge | Manifest validation |
| **Change Data Capture (CDC)** | DB-level mutations | DMS → EventBridge | Schema registry validation |
| **Trigger** | Continuous | Event-driven | CloudWatch alarm monitoring |

All incoming records must include `{schema_urn, version}` and be validated against DCON-001 before normalization.

---

## 4. Architecture
**Pattern:** Real-time event pipeline with asynchronous fan-out for enrichment and optional embedding.

| Layer | Component | Standard |
|--------|------------|-----------|
| **Ingress** | API Gateway + Lambda or FastAPI behind ALB | ING-001 ingestion endpoint |
| **Queueing** | SQS standard + DLQ | OBS-001 observability baseline |
| **Processing** | ECS Fargate consumers + optional Lambda light processors | CI/CL-002 container governance |
| **Embedding Branch** | Optional async route to PROC-003 | DM-004 vector schema |
| **Storage Targets** | Weaviate (`weaviate-<env>`), OpenSearch (`os-<env>`), RDS (`nc-core-meta`) | LAK-001, DM-003 |
| **Observability** | ADOT Collector + Prometheus / Grafana + AMP | OBS-002, OBS-003 |

---

## 5. Execution Flow
1. **Ingress:** Receive validated event via webhook or message bus.  
2. **Normalize:** Apply contract from SRG-001 and validate per DCON-001.  
3. **Enrich:** Append system metadata (tenant, timestamps, correlation_id).  
4. **Transform:** Map fields to canonical model per DM-001.  
5. **Route:** Branch to embedding pipeline (PROC-003) if applicable.  
6. **Index:** Write to Weaviate and OpenSearch in parallel.  
7. **Acknowledge:** Delete message from queue and update checkpoint.

---

## 6. IAM and Security Controls
| Control Domain | Implementation |
|----------------|----------------|
| **Authentication** | JWT or mTLS on webhooks; signed AWS IAM roles for internal producers |
| **Authorization** | ABAC tagging by tenant; least privilege enforced via scoped policies |
| **Secrets** | Stored in AWS Secrets Manager with rotation; access via ECS task role |
| **Encryption** | TLS 1.3 in transit; AES-256 / KMS at rest |
| **Audit Logging** | Event-level audit trail persisted to DynamoDB `event_audit_log` |
| **Compliance** | Aligned to SOC 2 Type II per GOV-002 |

---

## 7. Observability and SLOs
| Metric | Target | Source |
|---------|---------|---------|
| End-to-Index Latency | ≤ 5 min (p95) | CloudWatch / Prometheus |
| Ingestion Throughput | ≥ 500 events/sec | ECS metrics |
| Error Rate | < 1% 5xx | ALB / API Gateway |
| DLQ Depth | 0 | SQS metrics |
| Embedding Lag | ≤ 10 min | PROC-003 metrics |

Golden signals (latency, traffic, errors, saturation) are visualized via Grafana dashboards. Alert thresholds and escalation defined in OBS-003.

---

## 8. Failure Handling and Backpressure
- **Retries:** Each stage retries 3x with exponential backoff.  
- **DLQ:** Poison messages routed with sample payload and `correlation_id`.  
- **Backpressure:** Autoscaling on SQS depth, oldest message age, or ECS CPU ≥ 80%.  
- **Recovery:** Runbook RB-STREAM-001 provides DLQ reprocessing procedure.  

---

## 9. CI/CD and Promotion
- **CI (CI/CL-001):** Unit and contract tests, linting, schema validation, and SBOM scan.  
- **CD (CI/CL-002):** GitHub Actions → ECS rolling update; digest-only deployments.  
- **Change Control (CI/CL-003):** CAB review for schema or model changes; evidence linked in ServiceNow ticket.  

---

## 10. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|------------|
| Event Queue | OBS-001 | 14-day retention |
| Weaviate Vectors | DM-004 | RC2 2-year retention |
| OpenSearch Indices | DM-004 | ILM rollover 30 days |
| Audit Logs | DM-003 | PITR 7 days |
| Schema Registry | SRG-001 | Immutable |
| Manifests | LAK-001 | 7-year retention |

---

## 11. Acceptance Criteria
1. Stream job maintains p95 latency ≤ 5 min for 99% of records.  
2. DLQ remains empty post-deployment.  
3. Observability dashboards show all metrics green.  
4. Schema registry alignment verified via digest.  
5. Change ticket includes SBOM, logs, and lineage report.  

---

## 12. Change Log
| Version | Date | Description | Author |
|-----------|-------|--------------|---------|
| 1.0 | 2025-11-07 | Initial board-ready release validated against REF-001 standards | Data Platform Lead |

---

## Appendix A — Step Functions ASL (Simplified)
```json
{
  "Comment": "PROC-002 Stream Orchestration",
  "StartAt": "ReceiveEvent",
  "States": {
    "ReceiveEvent": { "Type": "Task", "Resource": "arn:aws:lambda:receive", "Next": "Normalize" },
    "Normalize": { "Type": "Task", "Resource": "arn:aws:lambda:normalize", "Next": "Enrich" },
    "Enrich": { "Type": "Task", "Resource": "arn:aws:lambda:enrich", "Next": "Route" },
    "Route": { "Type": "Choice", "Choices": [
      { "Variable": "$.embed", "BooleanEquals": true, "Next": "Embed" }
    ], "Default": "Index" },
    "Embed": { "Type": "Task", "Resource": "arn:aws:ecs:embed", "Next": "Index" },
    "Index": { "Type": "Task", "Resource": "arn:aws:ecs:index", "End": true }
  }
}
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Stream Job Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'proc/stream/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-oidc-deploy
          aws-region: ca-central-1

      - name: Deploy Stream Processor
        run: |
          aws ecs update-service             --cluster nc-core-stream-cluster             --service proc-002-stream             --force-new-deployment

      - name: Register Deployment
        run: |
          echo "PROC-002 deployment complete"
```
