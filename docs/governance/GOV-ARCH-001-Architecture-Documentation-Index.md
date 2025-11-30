# GOV-ARCH-001 Architecture Documentation Index

Status: Draft for review  
Owner: Architecture  
Approvers: Architecture Board, Security Engineering  
Last updated: 2025-11-26  
Applies to: Neurocipher Platform (Core, Data Pipeline, AuditHound, Agent Forge, MCP)  
Related: REF-001 Glossary-and-Standards-Catalog, PRD-001, PRD-002, ARC-001, SEC-001, ADR-001  

## 1. Purpose

This document is the canonical index for all architecture and product
documentation in the Neurocipher platform monorepo.

It exists to:

- Provide a single, stable reference list of documents for architecture,
  product, data, security, AI, and operations.
- Make explicit which documents exist, where they live, and their current
  status.
- Identify gaps where specifications are still missing or planned.
- Give implementation teams a clear map of which documents they must follow.

This index must be kept up to date as documentation is added, renamed, or
superseded.

## 2. Scope

This index covers:

- Platform-level product and architecture documents.
- Module-level architecture for:
  - Neurocipher Core.
  - Neurocipher Data Pipeline.
  - AuditHound.
  - Agent Forge.
  - MCP server.
- Cross-cutting data models and contracts.
- Ingestion and service-level architecture.
- Security controls, AI/ML architecture, and observability/operations.
- Runbooks that are tightly coupled to architectural decisions.

This document does not:

- Duplicate the content of individual specifications.
- Serve as a change log for each document (use document-specific histories).

## 3. Status and tier definitions

### 3.1 Status

The following status values are used in this index:

- Existing: Document exists in the repository and is actively used.
- Draft for review: Document exists but requires review and possible revision.
- Approved for implementation: Document is signed off and should be followed by implementation teams.
- Planned: Document is not yet written and must be created.

Each individual document may carry a more specific status string in its own
header; this index uses the simplified set above to track coverage.

### 3.2 Documentation tiers

Each document is also assigned a tier:

- Tier 1 – Implementation blocking  
  - Must exist and be at least Draft for review before any new major service
    implementation or refactor proceeds.  
- Tier 2 – Integration and interoperability blocking  
  - Must exist before services or modules are integrated or exposed to
    external consumers.  
- Tier 3 – Production readiness blocking  
  - Must exist before the platform is considered ready for external tenants or
    paying customers.  
- Tier 4 – Optimisation and operational maturity  
  - Can be added and refined in parallel with implementation and early
    adoption.

Tiers are used to prioritise documentation work; they do not override the
status of individual documents.

## 4. Document families overview

Document families are organized as follows:

- Governance (`GOV-*`, `REF-*`).
- Product (`PRD-*`, `BETA-*`).
- Architecture (`ARC-*`, module architecture docs).
- Data models and contracts (`DM-*`, `SRG-*`, `DCON-*`).
- Ingestion (`ING-*`).
- Services (`DPS-*` and other service-level docs).
- Security controls (`SEC-*`).
- AI/ML (`AI-*`).
- Observability and operations (`OBS-*`, `CAP-*`, `DR-*`, `ROL-*`, `SVC-*`).
- Runbooks (`*-RUN-*` where tightly linked to architecture).

The following sections enumerate each family with path, status, and tier.

## 5. Governance documentation

| ID           | Title                             | Path                                                                 | Status              | Tier  | Notes                             |
|--------------|-----------------------------------|----------------------------------------------------------------------|---------------------|-------|-----------------------------------|
| REF-001      | Glossary and Standards Catalog    | `docs/governance/REF-001-Glossary-and-Standards-Catalog.md`         | Existing            | 1     | Canonical naming and style rules. |
| REF-002      | Platform Constants                | `docs/governance/REF-002-Platform-Constants.md`                     | Existing            | 1     | Canonical identifiers and constants. |
| GOV-DEC-001  | Decision Governance               | `docs/governance/GOV-DEC-001-Decision-Governance.md`                | Planned             | 2     | Decision and approval process.    |
| GOV-ARCH-001 | Architecture Documentation Index  | `docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md`  | Existing (this doc) | 1     | Index for all architecture docs.  |

