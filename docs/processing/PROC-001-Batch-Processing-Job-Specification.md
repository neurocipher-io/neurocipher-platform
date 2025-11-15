id: PROC-001
title: Batch Processing Job Specification
owner: Data Platform Lead / Pipeline Engineering
status: Final v1.0
last_reviewed: 2025-11-07

# Document ID: PROC-001
**Title:** Batch Processing Job Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Pipeline Engineering  
**Applies to:** Neurocipher Core Data Pipeline  
**Last Reviewed:** 2025-11-07  
**References:** ING-001–003, DCON-001, DM-001–005, SRG-001, LAK-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the standardized, deterministic, and auditable batch-processing framework used across the Neurocipher Core Pipeline for large-scale data transformations, re-indexing, compaction, and compliance backfills. Ensures reproducibility, observability, and security compliance within governed CI/CD pipelines.

---

## 2. Scope
**In scope:** Nightly and on-demand jobs executing deterministic, idempotent workflows that operate on datasets stored in S3 Iceberg tables, RDS clusters, Weaviate vector stores, or OpenSearch indices.  
**Out of scope:** Near-real-time event handling (PROC-002) and embedding/indexing tasks (PROC-003).

---

## 3. Inputs and Triggers
| Input Type | Description | Source | Validation |
|-------------|--------------|---------|-------------|
| **Manifest File** | S3 URI list or date-range manifest (JSON) | ING-001 raw landing bucket | SHA-256 digest verification + schema validation (SRG-001) |
| **Schema Contract** | JSON schema per DCON-001 | Schema Registry API | Version pinned via digest |
| **Execution Params** | Batch window, shard count, idempotency salt | Parameter Store (SSM) | Change-ticket required |
| **Triggers** | Scheduled cron (Step Functions state machine), manual trigger via CAB-approved change | CloudWatch Events | Audit log stored in RDS metadata table `proc_job_runs` |

---

## 4. Architecture
**Pattern:** Orchestrated fan-out/fan-in model using AWS Step Functions + ECS Fargate workers + SQS queues.  

| Layer | Component | Standard |
|--------|------------|-----------|
| **Orchestration** | AWS Step Functions Standard Workflow | CI/CL-001 approval gates |
| **Workers** | ECS Fargate containers (ECR image signed & scanned) | CI/CL-002 image governance |
| **Queueing** | SQS primary queue + DLQ | OBS-001 telemetry integration |
| **Storage** | S3 Iceberg (`s3://nc-<env>-lake/iceberg/`), RDS (PostgreSQL), Weaviate (`weaviate-<env>`), OpenSearch (`os-<env>`) | LAK-001 layout |
| **Metadata** | DynamoDB table `proc_run_ledger` | DM-003 physical schema |
| **Observability** | ADOT Collector + Prometheus exporter | OBS-002/003 metrics map |

All deployments use environment-prefixed resource names and KMS-encrypted buckets per GOV-002.

---

## 5. Execution Flow
1. **Plan Stage:** Load manifest → validate contract → enumerate shards → record run metadata.  
2. **Stage Stage:** Read raw objects → apply DCON-001 schema → normalize records → write to temporary S3 prefix.  
3. **Process Stage:** Transform, enrich, and deduplicate. Optionally compute embeddings if flag `enable_embeddings=true`.  
4. **Write Stage:** Upsert validated data to target store (Weaviate, OpenSearch, or RDS).  
5. **Verify Stage:** Run contract diff checks, sample row counts, and generate reconciliation report.  
6. **Finalize:** Emit lineage event to `data_lineage` topic → update ledger → publish metrics → close run.

---

## 6. IAM and Security Controls
| Control Domain | Implementation |
|----------------|----------------|
| **Authentication** | GitHub OIDC role for deploy; runtime IAM roles per service (ECS/Lambda/Step Functions) |
| **Authorization** | Least-privilege IAM policies scoped to resource ARNs; ABAC tenant tagging per GOV-001 |
| **Secrets** | AWS Secrets Manager and SSM Parameter Store; KMS CMKs per environment |
| **Data Protection** | S3 encryption at rest (AES-256/KMS); TLS 1.3 in transit; no PII in logs |
| **Auditing** | CloudTrail enabled for API calls; event ID logged in `proc_run_ledger` |
| **Compliance** | Aligned to SOC 2 Type II controls defined in GOV-002 |

