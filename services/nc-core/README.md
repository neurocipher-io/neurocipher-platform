# nc-core

Neurocipher Core - Semantic engine for cloud security risk reasoning.

## Purpose

Neurocipher Core is the semantic analysis and risk reasoning engine for the Neurocipher platform. It applies LLM-assisted reasoning to prioritize cloud security risks by impact and likelihood, providing human-readable explanations and remediation recommendations.

## Responsibilities

- **Semantic analysis**: Apply LLM reasoning to security findings and posture data
- **Risk prioritization**: Calculate and rank risks by impact and likelihood
- **Explanation generation**: Produce human-readable risk explanations
- **Remediation recommendations**: Suggest actionable remediation options
- **Pattern detection**: Identify risky patterns and posture drift
- **Impact analysis**: Explain security impact in business terms

## Non-goals

- **NOT** responsible for data ingestion (handled by nc-data-pipeline)
- **NOT** responsible for compliance framework modeling (handled by nc-audithound-api)
- **NOT** responsible for remediation execution (handled by nc-agent-forge)
- **NOT** responsible for audit-style compliance reports
- Does not implement compliance gap analysis

## Integration Points

- **Consumes from**: nc-data-pipeline (normalized security findings and posture data)
- **Provides to**: 
  - nc-agent-forge (risk-prioritized findings for remediation)
  - nc-audithound-api (technical posture data for compliance assessment)
  - API consumers (risk scores, explanations, recommendations)

## Structure

```
nc-core/
├── src/nc_core/           # Core semantic engine implementation
│   ├── __init__.py
│   ├── reasoning/         # LLM-based risk reasoning
│   ├── prioritization/    # Risk scoring and prioritization
│   └── explanation/       # Human-readable explanation generation
├── tests/                 # Service-specific tests
│   ├── __init__.py
│   └── fixtures/          # Test fixtures
├── README.md
└── pyproject.toml
```

## Documentation

See architecture documentation for detailed specifications:

- [Architecture Index](../../docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Platform Context](../../docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)
- [Module Mapping](../../docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md)
- [Semantic Engine Architecture](../../docs/architecture/CORE-001-Semantic-Engine-Architecture.md) (planned)

## Development

This service is currently a skeleton. Implementation will follow the specifications in the architecture documents above.