## 6. Product documentation

| ID       | Title                                            | Path                                                                                   | Status                      | Tier  | Notes                                                  |
|----------|--------------------------------------------------|----------------------------------------------------------------------------------------|-----------------------------|-------|--------------------------------------------------------|
| PRD-001  | Neurocipher Platform Vision and Scope            | `docs/product/PRD-001-Neurocipher-Platform-Vision-and-Scope.md`                       | Draft for review            | 1     | Platform mission, segments, non-goals.                 |
| PRD-002  | Capabilities and Module Mapping (Neurocipher vs AuditHound) | `docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md` | Approved for implementation | 1     | Canonical roles and boundaries for modules.            |
| PRD-003  | MVP Vertical Slice Specification                 | `docs/product/PRD-003-MVP-Vertical-Slice-Specification.md`                            | Planned                     | 2     | One end-to-end slice from ingest to report.            |
| BETA-001 | Beta Experiment and Feedback Plan                | `docs/product/BETA-001-Beta-Experiment-and-Feedback-Plan.md`                          | Planned                     | 4     | Cohorts, metrics, and evaluation criteria.             |

## 7. Architecture documentation

| ID           | Title                                       | Path                                                                 | Status  | Tier  | Notes                                                      |
|--------------|---------------------------------------------|----------------------------------------------------------------------|---------|-------|------------------------------------------------------------|
| ARC-001      | Platform Context and Boundaries             | `docs/architecture/ARC-001-Platform-Context-and-Boundaries.md`      | Existing| 1     | System context, actors, trust boundaries.                  |
| ARC-002      | Data Pipeline Architecture Blueprint        | `docs/architecture/ARC-002-Data-Pipeline-Architecture-Blueprint.md` | Active  | 1     | nc-data-pipeline subsystem architecture (ingest, normalize, embed, query). |
| CORE-001     | Semantic Engine Architecture                | `docs/architecture/CORE-001-Semantic-Engine-Architecture.md`        | Planned | 2     | Neurocipher Core architecture and interfaces.              |
| AH-001       | AuditHound Module Overview and Use Cases    | `docs/architecture/AH-001-AuditHound-Module-Overview-and-Use-Cases.md` | Planned | 2  | Product and flows for AuditHound.                          |
| AH-002       | AuditHound Architecture and Integration     | `docs/architecture/AH-002-AuditHound-Architecture-and-Integration.md` | Planned | 2  | Technical architecture and dependencies.                   |
| AF-001       | Agent Forge Orchestration Engine Architecture | `docs/architecture/AF-001-Agent-Forge-Orchestration-Engine-Architecture.md` | Planned | 2 | Task orchestration, state machine, safety.                 |
| MCP-ARCH-001 | MCP Server Architecture                     | `docs/architecture/MCP-ARCH-001-MCP-Server-Architecture.md`         | Planned | 3     | High-level architecture for MCP server.                    |
| MCP-TASK-001 | MCP Task Specification                      | `docs/architecture/MCP-TASK-001-Task-Specification.md`              | Planned | 2     | Defines MCP task model and lifecycle.                      |
| MCP-LEDGER-001 | MCP Ledger Specification                  | `docs/architecture/MCP-LEDGER-001-Ledger-Specification.md`          | Planned | 2     | Defines MCP decision and task ledger format.               |
| —            | Data Pipeline Architecture                  | `docs/architecture/Data-Pipeline-Architecture.md`                   | Existing| 1     | Detailed data pipeline architecture.                       |

## 8. Data models and contracts

