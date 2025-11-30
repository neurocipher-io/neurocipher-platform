# nc-data-pipeline

Neurocipher Data Pipeline - Data ingestion, normalization, embedding, and query service.

## Purpose

The Neurocipher Data Pipeline is responsible for continuous ingestion, normalization, and storage of cloud security data. It provides the foundational data layer that powers all other platform modules with normalized security findings and posture data.

## Responsibilities

- **Data ingestion**: Continuously ingest from cloud providers:
  - Configuration and state (AWS Config, GCP Config, Azure equivalents)
  - Audit and event logs (CloudTrail, GCP Audit Logs, Azure Activity Logs)
  - Native security findings (GuardDuty, Security Hub, GCP SCC, Microsoft Defender)
- **Normalization**: Transform and enrich raw data into canonical schemas
- **Data quality**: Validate data completeness and quality
- **PII handling**: Detect and appropriately handle sensitive data
- **Vector embedding**: Generate embeddings for semantic search
- **Query interface**: Provide efficient query and analytics API
- **Storage management**: Manage data lifecycle and retention

## Sub-services

- `svc-ingest-api` - Raw data ingestion from cloud providers
- `svc-normalize` - Transformation and enrichment
- `svc-embed` - Vector embedding workers
- `svc-query-api` - Query and analytics API

## Non-goals

- **NOT** responsible for semantic risk reasoning (handled by nc-core)
- **NOT** responsible for compliance assessment (handled by nc-audithound-api)
- **NOT** responsible for remediation execution (handled by nc-agent-forge)
- Does not perform LLM-based analysis or risk prioritization
- Does not implement compliance framework logic

## Integration Points

- **Consumes from**: 
  - Cloud provider APIs (AWS, GCP, Azure)
  - Native security services (GuardDuty, Security Hub, etc.)
- **Provides to**: 
  - nc-core (normalized findings and posture data)
  - nc-audithound-api (technical evidence)
  - API consumers (query endpoints)

## Structure

```
nc-data-pipeline/
├── src/nc_data_pipeline/     # Service code
│   ├── __init__.py
│   ├── ingest/               # Data ingestion components
│   ├── normalize/            # Normalization and enrichment
│   ├── embed/                # Vector embedding
│   └── query/                # Query API
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
- [Data Pipeline Architecture](../../docs/architecture/ARC-002-Data-Pipeline-Architecture-Blueprint.md)
- [Module Mapping](../../docs/product/PRD-002-Capabilities-and-Module-Mapping-(Neurocipher-vs-AuditHound).md)
- Service-level specs: DPS-ING-001, DPS-NORM-001, DPS-EMB-001, DPS-API-001 (planned)

## Development

This service is currently a skeleton. Implementation will follow the specifications in the architecture documents above.

## Note

Database migrations and schemas remain at repository root until
service implementation begins. See migration-plan.md Phase 4 notes.