---

## 7. Observability and SLOs
| Metric | Target | Source |
|---------|---------|---------|
| Job Success Rate | ≥ 99% monthly | CloudWatch / Prometheus |
| Batch Freshness | Outputs available before next business day | S3 object timestamps |
| Error Budget Burn | ≤ 2% per rolling 30 days | AMP alerts |
| Throughput | ≥ 100 MB/s aggregate | ECS metrics |
| DLQ Depth | 0 | SQS metrics |

All metrics collected via ADOT Collector and surfaced in Grafana dashboards per OBS-002. Alert rules defined in OBS-003.

---

## 8. Failure Handling and Rollback
- **Retry Policy:** Exponential back-off (1 → 5 attempts per stage).  
- **DLQ:** Poison messages with payload sample and `correlation_id`.  
- **Rollback:** S3 versioned data or RDS PITR snapshot via runbook RB-PROC-001.  
- **Audit Trail:** Every retry and rollback logged to DynamoDB ledger.  

---

## 9. CI/CD and Promotion
- **CI (Ref: CI/CL-001):** Lint, unit tests, schema diff, SAST, SBOM validation, signature verification.  
- **CD (Ref: CI/CL-002):** Staged rollout (dev → stg → prod) using GitHub Actions + CodeDeploy blue/green.  
- **Change Control (Ref: CI/CL-003):** CAB approval required for production execution windows; audit evidence attached to change ticket.  

---

## 10. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|------------|
| S3 Iceberg Tables | LAK-001 | Versioned, 7-year retention |
| RDS Metadata | DM-003 | PITR 7 days |
| Weaviate Vectors | DM-004 | RC2 2-year retention |
| OpenSearch Indices | DM-004 | ILM rollover 30 days |
| Contract Registry | SRG-001 | Digest-pinned immutable |
| Lineage Events | LIN-001 | 30-day window |

---

## 11. Acceptance Criteria
1. Full run of a 1-day backfill completes within scheduled window with zero contract violations.  
2. No unacknowledged messages in DLQ after completion.  
3. Ledger entries accurately reflect run status (`SUCCEEDED`/`FAILED`).  
4. All observability dashboards report green post-run.  
5. Evidence pack (SBOM, logs, metrics, CloudTrail event IDs) attached to change ticket.  

---

## 12. Change Log
| Version | Date | Description | Author |
|-----------|-------|--------------|---------|
| 1.0 | 2025-11-07 | Initial board-ready release validated against REF-001 standards | Data Platform Lead |

---

## Appendix A — Step Functions ASL (Simplified)
```json
{
  "Comment": "PROC-001 Batch Orchestration",
  "StartAt": "PlanJob",
  "States": {
    "PlanJob": { "Type": "Task", "Resource": "arn:aws:lambda:plan", "Next": "StageData" },
    "StageData": { "Type": "Task", "Resource": "arn:aws:ecs:stage", "Next": "ProcessData" },
    "ProcessData": { "Type": "Task", "Resource": "arn:aws:ecs:process", "Next": "WriteData" },
    "WriteData": { "Type": "Task", "Resource": "arn:aws:ecs:write", "Next": "VerifyRun" },
    "VerifyRun": { "Type": "Task", "Resource": "arn:aws:lambda:verify", "Next": "FinalizeRun" },
    "FinalizeRun": { "Type": "Task", "Resource": "arn:aws:lambda:finalize", "End": true }
  }
}
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Batch Job Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'proc/batch/**'

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

      - name: Deploy Step Functions
        run: |
          aws stepfunctions update-state-machine             --state-machine-arn arn:aws:states:ca-central-1:${{ secrets.AWS_ACCOUNT_ID }}:stateMachine:proc-001-batch             --definition file://proc-001-state-machine.json

      - name: Register Deployment
        run: |
          echo "PROC-001 deployment complete"
```
