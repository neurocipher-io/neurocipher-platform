# Document ID: DQ-001
**Title:** Data Quality Gates Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Governance Engineering  
**Applies to:** Neurocipher Core and AuditHound Module Pipelines  
**Last Reviewed:** 2025-11-09  
**References:** ING-001–003, PROC-001–003, DM-001–005, DCON-001, SRG-001, LAK-001, LIN-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the unified data quality (DQ) control framework for all ingestion, transformation, and serving pipelines within the Neurocipher Core Platform.  
These quality gates ensure reliability, consistency, and compliance through automated contract validation, metric thresholds, and governed CI/CD enforcement.

---

## 2. Scope
**In scope:**  
- Enforcement of schema contracts, semantic validation, duplication, null, and referential integrity checks across all data stages (Raw, Staged, Canonical, Serving).  
- Real-time and batch quality gate integration into **ING-001–003**, **PROC-001–003**, and **DM-001–005** pipelines.  
- Observability of DQ metrics and alerting as defined in **OBS-002/003**.  

**Out of scope:**  
- Human-driven data remediation workflows (managed separately under DataOps procedures).

---

## 3. Quality Gate Framework
Quality gates are declarative YAML policies stored in the `schema-registry/dq/` repository and deployed via CI pipelines. Each gate is evaluated automatically during data movement or promotion.

| Gate ID | Category | Description | Enforcement Stage | Spec Reference |
|----------|-----------|--------------|------------------|----------------|
| **DQ-SCHEMA-001** | Schema Conformance | Validate all payloads against DCON-001 contract | Ingest / Process | SRG-001 |
| **DQ-INTEGRITY-002** | Referential Integrity | Validate primary–foreign key relationships | Process / Write | DM-002 |
| **DQ-UNIQUENESS-003** | Uniqueness | Ensure no duplicate primary identifiers | Stage / Write | DM-003 |
| **DQ-COMPLETENESS-004** | Completeness | Enforce mandatory field presence | Ingest / Stage | DCON-001 |
| **DQ-RANGE-005** | Value Range | Validate numeric and datetime bounds | Process | DM-001 |
| **DQ-DUP-006** | Deduplication | Detect content_hash collisions | Process | PROC-001 |
| **DQ-SEMANTIC-007** | Semantic Rules | Domain-specific logical checks (e.g., IAM role validity) | Process | DM-005 |
| **DQ-RETENTION-008** | Retention Compliance | Ensure retention_class tagging and expiry metadata | Write / Storage | GOV-002 |

---

## 4. Architecture
**Pattern:** Declarative DQ engine integrated into ingestion and processing pipelines with metrics, fail-fast logic, and escalation.

| Layer | Component | Standard |
|--------|------------|----------|
| **Policy Store** | S3 `s3://nc-<env>-dq-policies/` versioned bucket | GOV-002 |
| **Evaluation Engine** | Lambda or ECS job triggered by Step Functions hooks | CI/CL-001 |
| **Rule Registry** | DynamoDB `dq_rules` table with digest and metadata | DM-003 |
| **Results Store** | DynamoDB `dq_results` + S3 for detailed logs | LAK-001 |
| **Observability** | ADOT + Prometheus / AMP dashboards | OBS-002/003 |
| **CI/CD Hooks** | GitHub Actions + pre-deploy quality check jobs | CI/CL-002 |

---

## 5. Execution Flow
1. **Policy Load:** Retrieve gate definitions and schema digests from SRG-001.  
2. **Validation:** Execute configured gates sequentially or in parallel against staged data.  
3. **Metrics Emission:** Publish DQ metrics (`dq_errors_total`, `dq_violation_rate`, `dq_latency_ms`) to Prometheus.  
4. **Decision:**  
   - If critical violation → block pipeline and raise incident via PagerDuty.  
   - If minor violation → flag for review, annotate lineage, and continue.  
5. **Persist:** Write summarized results to DynamoDB; full reports archived to S3.  
6. **Notify:** Emit SNS event for downstream consumers and audit trail entry in RDS.

---

