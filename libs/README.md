# Shared Libraries

Shared Python packages for the Neurocipher platform.

## Overview

These packages form the shared backbone for all services, centralizing common concerns to avoid duplication and divergence.

## Packages

| Package             | Purpose                                                           | Status | Documentation                              |
| ------------------- | ----------------------------------------------------------------- | ------ | ------------------------------------------ |
| `nc_models`         | Canonical Pydantic models and data contracts per DCON-001         | Active | [README](python/nc_models/README.md)       |
| `nc_common`         | Shared utilities, configuration, and common code                  | Active | [README](python/nc_common/README.md)       |
| `nc_observability`  | Logging, metrics, tracing per OBS-001                             | Active | [README](python/nc_observability/README.md)|
| `nc_security`       | Security primitives, validation, and audit logging                | Active | [README](python/nc_security/README.md)     |

## Package Responsibilities

### nc_models - Data Contracts

**The single source of truth for shared data models.**

- Pydantic models for domain entities (findings, scans, assets, identities)
- API request/response DTOs
- CloudEvents payload schemas
- Validation rules and business constraints

Links to: [DCON-001](../docs/data-models/DCON-001-Data-Contract-Specification.md), [DM-003](../docs/data-models/DM-003-Physical-Schemas-and-Storage-Map.md), [DM-004](../docs/data-models/DM-004-Event-Schemas-and-Contracts.md), [DM-006](../docs/data-models/DM-006-Event-and-Telemetry-Contract-Catalog.md)

### nc_common - Utilities

**Foundational utilities used across all services.**

- Configuration management and environment handling
- Date/time utilities and UUIDv7 generation
- Serialization helpers (JSON with custom types)
- Retry/backoff mechanisms
- String utilities and validators

Links to: [REF-001](../docs/governance/REF-001-Glossary-and-Standards-Catalog.md), [REF-002](../docs/governance/REF-002-Platform-Constants.md)

### nc_observability - Telemetry

**Standardized logging, metrics, and tracing.**

- Structured logging with correlation IDs
- Prometheus-compatible metrics (RED/USE patterns)
- OpenTelemetry distributed tracing
- AWS X-Ray integration
- Context propagation (W3C traceparent/tracestate)

Links to: [OBS-001](../docs/observability/OBS-001-Observability-Strategy-and-Telemetry-Standards.md), [OBS-002](../docs/observability/OBS-002-Monitoring-Dashboards-and-Tracing.md)

### nc_security - Security

**Security primitives and validation logic.**

- Input validation and sanitization
- Cryptographic utilities (hashing, signing, encryption)
- Secret management (AWS Secrets Manager/Parameter Store)
- JWT validation and authentication helpers
- PII detection and redaction
- Security audit logging

Links to: [SEC-001](../docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md),
[SEC-002](../docs/security-controls/SEC-002-IAM-Policy-and-Trust-Relationship-Map.md),
[SEC-003](../docs/security-controls/SEC-003-Network-Policy-and-Segmentation.md),
[SEC-004](../docs/security-controls/SEC-004-Secrets-and-KMS-Rotation-Playbook.md),
[SEC-005](../docs/security-controls/SEC-005-Multitenancy-Policy.md)

## Usage

Services import from these packages:

```python
# Models and data contracts
from nc_models.finding import SecurityFinding, Severity
from nc_models.events.finding_events import FindingCreatedEvent

# Common utilities
from nc_common.config import get_settings
from nc_common.datetime_utils import utc_now, generate_uuidv7
from nc_common.retry import exponential_backoff

# Observability
from nc_observability.logging import get_logger
from nc_observability.metrics import Counter, Histogram
from nc_observability.tracing import trace_span

# Security
from nc_security.validation import sanitize_input, validate_email
from nc_security.secrets import get_secret
from nc_security.auth import validate_jwt
```text

## Structure

Each package follows a consistent structure:

```text
package_name/
├── src/
│   └── package_name/
│       ├── __init__.py          # Package exports and version
│       └── *.py                 # Module files
├── tests/                       # Unit tests
├── pyproject.toml               # Package metadata and dependencies
└── README.md                    # Package documentation
```text

## Development

### Testing

Run tests for all packages:

```bash
make test
```text

Run tests for a specific package:

```bash
pytest libs/python/nc_models/tests/ -v
pytest libs/python/nc_common/tests/ -v
pytest libs/python/nc_observability/tests/ -v
pytest libs/python/nc_security/tests/ -v
```text

### Linting and Formatting

Format all Python code:

```bash
make fmt
```text

Lint all Python code:

```bash
make lint
```text

## Standards

All packages follow:

- **Naming**: snake_case for packages, modules, functions per [REF-001 §4.2](../docs/governance/REF-001-Glossary-and-Standards-Catalog.md)
- **Models**: Follow [DCON-001](../docs/data-models/DCON-001-Data-Contract-Specification.md) contracts
- **Logging**: Use [OBS-001](../docs/observability/OBS-001-Observability-Strategy-and-Telemetry-Standards.md) required keys
- **Security**: Implement [SEC-001](../docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md) through [SEC-006](../docs/security-controls/SEC-005-Multitenancy-Policy.md) controls
- **Style**: PEP 8 via Black, isort, ruff
- **Type hints**: All public functions
- **Docstrings**: Google-style
- **Testing**: ≥80% coverage

## Design Principles

1. **Single Responsibility**: Each package has a clear, focused purpose
2. **No Circular Dependencies**: Packages form a dependency graph, not a web
3. **Minimal External Dependencies**: Avoid heavy third-party libraries
4. **Backward Compatibility**: Follow semantic versioning
5. **Documentation First**: Comprehensive READMEs and docstrings
6. **Security by Default**: Validate inputs, sanitize outputs, never log secrets

## Dependency Graph

```text
nc_security ────┐
                │
nc_observability ┼──> nc_common
                │
nc_models ──────┘
```text

- `nc_common` has no internal dependencies (foundation)
- `nc_models`, `nc_observability`, `nc_security` may depend on `nc_common`
- Services depend on any/all packages as needed

## Contributing

When contributing to these packages:

1. Read the package-specific README thoroughly
2. Follow the coding standards and design principles
3. Write comprehensive tests (≥80% coverage)
4. Update documentation for any API changes
5. Ensure changes are backward compatible (or bump major version)
6. Link to relevant specifications in docstrings
7. Run `make fmt && make lint && make test` before committing

## Related Documentation

- [GOV-ARCH-001](../docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md) - Architecture Documentation Index
- [REF-001](../docs/governance/REF-001-Glossary-and-Standards-Catalog.md) - Glossary and Standards Catalog
- [Python Instructions](../.github/instructions/python.instructions.md) - Python coding standards
