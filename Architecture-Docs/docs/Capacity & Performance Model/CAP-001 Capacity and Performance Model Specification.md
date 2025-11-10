# Document ID: CAP-001
**Title:** Capacity and Performance Model Specification  
**Status:** Final v1.0  
**Owner:** Platform SRE / Data Platform Lead  
**Applies to:** Neurocipher Core and AuditHound Module Pipelines  
**Last Reviewed:** 2025-11-09  
**References:** ING-001–003, PROC-001–003, DM-001–005, DCON-001, LAK-001, DQ-001, LIN-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the unified capacity-planning and performance-modelling framework for all ingestion, processing, and serving components within the Neurocipher Core platform.  
Ensures predictable scalability, cost efficiency, and performance consistency across workloads through governed SLOs, capacity tiers, and auto-scaling baselines.

---

## 2. Scope
**In scope:**  
- Compute, memory, and storage sizing models for batch (PROC-001), stream (PROC-002), and embedding (PROC-003) pipelines.  
- Baseline and burst capacity thresholds for ECS, Lambda, and Step Functions workloads.  
- Performance monitoring, forecasting, and auto-scaling metrics under **OBS-001–003**.  
- Storage performance standards for S3 Iceberg, RDS, Weaviate, and OpenSearch per **LAK-001** and **DM-003–005**.  

**Out of scope:**  
- Business-tier SLA design (handled under contractual SLO management).  

---

## 3. Capacity Framework
Capacity management is governed through **Performance Tiers**, defining resource profiles and scaling limits per environment (`dev`, `stg`, `prod`).

| Tier | Use Case | ECS vCPU / Memory | Lambda Concurrency | S3 Throughput | RDS IOPS | Notes |
|------|-----------|-------------------|--------------------|---------------|----------|-------|
| **T1** | Development / Testing | 1 vCPU / 2 GB | ≤ 5 | 50 MB/s | 500 | Minimal baseline |
| **T2** | Staging / Pre-prod | 2 vCPU / 4 GB | ≤ 20 | 150 MB/s | 1500 | Mirrors prod config |
| **T3** | Production (steady state) | 4 vCPU / 8 GB | ≤ 100 | 500 MB/s | 6000 | Default scaling floor |
| **T4** | Production (burst / reindex) | 8 vCPU / 16 GB | ≤ 250 | 1 GB/s | 12000 | Short-term burst only |

Capacity tiers are encoded in `cap_config.json` stored under `infrastructure/config/`.

---

## 4. Performance Model Overview
Performance modelling uses empirical telemetry from **OBS-002/003** and synthetic load tests to establish baseline metrics.

| Metric | Target (p95) | Measurement Source | Notes |
|---------|---------------|--------------------|-------|
| **Batch Throughput** | ≥ 100 MB/s | CloudWatch + Prometheus | PROC-001 |
| **Stream Latency** | ≤ 5 min | API Gateway / ECS metrics | PROC-002 |
| **Embedding Upsert** | ≤ 1 s / chunk | Weaviate metrics | PROC-003 |
| **Query Latency** | ≤ 200 ms | OpenSearch / Weaviate | Serving |
| **Pipeline Success Rate** | ≥ 99 % / month | ADOT collector | Platform-wide |
| **Autoscaling Convergence** | ≤ 90 s | CloudWatch + Application Autoscaling | ECS & Lambda |

All metrics roll into the **Performance Dashboard (OBS-003)**, with error-budget tracking per GOV-002 reliability policy.

---

## 5. Architecture
**Pattern:** Multi-layer capacity control integrated with observability and IaC.

| Layer | Component | Standard |
|--------|------------|----------|
| **Measurement** | Prometheus + ADOT collectors | OBS-002 |
| **Forecasting** | AWS Compute Optimizer + CloudWatch Anomaly Detection | GOV-002 |
| **Scaling Control** | Application Auto Scaling + ECS Service Auto Scaling | CI/CL-002 |
| **Storage Tiering** | S3 Intelligent-Tiering, RDS GP3, OpenSearch warm tiers | LAK-001 |
| **CI/CD Validation** | Pre-deploy load-test jobs (GitHub Actions) | CI/CL-001 |

---

## 6. Sizing and Cost Models
1. **Compute:** ECS Fargate vCPU × memory ratio = 1:2 baseline; Lambda cost projection = invocations × duration × memory price.  
2. **Storage:**  
   - S3 Iceberg: 1 TB ≈ $23/mo (standard); ILM 30-day transition to Infrequent Access.  
   - OpenSearch warm node ratio = 1 warm : 4 hot shards.  
   - RDS: GP3 with 3000 IOPS baseline, 1:2 IOPS/GB ratio.  
