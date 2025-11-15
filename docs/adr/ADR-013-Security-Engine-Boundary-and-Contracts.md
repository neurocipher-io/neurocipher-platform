id: ADR-013
title: Security Engine Boundary and Contracts
owner: Security Engineering
status: Accepted
last_reviewed: 2025-11-10

# ADR-013 Security Engine Boundary and Contracts

## Status
Accepted — 2025-11-10

## Context
The Neurocipher pipeline requires a remediation loop that evaluates findings, issues commands, and records outcomes. The Security Engine handles remediation logic but must remain decoupled so that pipeline services do not depend on its runtime internals. Previous drafts mixed Security Engine details into ingestion and serving specs, creating unclear ownership and governance.

## Decision

1. **Boundary ownership:** Neurocipher core owns the Security Engine contracts (schemas, APIs, IAM roles) and exposes them via the pipeline repository. Implementation of the Security Engine runtime may reside in a separate repository managed by Security Engineering.
2. **Contracts:** All communication uses the event/command schemas registered in `schemas/events/` and the `/v1/security/actions*` API surface described in `openapi.yaml`.
3. **Observability:** Metrics/logs/traces for the integration are required (see OBS-001/OBS-003); action IDs and status IDs must appear in every signal.
4. **Governance:** Changes to the contracts follow DM-005 and SRG-001 processes and require review from both Platform Architecture and Security Engineering.

## Consequences

- Core documentation references the Security Engine only through the defined contracts (architecture diagrams, DCON-001, SRG-001, OBS-00x, openapi.yaml).
- Implementation guides, remediation playbooks, and control catalogs remain under `docs/security-engine/` (or the dedicated repo) and may evolve independently without modifying pipeline internals.
- Partner integrations consume Security Engine functionality exclusively through the documented contracts, eliminating cross-product bleed.

## Acceptance Criteria

- Event and command schemas for the Security Engine are defined under `schemas/events/` and versioned according to DM-005/SRG-001, with compatibility enforced in CI.
- The `/v1/security/actions` and related endpoints in `openapi.yaml` are implemented and are the only HTTP interfaces used by pipeline and partner integrations to interact with the Security Engine.
- Core architecture and data contract docs (DCON-001, SRG-001, OBS-00x, API-00x) reference the Security Engine only through these contracts and do not embed implementation details.
- Observability for the integration (metrics, logs, traces) includes `action_id`, `status_id`, `schema_urn`, and `tenant_id` fields as required by OBS-001/OBS-003.
- Changes to Security Engine contracts are reviewed jointly by Platform Architecture and Security Engineering and recorded either as updates to this ADR or as new ADRs that extend/supersede it.