| ID      | Title                                           | Path                                                                 | Status   | Tier  | Notes                                                  |
|---------|-------------------------------------------------|----------------------------------------------------------------------|----------|-------|--------------------------------------------------------|
| DM-003  | Physical Schemas and Storage Map                | `docs/data-models/DM-003-Physical-Schemas-and-Storage-Map.md`       | Existing | 1     | Postgres and storage layout.                          |
| DM-005  | Governance, Versioning, and Migrations          | `docs/data-models/DM-005-Governance-Versioning-and-Migrations.md`   | Existing | 1     | Data versioning and migration rules.                  |
| DCON-001| Data Contract Specification                     | `docs/data-models/DCON-001-Data-Contract-Specification.md`          | Existing | 1     | Global data contract rules and compatibility policy.  |
| DM-004  | Canonical Asset and Identity Schema             | `docs/data-models/DM-004-Canonical-Asset-and-Identity-Schema.md`    | Planned  | 2     | Cloud-agnostic model for assets and identities.       |
| DM-006  | Event and Telemetry Contract Catalog            | `docs/data-models/DM-006-Event-and-Telemetry-Contract-Catalog.md`   | Planned  | 2     | Catalog of event and command contracts.               |
| SRG-001 | Schema Registry Specification                   | `docs/data-models/SRG-001-Schema-Registry-Specification.md`         | Planned  | 2     | How schemas are stored, versioned, and validated.     |

## 9. Ingestion documentation

| ID      | Title                                           | Path                                                                 | Status   | Tier  | Notes                                             |
|---------|-------------------------------------------------|----------------------------------------------------------------------|----------|-------|---------------------------------------------------|
| ING-001 | Raw Ingestion Spec                              | `docs/ingestion/ING-001-Raw-Ingestion-Spec.md`                       | Planned  | 2     | Entry formats and constraints for raw inputs.     |
| ING-002 | Source Adapters and Connectors                  | `docs/ingestion/ING-002-Source-Adapters-and-Connectors.md`          | Planned  | 2     | Per-source adapter design and mapping.            |
| ING-003 | Enrichment Routing and Persistence              | `docs/ingestion/ING-003-Enrichment-Routing-and-Persistence.md`      | Existing | 2     | Current ingestion and enrichment design.          |

## 10. Service-level architecture

| ID           | Title                                       | Path                                                                 | Status   | Tier  | Notes                                                      |
|--------------|---------------------------------------------|----------------------------------------------------------------------|----------|-------|------------------------------------------------------------|
| DPS-ING-001  | Ingest Service Architecture                 | `docs/services/DPS-ING-001-Ingest-Service-Architecture.md`          | Planned  | 1     | `services/nc-data-pipeline` ingest component.              |
| DPS-NORM-001 | Normalize Service Architecture              | `docs/services/DPS-NORM-001-Normalize-Service-Architecture.md`      | Planned  | 1     | Normalisation and PII/DQ pipeline.                         |
| DPS-EMB-001  | Embed Service Architecture                  | `docs/services/DPS-EMB-001-Embed-Service-Architecture.md`           | Planned  | 2     | Embedding workers and index writes.                        |
| DPS-API-001  | API Service Architecture                    | `docs/services/DPS-API-001-API-Service-Architecture.md`             | Planned  | 1     | FastAPI layer and query endpoints.                         |
| DPS-BATCH-001| Batch and Reindex Service Architecture      | `docs/services/DPS-BATCH-001-Batch-and-Reindex-Service-Architecture.md` | Planned | 2 | Reindex, backfill, and migration jobs.                     |

## 11. Security controls documentation

| ID      | Title                                           | Path                                                                 | Status                      | Tier  | Notes                                           |
|---------|-------------------------------------------------|----------------------------------------------------------------------|-----------------------------|-------|-------------------------------------------------|
| SEC-001 | Threat Model and Mitigation Matrix              | `docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md` | Approved for implementation | 1     | Platform threat model and mitigations.          |
| SEC-002 | IAM Policy and Trust Relationship Map           | `docs/security-controls/SEC-002-IAM-Policy-and-Trust-Relationship-Map.md` | Draft for review       | 1     | IAM roles, policies, and trust relationships.   |
| SEC-003 | Network Policy and Segmentation                 | `docs/security-controls/SEC-003-Network-Policy-and-Segmentation.md` | Draft for review             | 1     | VPC, subnet, and network segmentation rules.    |
| SEC-004 | Audit Logging and Forensics                     | `docs/security-controls/SEC-004-Audit-Logging-and-Forensics.md`     | Planned                     | 2     | Logging design and investigation workflows.     |
| SEC-005 | Supply Chain and CI/CD Security                 | `docs/security-controls/SEC-005-Supply-Chain-and-CICD-Security.md`  | Planned                     | 2     | Dependency, build, and pipeline security.       |
| SEC-006 | Privacy and Data Handling                       | `docs/security-controls/SEC-006-Privacy-and-Data-Handling.md`       | Planned                     | 3     | Data minimisation, retention, and deletion.     |

