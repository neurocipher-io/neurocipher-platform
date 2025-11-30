# nc-audithound-api

AuditHound API - Compliance assessment and reporting service.

## Purpose

AuditHound is a compliance scanner and reporting tool that helps organizations answer: "Am I compliant with SOC 2, ISO 27001, PCI-DSS, GDPR, HIPAA, or similar frameworks, and what exactly must I do to pass an audit?"

## Responsibilities

- **Compliance framework modeling**: Model and evaluate SOC 2, ISO 27001, PCI-DSS, GDPR, HIPAA frameworks
- **Compliance gap analysis**: Identify gaps between current state and framework requirements
- **Evidence management**: Track and validate evidence completeness and quality
- **Audit reporting**: Generate plain-language compliance reports and remediation guidance
- **Control evaluation**: Assess presence, absence, and maturity of required controls
- **Remediation planning**: Provide step-by-step guidance to achieve or regain certification

## Non-goals

- **NOT** responsible for continuous cloud monitoring (handled by nc-data-pipeline)
- **NOT** responsible for direct cloud resource scanning
- **NOT** responsible for auto-remediation execution (handled by nc-agent-forge)
- **NOT** a cloud security posture management (CSPM) engine
- Does not collect or compute posture findings directly

## Integration Points

- **Consumes from**: 
  - nc-core (technical posture data and findings as evidence)
  - Manual evidence uploads and questionnaires
- **Provides to**: 
  - API consumers (compliance status, gap analysis, audit reports)
  - End users (plain-language remediation guidance)

## Structure

```
nc-audithound-api/
├── src/nc_audithound_api/  # AuditHound API implementation
│   ├── __init__.py
│   ├── frameworks/          # Compliance framework models
│   ├── assessment/          # Gap analysis and control evaluation
│   ├── evidence/            # Evidence management
│   └── reporting/           # Report generation
├── tests/                   # Service-specific tests
│   ├── __init__.py
│   └── fixtures/            # Test fixtures
├── README.md
└── pyproject.toml
```

## Documentation

See architecture documentation for detailed specifications:

- [Architecture Index](../../docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Platform Context](../../docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)
- [Module Mapping](../../docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md)
- [AuditHound Module Overview](../../docs/architecture/AH-001-AuditHound-Module-Overview-and-Use-Cases.md) (planned)
- [AuditHound Architecture](../../docs/architecture/AH-002-AuditHound-Architecture-and-Integration.md) (planned)

## Development

This service is currently a skeleton. Implementation will follow the specifications in the architecture documents above.
