# nc_models

Canonical Pydantic models and data contracts for the Neurocipher platform.

## Scope and Responsibilities

`nc_models` is the **single source of truth** for shared data models across all services. This package contains:

- **Pydantic models** representing core domain entities (findings, scans, assets, identities, tickets, etc.)
- **Data transfer objects (DTOs)** for API requests and responses
- **Event payload schemas** that implement CloudEvents 1.0 contracts
- **Validation rules** and business constraints
- **Schema metadata** and versioning information

### What MUST Live Here

- All Pydantic models shared by 2+ services
- Domain entities from the canonical data model (see DCON-001)
- CloudEvents payload schemas (see DM-004, DM-006)
- API request/response models that cross service boundaries
- Shared enums, constants, and type definitions
- Field validators and custom types

### What MUST NOT Live Here

- Service-specific business logic
- Database models or ORM mappings
- API route handlers or controllers
- Service configuration
- Observability or logging code
- Security primitives (use `nc_security` instead)
- Utility functions (use `nc_common` instead)

## Architecture and Specifications

This package implements data contracts specified in:

- **[DCON-001](../../docs/data-models/DCON-001-Data-Contract-Specification.md)** - Data Contract Specification (normative framework for schemas, versioning, compatibility)
- **[DM-003](../../docs/data-models/DM-003-Physical-Schemas-and-Storage-Map.md)** - Physical Schemas and Storage Map
- **[DM-004](../../docs/data-models/DM-004-Event-Schemas-and-Contracts.md)** - Event Schemas and Contracts (CloudEvents structure)
- **[DM-006](../../docs/data-models/DM-006-Event-and-Telemetry-Contract-Catalog.md)** - Event and Telemetry Contract Catalog

## Structure

```text
nc_models/
├── src/
│   └── nc_models/
│       ├── __init__.py          # Package exports
│       ├── finding.py           # Security finding models
│       ├── scan.py              # Scan models
│       ├── asset.py             # Cloud asset models
│       ├── identity.py          # Identity and IAM models
│       ├── ticket.py            # Ticket/issue models
│       ├── events/              # CloudEvents payload schemas
│       │   ├── __init__.py
│       │   ├── finding_events.py
│       │   └── scan_events.py
│       └── common/              # Shared types and validators
│           ├── __init__.py
│           ├── types.py         # Custom field types
│           └── validators.py   # Shared validators
├── tests/                       # Unit tests
└── README.md                    # This file
```text

## Usage

```python
from nc_models.finding import SecurityFinding, Severity
from nc_models.events.finding_events import FindingCreatedEvent
from nc_models.common.types import UUIDv7

# Create a finding
finding = SecurityFinding(
    id=UUIDv7(),
    severity=Severity.HIGH,
    title="Unencrypted S3 bucket",
    description="S3 bucket lacks default encryption",
    resource_id="arn:aws:s3:::my-bucket"
)

# Create an event
event = FindingCreatedEvent(
    data=finding
)
```text

## Design Principles

1. **Immutability**: Models should be immutable where possible (use `frozen=True`)
2. **Validation**: Always validate inputs using Pydantic validators
3. **Documentation**: Every field must have a description
4. **Examples**: Provide realistic examples in `Config.json_schema_extra`
5. **Versioning**: Follow semantic versioning for breaking changes
6. **Compatibility**: Maintain backward compatibility per DCON-001 rules

## Testing

Run tests from the repository root:

```bash
# Run all tests
make test

# Run only nc_models tests
pytest libs/python/nc_models/tests/ -v
```text

## Standards Compliance

All models follow:

- PEP 8 style guidelines (via Black, isort, ruff)
- Type hints for all fields
- Google-style docstrings
- CloudEvents 1.0 envelope structure (for event payloads)
- RFC 7807 Problem Details (for error responses)
- ISO 8601 timestamps with Z suffix
- UUIDv7 for identifiers

See [REF-001](../../docs/governance/REF-001-Glossary-and-Standards-Catalog.md) for complete standards catalog.

## Dependencies

Minimal external dependencies:

- `pydantic` (>=2.0) - Data validation and serialization
- `python-dateutil` - Date/time handling
- `typing-extensions` - Backported type hints

## Contributing

When adding new models:

1. Place in appropriate module (finding.py, scan.py, etc.)
2. Include comprehensive docstrings and field descriptions
3. Add validation rules for business constraints
4. Provide realistic examples
5. Add unit tests with ≥80% coverage
6. Update this README if adding new modules
7. Ensure changes follow DCON-001 compatibility rules

## Related Packages

- **nc_common** - Shared utilities and configuration
- **nc_observability** - Logging, metrics, tracing
- **nc_security** - Security primitives and validation
