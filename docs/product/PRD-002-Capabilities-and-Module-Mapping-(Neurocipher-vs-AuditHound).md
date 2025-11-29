id: PRD-002
title: Capabilities and Module Mapping (Neurocipher vs AuditHound)
owner: Product Management
status: Approved for implementation
last_reviewed: 2025-11-25

# PRD-002 Capabilities and Module Mapping (Neurocipher vs AuditHound)

## 1. Purpose

This document defines the canonical roles, capabilities, and boundaries of the
Neurocipher platform and the AuditHound module.

It is the single source of truth for:

- What each module is responsible for.
- What each module must not do.
- How they interact in end-to-end flows.
- How these boundaries inform build order and roadmap.

All future design, implementation, and documentation must align with this
mapping unless explicitly superseded by a new product requirements document.

## 2. Scope

This document covers:

- AuditHound as a compliance scanner and reporting tool.
- Neurocipher as a continuous cloud security and posture engine, including:
  - Neurocipher Data Pipeline for ingestion and normalization.
  - Neurocipher Core for semantic analysis and risk reasoning.
  - Agent Forge for orchestration of remediation tasks.
- The relationship between AuditHound and Neurocipher.
- High-level implications for build order and integration.

This document does not describe:

- Detailed API surfaces (see `openapi.yaml` and per-service specifications).
- Internal service-level architecture for each module (see ARC-*, DPS-*, CORE-* and AF-* documents).
- Low-level remediation playbook content (see Agent Forge specifications).

## 3. References

- `docs/governance/REF-001 Glossary-and-Standards-Catalog.md`
- `docs/System-Architecture-Blueprint.md`
- `docs/security-controls/SEC-001 Threat-Model-and-Mitigation-Matrix.md`
- `docs/adr/ADR-001 AWS-Native-Baseline.md`
- `docs/audithound/AH-001 Module-Overview-and-Use-Cases.md` (when present)
- `docs/core/CORE-001 Semantic-Engine-Architecture.md` (when present)
- `docs/agent-forge/AF-001 Orchestration-Engine-Architecture.md` (when present)

## 4. Canonical Module Roles

### 4.1 AuditHound

#### 4.1.1 Purpose

AuditHound exists strictly as a compliance scanner and reporting tool.

Its primary goal is to answer the question:

> “Am I compliant or close to compliant with SOC 2, ISO 27001, PCI-DSS,
> GDPR, HIPAA, or a similar framework, and what exactly must I do to pass
> an audit?”

#### 4.1.2 Scope

AuditHound:

- Runs on-demand or scheduled compliance assessments against frameworks such as:
  - SOC 2.
  - ISO 27001.
  - PCI-DSS.
  - GDPR.
  - HIPAA.
  - Other frameworks added later as packs.
- Evaluates:
  - Presence and absence of required controls.
  - Policy and process gaps.
  - Evidence completeness and quality.
  - Maturity of practices where a maturity model is defined.
- Produces:
  - Plain-language compliance reports.
  - Framework-specific checklists.
  - Step-by-step remediation guidance to reach or regain certification.

#### 4.1.3 Explicit Non-goals

AuditHound must not:

- Perform continuous monitoring of cloud environments.
- Directly scan cloud resources or security posture.
- Perform or trigger auto-remediation of cloud resources.

AuditHound may:

- Reference technical findings and posture data produced by Neurocipher.
- Embed links or evidence summaries that originate from Neurocipher.

AuditHound does not collect or compute posture findings itself and is not a
cloud security posture management engine.

#### 4.1.4 Outputs

AuditHound outputs include:

- Per-framework compliance status such as SOC 2 CC controls and ISO 27001 Annex A.
- Control-level status with states such as implemented, partially implemented, or missing.
- Evidence inventory and identified gaps.
- Remediation plans with:
  - Task lists.
  - Suggested owners.
  - Suggested sequencing and prioritization.

