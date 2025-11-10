# ADR-012 System Boundary and Orchestrator Placement

**Status:** Accepted  
**Date:** 2025-11-06  
**Version:** 1.0  
**Owner:** Architecture Board  
**Repository:** neurocipher-core  
**Related Documents:** OPS-001, API-002, SRG-001, OBS-001–003, REF-001, ADR-009, ADR-011

---

## 1. Purpose
Establish definitive system boundaries and the orchestration placement model for the Neurocipher platform. Unify automation, coordination, and CI/CD control in a single orchestrator while keeping component ownership clear and isolated.

## 2. Context
Multiple services (ingest, normalize, embed, query, AuditHound scanners) require coordinated workflows, rollouts, and backfills. Prior drafts showed ambiguity in which layer owned orchestration logic and how boundaries mapped to repositories, IAM, and APIs. This ADR fixes the boundary map and standardizes orchestration responsibilities.

## 3. Decision
- **Agent Forge = the orchestration tier** for Neurocipher Core and the AuditHound module.
- Orchestration is **event-driven and CI/CD-controlled**; no business logic lives in the orchestrator.
- **Boundaries are contract-first**: API-002 and SRG-001 govern all interactions.
- **No shared libraries across boundaries**; reuse via contracts and versioned SDKs only.

### 3.1 Component Boundaries

| Component | Description | Deployment Domain | Ownership |
|---|---|---|---|
| **Core Platform (Neurocipher)** | Ingestion, normalization, embeddings, hybrid search, serving | AWS | Platform Eng |
| **AuditHound Module** | CSPM scanning, rules engine, reports | AWS | Security Eng |
| **Agent Forge (Orchestrator)** | Workflow coordination, rollouts, backfills, task routing | AWS | Platform Eng |

All inter-service communication uses **OpenAPI contracts** and **event schemas registered in SRG-001**. No direct DB access across boundaries.

### 3.2 Orchestrator Placement
- **Runtime:** ECS Fargate + Step Functions (workflows), EventBridge (schedules), SQS (queues).
- **Interfaces:**  
  - Calls service APIs via SDKs generated from API-002.  
  - Emits/consumes events per SRG-001 with schema compatibility gates.  
- **State:** Orchestrator stores execution state only (Step Functions, DynamoDB state tables). Domain state remains within service boundaries.

### 3.3 Identity and Access
- GitHub OIDC → env-scoped IAM roles.  
- Least-privilege policies per workflow: invoke:API, publish:SNS/SQS, startExecution:SFN.  
- No cross-account wildcards; each env uses its own role set.

### 3.4 CI/CD Controls
- Pipelines per service (CI/CL-001..003).  
- Orchestrator workflows versioned and promoted like any other service (canary where applicable).  
- Contracts (OpenAPI/events) diff-gated in CI; deploys fail on breaking changes.

## 4. Rationale
Centralizing orchestration improves observability, rollback safety, and auditability without violating service isolation. Contract-first boundaries reduce coupling and enable independent scaling and deploy cadence.

## 5. Consequences
- Feature delivery includes: service change + orchestrator workflow update + contract diffs.  
- Breaking contract changes require coordinated rollouts with deprecation headers (API-002) and event schema migrations (SRG-001).  
- Orchestrator outages should not corrupt domain state; workflows must be idempotent and resumable.

## 6. Architecture Impacts
- **Observability:** Orchestrator emits spans with correlation_id; dashboards per OBS-002 include workflow success rate, queue age, and task retry metrics.  
- **Reliability:** Backoff, DLQs, and replay endpoints exposed per OPS-001; incident handling per REL-002.  
- **Cost:** Orchestrator is governed by COST-001; unit-economics tied to workflow executions.

## 7. Security
- Secrets in AWS Secrets Manager; no secrets in workflow definitions.  
- SigV4/JWT to downstream APIs.  
- IAM Access Analyzer on orchestrator roles; periodic permission review.

## 8. Compliance and Links
- **ADR-011** enforces perf-cost gates on releases that include orchestrator changes.  
- **API-002** and **SRG-001** are the sole sources of truth for contracts.  
- **OPS-001** defines environment isolation and promotion.

## 9. Acceptance Criteria
- Orchestrator code isolated in `agent-forge` repo with no domain logic.  
- All orchestrator calls go through generated SDKs from API-002.  
- Event schemas registered and validated in SRG-001 with compatibility checks in CI.  
- Dashboards and alerts for orchestrator KPIs exist and are green in stg.  
- Runbooks for failed workflows and DLQs documented under `/docs/runbooks/`.