## 6. IAM and Security Controls
| Domain | Implementation |
|---------|----------------|
| **Authentication** | GitHub OIDC deploy role; runtime IAM roles for Step Functions, ECS, and Lambda. |
| **Authorization** | Least-privilege scoped to DQ policy S3 bucket, DynamoDB tables, and CloudWatch metrics. |
| **Secrets** | All connections managed via SSM Parameter Store and AWS Secrets Manager. |
| **Encryption** | S3, DynamoDB, and SNS encrypted with KMS CMKs per environment. |
| **Compliance** | SOC 2 Type II alignment per GOV-002; CloudTrail enabled for all API actions. |

---

## 7. Observability and Metrics
| Metric | Target | Source |
|---------|---------|---------|
| **DQ Violation Rate** | ≤ 0.5 % of total records | Prometheus (`dq_violation_rate`) |
| **DQ Latency (p95)** | ≤ 1 s per 10 000 records | ADOT metrics |
| **Rule Coverage** | 100 % of active data contracts | Registry comparison |
| **Policy Drift** | 0 drift (digest equality) | SRG-001 registry |
| **Alert Response Time** | ≤ 15 min for critical alerts | OBS-003 escalation policy |

Dashboards under Grafana board `DQ-001` display rule performance, coverage, and freshness metrics with deploy markers. Alert thresholds follow **OBS-003 Alert Catalog**.

---

## 8. CI/CD Integration
- **Pre-Commit Hook:** Validates all new schema PRs include DQ YAML definition.  
- **CI (Ref: CI/CL-001):** Run static DQ tests, contract lint, and unit checks.  
- **CD (Ref: CI/CL-002):** Deploy policy bundles to S3 bucket with digest pinning.  
- **Change Control (Ref: CI/CL-003):** CAB approval for critical rule changes; evidence attached to ticket.  
- **Rollbacks:** Triggered automatically when DQ violation rate exceeds SLA for 3 consecutive runs.

---

## 9. Data Governance Alignment
| Asset | Standard | Lifecycle |
|--------|-----------|-----------|
| DQ Policy Definitions | SRG-001 | Immutable, versioned per digest |
| DQ Results | DM-003 | PITR 7 days |
| S3 Logs | LAK-001 | Versioned, 7 years |
| Alerts / Metrics | OBS-001 | 90 days in Prometheus |
| Run Ledgers | DM-003 | Retained 2 years for audit |

All storage resources follow environment prefixing (`nc-<env>-dq-*`) and encryption as per GOV-002.

---

## 10. Acceptance Criteria
1. All pipelines (ING, PROC, DM) execute DQ gates automatically in CI and runtime.  
2. DQ violation rate ≤ 0.5 % across rolling 30 days.  
3. Zero drift between deployed and registry DQ policy digests.  
4. Full observability (metrics, logs, dashboards) verified in Grafana.  
5. Change ticket includes SBOM, metrics, violation summary, and rollback evidence.  

---

## 11. Change Log
| Version | Date | Description | Author |
|----------|-------|-------------|--------|
| 1.0 | 2025-11-09 | Initial board-ready release validated against REF-001 standards | Data Platform Lead |

---

## Appendix A — Example DQ Policy YAML
```yaml
gate_id: DQ-SCHEMA-001
name: Schema Conformance
severity: critical
description: Validate payloads conform to registered schema
target_stage: ingest
schema_ref: urn:nc:schema:user_profile:v3
rules:
  - type: field_presence
    fields: [user_id, email, created_at]
  - type: regex
    field: email
    pattern: '^[^@]+@[^@]+\.[^@]+$'
  - type: range
    field: created_at
    min: '2020-01-01T00:00:00Z'
    max: now()
on_violation: fail
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Data Quality Policy Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'dq/**'

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

      - name: Sync Policies
        run: |
          aws s3 sync dq/ s3://nc-prod-dq-policies/ --delete
          aws dynamodb batch-write-item --request-items file://dq/dq_rules.json

      - name: Register Deployment
        run: echo "DQ-001 Data Quality Policies deployed successfully"
```