In summary, AuditHound talks in the auditor’s language and focuses on
framework compliance outcomes.

---

### 4.2 Neurocipher

#### 4.2.1 Purpose

Neurocipher is the continuous cloud security and posture engine for the
platform. It is responsible for understanding the live security state of
customer environments and for driving safe remediation through Agent Forge.

Its primary goal is to answer the question:

> “Is my cloud configured securely right now, where are my risks, and what
> can be fixed safely and automatically?”

#### 4.2.2 Scope

Neurocipher, via the Neurocipher Data Pipeline and Core modules, performs the
following functions:

- Continuously ingests from cloud providers:
  - Configuration and state:
    - AWS Config.
    - GCP Config.
    - Azure equivalents.
  - Audit and event logs:
    - AWS CloudTrail.
    - GCP Audit Logs.
    - Azure Activity Logs.
  - Native security findings:
    - AWS GuardDuty and Security Hub.
    - GCP Security Command Center.
    - Microsoft Defender and equivalents.
- Detects:
  - Misconfigurations and insecure defaults.
  - Risky patterns and posture drift.
  - High-risk access paths and anomalies.
- Applies LLM-assisted reasoning in Neurocipher Core to:
  - Prioritize risks by impact and likelihood.
  - Explain impact in human-readable form.
  - Suggest remediation options.

The Neurocipher Data Pipeline is responsible for ingestion, normalization, and
storage. Neurocipher Core is responsible for semantic analysis, risk
reasoning, and LLM-backed explanations.

#### 4.2.3 Integration with Agent Forge

Together with Agent Forge, Neurocipher:

- Executes auto-remediation playbooks under strict governance, such as:
  - Tightening overly permissive security groups.
  - Locking down public storage buckets.
  - Rotating compromised or at-risk keys.
  - Disabling or quarantining suspicious identities or resources.
- Enforces policy-driven controls around:
  - Approval requirements where human-in-the-loop is mandatory.
  - Maximum change scope per action.
  - Rollback strategies and safety limits.

Neurocipher is the source of truth for posture and threats and is the driver
of safe automated changes via Agent Forge.

#### 4.2.4 Outputs

Neurocipher outputs include:

- Continuous posture and security findings per account, region, and asset.
- Risk scores and prioritization metadata.
- Recommended or executed actions with full audit trails, such as:
  - Suggested remediation when human approval is required.
  - Executed remediation when auto-remediation policies allow.

In summary, Neurocipher talks to the cloud’s reality and coordinates safe
changes to that reality.

---

## 5. Relationship Between AuditHound and Neurocipher

### 5.1 Direction of Dependency

- AuditHound depends on Neurocipher as a read-only provider of technical
  posture and evidence data.
- Neurocipher does not depend on AuditHound to perform posture detection or
  remediation.

Neurocipher’s core posture loop is independent of compliance frameworks and
remains operational whether or not audits are in progress.

### 5.2 Example Interaction

For a given SOC 2 control:

- AuditHound:
  - Interprets the SOC 2 requirement.
  - Evaluates policies, processes, and uploaded evidence.
  - Pulls in relevant Neurocipher findings when helpful, for example:

    > “For SOC 2 CC6.x, these three critical findings from Neurocipher
    > indicate that access control controls are not fully effective.”

- Neurocipher:
  - Monitors configuration, IAM policies, and audit logs.
  - Detects deviations and risks regardless of audit status.
  - Applies LLM reasoning to prioritize and explain risks.
  - Coordinates remediation via Agent Forge when permitted by policy.

### 5.3 Responsibility Boundaries

The ownership of core questions is defined as follows:

- Question: “Is my cloud configured securely right now?”
  - Owner: Neurocipher.
- Question: “Am I compliant with SOC 2, ISO 27001, PCI-DSS or a similar framework today, and what must I fix to pass an audit?”
  - Owner: AuditHound.

