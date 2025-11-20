id: DR-001
title: Neurocipher Disaster Recovery Plan
owner: Platform SRE / Security Engineering
status: Draft v0.1
last_reviewed: 2025-11-09

# DR-001 Neurocipher Disaster Recovery Plan

**References:** GOV-001, GOV-002, LAK-001, ROL-001, OPS-001, RB-LAK-001-A–D, RB-PROC-001, RB-STREAM-001

---

## 1. Purpose
Define the authoritative disaster recovery strategy for the Neurocipher Data Pipeline, aligning Recovery Time Objective (RTO) ≤ 4 hours and Recovery Point Objective (RPO) ≤ 15 minutes across ingest, processing, and serving tiers.

## 2. Activation Criteria
- Region-wide outage impacting ≥ 2 core services for > 15 minutes.  
- Data corruption or loss not solvable via standard runbooks.  
- Security incident requiring environment rebuild.  
Activation requires approval from Platform Director plus Security Engineering lead.

## 3. Recovery Architecture
- **Primary Region:** `us-east-1` (active).  
- **Secondary Region:** `ca-central-1` warm standby with IaC parity (`iac/stacks/`).  
- **Data Stores:**  
- Lakehouse snapshots replicated nightly (`s3://nc-backups-<env>`).  
- Vector indexes exported hourly.  
- RDS and Dynamo PITR enabled.  
- **Control Plane:** GitHub + CI/CD with artifact storage in S3 `/ci/artifacts/`.

### 3.1 RPO/RTO by tier

| Tier              | Target RPO       | Target RTO       | Notes                                      |
|-------------------|------------------|------------------|--------------------------------------------|
| Control plane     | 15 minutes       | 60 minutes       | CI/CD, IaC state, and deployment metadata. |
| Ingest pipeline   | 15 minutes       | 120 minutes      | SQS queues, Lambda, and raw S3 buckets.    |
| Lakehouse         | 60 minutes       | 240 minutes      | As defined in LAK-001; nightly snapshots.  |
| Vector indexes    | 60 minutes       | 240 minutes      | Rebuilt from lakehouse + snapshot exports. |
| Query API         | 15 minutes       | 60 minutes       | Public API entry points and gateways.      |

These RPO/RTO targets mirror the availability and retention entries for ingest, pipeline, and vector search in the Retention & SLO matrix (OBS-001 §5); that matrix is the authoritative reference for target latency, availability, and retention durations elsewhere in the platform documentation.

## 4. Recovery Procedure (Regional Outage)
1. Declare incident, assign Incident Commander, and start log in `ops/incident/<id>.md`.  
2. Freeze deployments; capture last healthy build IDs.  
3. Deploy infra to standby region: `cd iac && terraform workspace select <env>-dr && terraform apply`.  
4. Restore data:  
   - Lakehouse via RB-LAK-001-C and RB-LAK-001-B.  
   - Vector indexes using `python tools/vector_restore.py --snapshot <ts>`.  
   - RDS via PITR (`aws rds restore-db-instance-to-point-in-time`).  
5. Reconfigure routing (Route53/Akamai) to point to standby API endpoints.  
6. Validate end-to-end using smoke tests (`make e2e`) and lift customer traffic gradually (25/50/100%).

## 5. Data Corruption Procedure
1. Identify corrupted scope (table, partition, index).  
2. Isolate by stopping writers and enabling read-only mode.  
3. Restore from snapshot or backup matching RPO target.  
4. Reconcile downstream systems via RB-PROC-001 or RB-STREAM-001.  
5. Document root cause and preventive actions.

## 6. Communications & Evidence
- Update stakeholders every 30 minutes via #status channel and exec email.  
- File incident ticket with timeline, impact, mitigation, and follow-up tasks.  
- Store recovery evidence (commands, outputs, validation screenshots) in `s3://nc-audit-artifacts/<incident>/`.

## 7. Testing & Maintenance
- Conduct full DR exercise twice per year; log results in `docs/dr/DR-001-Disaster-Recovery-Plan.md#testing`.  
- After each infrastructure change, run tabletop validation to ensure IaC parity.  
- Keep runbook references (RB-LAK-001-*, RB-ING-003-*, RB-PROC-001) current.

## 8. References & Dependencies
| Stack / Module | IaC Path | Workspace / Env Alias | DR Dependency |
|----------------|----------|-----------------------|---------------|
| Core Network & Security | `iac/stacks/core/network` | `<env>-core-network` | VPCs, subnets, gateways that must exist before failover applies |
| Data Plane Services | `iac/stacks/core/data-plane` | `<env>-data-plane` | Lambda, Step Functions, Glue, and SQS definitions restored during Step 4 |
| Serving Edge & Routing | `iac/stacks/core/edge` | `<env>-edge` | Route53, CloudFront/Akamai configs toggled in Step 4.5 |
| Observability & Ops | `iac/stacks/core/observability` | `<env>-obs` | Metrics, logs, and dashboards verified in Sections 4 & 6 |
| Backup / DR Support | `iac/stacks/core/dr-support` | `<env>-dr` | Cross-region buckets, backup vaults, and artifact stores required for recovery evidence |

## 9. Revision History
|| Version | Date | Author | Summary |
||---------|------|--------|---------|
|| v0.1 | 2025-11-09 | Platform SRE | Initial DR blueprint aligned with GOV-001 |

## 10. Acceptance Criteria
- DR exercises demonstrate that the RPO/RTO targets by tier in Section 3.1 are met or exceeded and evidence is stored under the audit bucket for each incident or drill.  
- Regional failover and failback procedures (including routing, data restore, and smoke tests) are validated at least twice per year and referenced from ROL-001 and OPS-001.  
- Runbook dependencies (RB-LAK-001-*, RB-ING-003-*, RB-PROC-001, RB-STREAM-001) remain current and are updated alongside DR-001 when data paths change.  
- Communications during DR incidents follow GOV-001/GOV-002 expectations (status cadence, stakeholder updates, and post-incident reviews).  
- DR-001 remains consistent with ADR-010 and related reliability and observability specs (REL-002, OBS-001–003).