3. **Data Transfer:** VPC endpoint usage mandatory; egress budget ≤ 5 % of monthly spend.  

All cost simulations maintained in `cap_model.xlsx` and exported nightly to FinOps dashboard via **GOV-002** controls.

---

## 7. IAM and Security Controls
| Domain | Implementation |
|--------|----------------|
| **Authentication** | GitHub OIDC for deploy; runtime IAM roles per ECS/Lambda. |
| **Authorization** | Least-privilege IAM policies; ABAC tagging (`env`, `service`, `team`). |
| **Encryption** | KMS-encrypted volumes and S3 buckets; no unencrypted EBS. |
| **Secrets** | Managed via AWS Secrets Manager; access via SSM Parameter Store. |
| **Audit** | CloudTrail logs for scaling actions; metrics published to `cap_audit` topic. |
| **Compliance** | SOC 2 Type II capacity controls enforced via GOV-002 audit checklist. |

---

## 8. Observability and SLOs
| Metric | Target | Alert Threshold | Source |
|---------|---------|----------------|---------|
| **CPU Utilization** | ≤ 70 % (p95) | ≥ 80 % 5 min | CloudWatch |
| **Memory Utilization** | ≤ 75 % (p95) | ≥ 85 % 5 min | ECS Metrics |
| **Queue Lag** | ≤ 120 s | ≥ 300 s 10 min | SQS |
| **Job Latency (p95)** | ≤ 5 min | ≥ 10 min | Step Functions |
| **Storage IOWait** | ≤ 5 ms | ≥ 10 ms | RDS / EBS metrics |

All alert rules managed in Grafana and AMP as per **OBS-003**; escalations routed via PagerDuty under SRE rotation.

---

## 9. CI/CD Integration
- **CI (CI/CL-001):** Pre-merge load test validation; synthetic benchmarks in staging.  
- **CD (CI/CL-002):** Blue/green deployment with performance bake verification.  
- **Change Control (CI/CL-003):** CAB approval for capacity tier upgrades; metrics evidence attached.  
- **Rollback:** Auto-triggered on SLO breach or cost spike > 20 % baseline.  

---

## 10. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|-----------|
| Capacity Config (`cap_config.json`) | GOV-001 | Versioned in Git; 7-year retention |
| Performance Logs | OBS-001 | 90 days |
| Benchmark Reports | GOV-002 | 1 year archival |
| Cost Models (`cap_model.xlsx`) | FinOps Policy (FIN-001) | 3 years |
| Metrics & Alerts | OBS-003 | Rolling 90 days |

All assets adhere to naming pattern `nc-<env>-cap-<component>` and are KMS-encrypted per environment.

---

## 11. Acceptance Criteria
1. All core pipelines meet target SLOs under Tier T3 load.  
2. Autoscaling reacts within 90 s to sustained utilization > 75 %.  
3. Forecast accuracy within ± 10 % of observed usage for 90-day window.  
4. No SLO breach > 2 % monthly error-budget.  
5. Evidence pack (metrics, benchmarks, cost report) attached to CAB ticket.  

---

## 12. Change Log
| Version | Date | Description | Author |
|----------|------|-------------|--------|
| 1.0 | 2025-11-09 | Initial board-ready release validated against REF-001 standards | Platform SRE / Data Platform Lead |

---

## Appendix A — Example Capacity Config (JSON)
```json
{
  "env": "prod",
  "tiers": {
    "T1": {"vcpu": 1, "memory": 2048, "lambda_concurrency": 5},
    "T2": {"vcpu": 2, "memory": 4096, "lambda_concurrency": 20},
    "T3": {"vcpu": 4, "memory": 8192, "lambda_concurrency": 100},
    "T4": {"vcpu": 8, "memory": 16384, "lambda_concurrency": 250}
  },
  "scaling": {
    "metric": "CPUUtilization",
    "threshold": 70,
    "scale_out_cooldown": 60,
    "scale_in_cooldown": 300
  },
  "cost_baseline_usd": 1250.00
}
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Capacity and Performance Validation

on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * *"  # Nightly run

jobs:
  validate-capacity:
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

      - name: Run Capacity Forecast
        run: |
          python3 scripts/capacity_forecast.py --env prod

      - name: Publish Report
        run: |
          aws s3 cp reports/capacity_forecast.json s3://nc-prod-capacity/reports/
          echo "CAP-001 Capacity validation complete"
```
