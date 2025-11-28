# PRD-001 Neurocipher Platform Vision and Scope

Status: Draft for review  
Owner: Product Management  
Approvers: Architecture Board, Security Engineering  
Last updated: 2025-11-26  
Applies to: Neurocipher Platform (Core, Data Pipeline, AuditHound, Agent Forge, MCP)  
Related: REF-001 Glossary-and-Standards-Catalog, PRD-002 Capabilities and Module Mapping, ARC-001 Platform Context and Boundaries, SEC-001 Threat Model and Mitigation Matrix  

## 1. Purpose

This document defines the vision, target users, core problems, and initial
scope of the Neurocipher platform.

It is the single source of truth for:

- Why Neurocipher exists.
- Which users and environments it serves.
- Which problems it is required to solve in its initial releases.
- Which problems and features are explicitly out of scope for the initial
  platform.

All downstream architecture, implementation, and roadmap documents must be
consistent with this vision and scope.

## 2. Vision

Neurocipher is a continuous cloud security and posture platform that uses
semantic analysis and AI-assisted reasoning to detect and remediate risks in
modern, multi-cloud environments.

The vision is:

> To give small and mid-sized organisations continuous, explainable, and
> affordable cloud security posture and compliance assurance, without
> requiring an in-house security engineering team.

Neurocipher should:

- Monitor cloud environments continuously and automatically.
- Detect misconfigurations, risky patterns, and posture drift.
- Explain risks in clear language that non-specialists can understand.
- Guide or execute safe remediation actions under strong governance.
- Provide structured evidence that can be used to satisfy auditors.

## 3. Target users and segments

### 3.1 Primary segments

The primary target segments are:

- Small and mid-sized organisations using AWS, GCP, and/or Azure, with:
  - Limited in-house security expertise.
  - Compliance obligations (SOC 2, ISO 27001, PCI-DSS, HIPAA, GDPR or similar).
  - Existing use of cloud-native services (compute, databases, storage,
    managed security services).

- Managed service providers (MSPs) and security consultancies that:
  - Manage multiple customer environments.
  - Need repeatable, evidence-based ways to assess posture and compliance.
  - Want to standardise on a tooling platform rather than building bespoke
    scripts for each customer.

### 3.2 Secondary segments

Secondary segments, not targeted in the initial release but compatible with the
architecture, are:

- Larger enterprises that already have detection tools but lack:
  - Strong explanation and prioritisation for non-security stakeholders.
  - Tight coupling between posture data and compliance evidence generation.

- Individual advanced users and prosumers who:
  - Run personal or side-project infrastructure in public cloud.
  - Want automated posture checks and reports, but at a smaller scale.

## 4. Problems to solve

The core problems Neurocipher must address are:

1. **Visibility gaps**  
   - Cloud environments evolve quickly and are often configured through a mix
     of consoles, scripts, and infrastructure as code.
   - Organisations struggle to answer “What does my posture look like right
     now?” without manual audits.

2. **Context-free alerts**  
   - Existing tools generate many alerts but provide insufficient context on:
     - Actual business impact.
     - Which issues matter most.
     - How individual findings relate to compliance obligations.

3. **Remediation friction**  
   - Even when issues are known, remediation is slow due to:
     - Unclear change impact.
     - Lack of safe, repeatable playbooks.
     - Coordination between security, DevOps, and product teams.

4. **Compliance burden**  
   - Proving compliance is time-consuming and reactive.
   - Evidence gathering is often manual and disconnected from day-to-day
     posture monitoring.
   - Audits become annual fire drills rather than continuous assurance.

Neurocipher must provide a platform that:

- Maintains an up-to-date view of cloud posture.
- Links detection events to understandable narratives.
- Bridges the gap from detection to action.
- Provides structured evidence that can be reused for compliance.

## 5. Solution overview

The Neurocipher platform is composed of the following modules:

- **Neurocipher Data Pipeline**  
  - Ingests configuration, audit logs, and security findings from cloud
    providers.
  - Normalises data into a canonical schema.
  - Stores and indexes data for retrieval and analysis.

- **Neurocipher Core (Semantic Engine)**  
  - Uses search, graph relationships, and AI models to:
    - Aggregate risks.
    - Prioritise findings.
    - Generate explanations and remediation suggestions.
  - Exposes posture and risk APIs to other modules.