## 12. AI and ML documentation

| ID      | Title                                           | Path                                                                 | Status   | Tier  | Notes                                               |
|---------|-------------------------------------------------|----------------------------------------------------------------------|----------|-------|-----------------------------------------------------|
| AI-001  | Model Architecture and Routing                  | `docs/ai/AI-001-Model-Architecture-and-Routing.md`                  | Planned  | 2     | Model inventory, routing, and retrieval strategy.   |
| AI-002  | Evaluation, Guardrails, and Safety Framework    | `docs/ai/AI-002-Evaluation-Guardrails-and-Safety-Framework.md`      | Planned  | 3     | Evaluation metrics, safety constraints, and drift.  |

## 13. Observability and operations documentation

| ID        | Title                                         | Path                                                                 | Status           | Tier  | Notes                                                   |
|-----------|-----------------------------------------------|----------------------------------------------------------------------|------------------|-------|---------------------------------------------------------|
| OBS-LOG-001 | Logging and Telemetry Baseline             | `docs/observability/OBS-LOG-001-Logging-and-Telemetry-Baseline.md`  | Draft for review | 2     | Common logging, metrics, and tracing requirements.      |
| CAP-001   | Capacity and Scalability Model                | `docs/observability/CAP-001-Capacity-and-Scalability-Model.md`      | Existing         | 3     | Capacity assumptions, scaling strategy, SLO drivers.    |
| DR-001    | Disaster Recovery and Business Continuity     | `docs/observability/DR-001-Disaster-Recovery-and-Business-Continuity.md` | Planned    | 3     | RPO/RTO, backup strategy, and recovery sequence.       |
| ROL-001   | Rollout and Release Strategy                  | `docs/observability/ROL-001-Rollout-and-Release-Strategy.md`        | Planned          | 3     | Canary, feature flags, and rollback patterns.           |
| SVC-001   | External Service Contracts                    | `docs/observability/SVC-001-External-Service-Contracts.md`          | Planned          | 2     | External API contracts and compatibility guarantees.    |

## 14. Runbooks (architecture-linked)

| ID              | Title                               | Path                                                                 | Status   | Tier  | Notes                                      |
|-----------------|-------------------------------------|----------------------------------------------------------------------|----------|-------|--------------------------------------------|
| MCP-RUN-001     | MCP Server Runbook                  | `docs/runbooks/MCP-RUN-001-MCP-Server-Runbook.md`                   | Planned  | 4     | Operational runbook for MCP server.        |
| PIPELINE-RUN-001| Data Pipeline Runbook               | `docs/runbooks/PIPELINE-RUN-001-Data-Pipeline-Runbook.md`           | Planned  | 4     | Operational runbook for data pipeline.     |
| AF-RUN-001      | Agent Forge Runbook                 | `docs/runbooks/AF-RUN-001-Agent-Forge-Runbook.md`                   | Planned  | 4     | Operational runbook for Agent Forge.       |

## 15. Maintenance and acceptance criteria

This index is considered complete for the current architecture when:

- Every document listed as Planned has either:
  - Been created, or
  - Been explicitly removed from scope in a governance decision (GOV-DEC-001).
- All Existing and Draft for review documents have:
  - A clear owner.
  - A current status in their own header.
  - References back to REF-001 where applicable.
- Implementation teams can:
  - Use this index to locate required specifications without ambiguity.
  - Trace each major architectural decision to a document listed here.

Changes to this index must be made in the same pull requests that add, remove,
or rename architecture documents.