AuditHound uses Neurocipher’s posture data as an input to its compliance
reasoning. It is not a substitute for AuditHound’s own framework logic and
does not perform compliance gap analysis itself.

---

## 6. Capability Mapping

The table below summarizes capability ownership and non-goals.

| Capability                                      | AuditHound                        | Neurocipher                                        |
|-------------------------------------------------|-----------------------------------|----------------------------------------------------|
| Continuous configuration ingestion              | Out of scope                      | Primary owner (via Data Pipeline)                  |
| Continuous log and audit ingestion              | Out of scope                      | Primary owner (via Data Pipeline)                  |
| Native cloud finding ingestion                  | Out of scope                      | Primary owner                                      |
| Misconfiguration detection                      | Out of scope                      | Primary owner                                      |
| Posture drift detection                         | Out of scope                      | Primary owner                                      |
| Compliance framework modeling                   | Primary owner                     | Out of scope                                       |
| Compliance gap analysis                         | Primary owner                     | Out of scope                                       |
| Evidence management and completeness checks     | Primary owner                     | Out of scope                                       |
| Plain-language audit-style reports              | Primary owner                     | Technical posture reporting only                   |
| LLM risk prioritization and explanation         | Consumer of Neurocipher outputs   | Primary owner (LLM reasoning in Core)              |
| Auto-remediation playbooks                      | Out of scope                      | Primary owner (implemented and governed via Agent Forge) |
| Human-in-the-loop approval workflows            | Compliance task workflows         | Remediation task workflows                         |

Definitions:

- Primary owner: Module is the system of record and responsible for
  implementation.
- Consumer: Module may read or display data from the owning module but is not
  the system of record.
- Out of scope: Module must not implement this capability under the current
  architecture.
- Technical posture reporting: Technical risk and posture narratives that are
  not framed as audit reports.

---

## 7. Build Order Implications

The boundaries in this document drive the order in which modules are designed
and implemented.

### 7.1 AuditHound Minimum Viable Product

AuditHound minimum viable product can be delivered before full Neurocipher
posture coverage, provided that:

- AuditHound has:
  - A minimal compliance engine driven by configuration snapshots, structured
    questionnaires, or manually supplied evidence.
  - A report generator for plain-language remediation guidance.
- AuditHound does not assume:
  - Real-time posture feeds from Neurocipher in the first release.

In early phases AuditHound may:

- Use static or manually curated inputs.
- Integrate with Neurocipher only for a subset of technical checks.

Over time AuditHound can progressively decorate controls and reports with live
evidence from Neurocipher.

### 7.2 Neurocipher

Neurocipher requires:

- A full data pipeline for continuous ingestion and normalization.
- Detection logic and posture models.
- Embedding and search support for semantic analysis.
- Agent Forge integration for policy-driven remediation.

For customers using AuditHound, Neurocipher is the upgrade path that:

- Provides deep, real-time technical backing for compliance reports.
- Enables continuous posture assurance between audits.
- Unlocks safe auto-remediation of misconfigurations and risks.

---

## 8. Normative Requirements

The following requirements are normative:

- AuditHound must implement compliance framework modeling, compliance gap
  analysis, evidence management, and plain-language audit reports.
- AuditHound must not implement continuous configuration ingestion, log
  ingestion, misconfiguration detection, posture drift detection, or
  auto-remediation.
- Neurocipher must implement continuous ingestion, posture and threat
  detection, semantic risk reasoning, and integration with Agent Forge for
  remediation.
- Neurocipher must not implement compliance framework logic or audit-style
  reports as its primary function.
- Any cross-module integration must preserve the direction of dependency in
  this document, with AuditHound reading posture data from Neurocipher and not
  the reverse.
- Any feature proposal that adds continuous posture capabilities to AuditHound
  or moves compliance logic into Neurocipher must be treated as an
  architectural change and must update this product requirements document and
  the relevant architecture decision records.