- **AuditHound (Compliance Module)**  
  - Evaluates compliance against frameworks such as SOC 2, ISO 27001,
    PCI-DSS, GDPR, and HIPAA.
  - Generates plain-language reports and remediation plans.
  - Consumes posture and finding data from Neurocipher as evidence.

- **Agent Forge (Orchestration and Remediation)**  
  - Orchestrates scans and remediation tasks.
  - Executes policy-governed playbooks to fix misconfigurations safely.
  - Provides detailed audit trails of actions taken and approvals.

- **MCP Server (Integration Layer)**  
  - Provides a structured interface for automation agents and external tools
    to interact with Neurocipher.
  - Manages metadata around tasks, decisions, and tool usage.

These modules are formally scoped and mapped in `PRD-002 Capabilities and
Module Mapping`.

## 6. Initial scope

The initial platform scope (v1 and MVP releases) includes:

- Cloud providers:
  - AWS as the primary provider.
  - Design decisions that do not prevent adding GCP and Azure later.

- Posture coverage:
  - A focused set of high-impact misconfiguration classes for AWS, for
    example:
    - Public or overly permissive storage.
    - Risky identity and access configurations.
    - Missing or misconfigured logging in critical areas.

- Compliance coverage:
  - Initial AuditHound focus on:
    - SOC 2 control families most directly tied to cloud security.
    - ISO 27001 Annex A controls related to cloud configuration and logging.
  - Reports that clearly identify:
    - Control status.
    - Required evidence.
    - Remediation tasks.

- Remediation:
  - A set of conservative, well-audited remediation playbooks executed by
    Agent Forge, with:
    - Strong guardrails and approvals.
    - Rollback strategies for misapplied changes.

- Integration:
  - A documented API surface for:
    - Ingesting external evidence or configuration snapshots.
    - Querying posture and findings.
    - Triggering scans and remediation tasks.

## 7. Explicit non-goals for initial releases

The following are explicitly out of scope for the initial platform releases:

- Full-featured SIEM or log management.  
  - Neurocipher will use logs to inform posture and findings but will not aim
    to replace a general-purpose SIEM.

- Network traffic inspection or deep packet inspection.  
  - The platform will reason over metadata and configuration, not raw packet
    flows.

- Full agent-based endpoint security.  
  - The focus is on cloud control planes and managed services, not endpoint
    agents.

- Irreversible, fully autonomous remediation without human oversight.  
  - All remediation will be:
    - Policy-controlled.
    - Observable.
    - Designed with human override and rollback capabilities.

- Support for every possible compliance framework in v1.  
  - Framework support will start with a small set and expand based on demand.

## 8. Success criteria

The platform is considered successful in its initial phase if:

- Users can connect at least one AWS environment and:
  - See a clear, actionable posture overview.
  - Understand the top risks and why they matter.
  - Receive a remediation plan that can be executed through Agent Forge or
    manually.

- AuditHound can:
  - Generate a SOC 2 or ISO 27001 oriented report for the connected
    environment.
  - Show how posture findings map to specific controls.

- The architecture:
  - Scales to multiple tenants with strong isolation.
  - Supports additional cloud providers without major redesign.
  - Provides stable, documented APIs for future integration.

## 9. Constraints

Key constraints for architecture and implementation are:

- Multi-tenant from day one, with strict isolation enforced at the database
  and application layers.
- AWS-native baseline for early infrastructure (as per ADR-001).
- Documentation-first approach:
  - Architecture and contracts must be documented before significant
    implementation.
- Security by design:
  - Threat model and controls (SEC-001..SEC-003) are treated as first-class
    requirements, not afterthoughts.

## 10. Relationship to other documents

- `REF-001` defines terminology and documentation standards used in this PRD.  
- `PRD-002` defines the detailed capabilities and module boundaries between
  Neurocipher and AuditHound.  
- `ARC-001` will provide the system context and high-level architecture that
  realises this vision.  
- `DM-*`, `SEC-*`, and `AI-*` documents provide more detailed specifications of
  data models, controls, and AI behaviour.

Changes to the platform vision or scope must be reflected here and propagated
to dependent documents through the governance process in `GOV-DEC-001`.