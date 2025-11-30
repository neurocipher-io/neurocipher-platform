# Neurocipher Platform

Enterprise cloud security platform for SMBs.

## Repository Structure

```
neurocipher-platform/
├── docs/                     # Architecture and product documentation
│   ├── governance/           # Standards, glossary, decision governance
│   ├── product/              # PRDs, vision, module mapping
│   ├── architecture/         # Platform and module architecture
│   ├── data-models/          # Schemas, contracts, data governance
│   ├── services/             # Service-level architecture (DPS-*)
│   ├── security-controls/    # Threat models, IAM, network policies
│   ├── ai/                   # Model architecture, guardrails
│   └── observability/        # Logging, metrics, DR, release strategy
├── services/                 # Backend services
│   ├── nc-data-pipeline/     # Data ingestion and processing
│   ├── nc-core/              # Semantic engine for risk reasoning
│   ├── nc-audithound-api/    # Compliance assessment and reporting
│   ├── nc-agent-forge/       # Auto-remediation orchestration
│   └── nc-mcp-server/        # Model Context Protocol integration
├── libs/                     # Shared Python libraries
│   └── python/
│       ├── nc_models/        # Canonical Pydantic models
│       ├── nc_common/        # Shared utilities
│       └── nc_observability/ # Logging, metrics, tracing
├── infra/                    # Infrastructure as Code
│   ├── modules/              # Shared Terraform modules
│   └── aws/                  # AWS environments
├── migrations/               # Database migrations (temporary location)
├── schemas/                  # JSON/Avro schemas (temporary location)
└── .github/                  # CI/CD workflows
```

## Modules

| Module | Purpose | Status |
|--------|---------|--------|
| **Neurocipher Core** | Semantic engine for cloud security risk reasoning | Skeleton |
| **AuditHound** | Compliance assessment and reporting | Skeleton |
| **Agent Forge** | Auto-remediation orchestration | Skeleton |
| **MCP Server** | Model Context Protocol integration | Skeleton |
| **Data Pipeline** | Ingestion, normalization, embedding, query | Skeleton |

Each module has its own README with detailed purpose, responsibilities, and integration points. See the `services/` directory for implementations.

## Quick Start

```bash
make help                    # Show available commands
make db_local_up             # Start local Postgres + Weaviate
make db_local_smoke_test     # Run database smoke tests
```

## Documentation

Start here:

- [Architecture Index](docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Standards Catalog](docs/governance/REF-001-Glossary-and-Standards-Catalog.md)
- [Platform Context](docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)

## Standards

- Documentation format: REF-001
- Service names: REF-002 (`svc-ingest-api`, `svc-normalize`, etc.)
- Identifiers: UUIDv7
- Events: CloudEvents 1.0
- Errors: RFC 7807 Problem Details
