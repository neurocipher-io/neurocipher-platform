# nc-agent-forge

Agent Forge - Auto-remediation orchestration engine.

## Purpose

Agent Forge is the orchestration engine for safe, policy-driven auto-remediation of cloud security issues. It executes remediation playbooks under strict governance, enforcing human-in-the-loop approval requirements and safety limits.

## Responsibilities

- **Remediation orchestration**: Execute auto-remediation playbooks for security issues
- **Policy enforcement**: Apply policy-driven controls for approval requirements and change scope
- **Safety governance**: Enforce maximum change scope per action and safety limits
- **Rollback management**: Implement rollback strategies for failed or unsafe changes
- **Human-in-the-loop**: Manage approval workflows for high-risk changes
- **Audit trail**: Maintain complete audit logs of all remediation actions
- **Playbook execution**: Execute remediation playbooks for common security issues:
  - Tighten overly permissive security groups
  - Lock down public storage buckets
  - Rotate compromised or at-risk keys
  - Disable or quarantine suspicious identities or resources

## Non-goals

- **NOT** responsible for security posture detection (handled by nc-core)
- **NOT** responsible for data ingestion or normalization (handled by nc-data-pipeline)
- **NOT** responsible for compliance assessment (handled by nc-audithound-api)
- Does not perform risk reasoning or prioritization
- Does not decide what to remediate (consumes prioritized findings from nc-core)

## Integration Points

- **Consumes from**: 
  - nc-core (risk-prioritized findings requiring remediation)
  - Policy definitions (approval rules, safety limits)
- **Executes against**: Cloud provider APIs (AWS, GCP, Azure)
- **Provides to**: 
  - Audit systems (complete action audit trail)
  - API consumers (remediation status, execution history)

## Structure

```
nc-agent-forge/
├── src/nc_agent_forge/       # Agent Forge orchestration engine
│   ├── __init__.py
│   ├── orchestration/        # Task orchestration and state machine
│   ├── playbooks/            # Remediation playbook definitions
│   ├── policy/               # Policy enforcement and approval workflows
│   ├── execution/            # Cloud API execution layer
│   └── rollback/             # Rollback and safety mechanisms
├── tests/                    # Service-specific tests
│   ├── __init__.py
│   └── fixtures/             # Test fixtures
├── README.md
└── pyproject.toml
```

## Documentation

See architecture documentation for detailed specifications:

- [Architecture Index](../../docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Platform Context](../../docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)
- [Module Mapping](../../docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md)
- [Agent Forge Architecture](../../docs/architecture/AF-001-Agent-Forge-Orchestration-Engine-Architecture.md) (planned)

## Development

This service is currently a skeleton. Implementation will follow the specifications in the architecture documents above.
