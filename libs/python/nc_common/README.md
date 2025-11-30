# nc_common

Shared utilities and common code for the Neurocipher platform.

## Scope and Responsibilities

`nc_common` provides foundational utilities used across all services. This package contains:

- **Configuration management** - Environment variables, settings, feature flags
- **Date/time utilities** - ISO 8601 formatting, timezone handling, UUIDv7 generation
- **Serialization helpers** - JSON encoding/decoding with custom types
- **String utilities** - Formatting, sanitization, validation
- **Retry and backoff** - Exponential backoff, circuit breaker patterns
- **HTTP helpers** - Request/response utilities, error handling
- **File and I/O utilities** - Safe file operations, path handling

### What MUST Live Here

- Pure utility functions with no domain-specific logic
- Configuration and environment variable handling
- Common constants and helper functions
- Retry/backoff mechanisms
- Shared decorators and context managers
- Type converters and serializers
- String manipulation and validation
- Date/time utilities and formatters

### What MUST NOT Live Here

- Domain models (use `nc_models` instead)
- Observability code (use `nc_observability` instead)
- Security primitives (use `nc_security` instead)
- Service-specific business logic
- Database access or ORM code
- API endpoints or handlers

## Architecture and Specifications

This package follows engineering standards from:

- **[REF-001](../../docs/governance/REF-001-Glossary-and-Standards-Catalog.md)** - Glossary and Standards Catalog (naming conventions, coding standards)
- **[REF-002](../../docs/governance/REF-002-Platform-Constants.md)** - Platform Constants (canonical identifiers, environment names)

## Structure

```text
nc_common/
├── src/
│   └── nc_common/
│       ├── __init__.py          # Package exports
│       ├── config.py            # Configuration and settings
│       ├── datetime_utils.py    # Date/time utilities
│       ├── json_utils.py        # JSON serialization helpers
│       ├── string_utils.py      # String manipulation
│       ├── retry.py             # Retry and backoff logic
│       ├── http_utils.py        # HTTP helpers
│       └── constants.py         # Platform constants
├── tests/                       # Unit tests
└── README.md                    # This file
```text

## Usage

```python
from nc_common.config import get_settings
from nc_common.datetime_utils import utc_now, format_iso8601, generate_uuidv7
from nc_common.retry import exponential_backoff
from nc_common.constants import ENVIRONMENT_DEV, ENVIRONMENT_PROD

# Get configuration
settings = get_settings()
log_level = settings.log_level
environment = settings.environment

# Work with dates and UUIDs
now = utc_now()
timestamp = format_iso8601(now)  # "2025-11-30T12:00:00Z"
unique_id = generate_uuidv7()     # "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a"

# Retry with exponential backoff
@exponential_backoff(max_retries=3, initial_wait=1.0)
def fetch_data():
    # Your code here
    pass
```text

## Design Principles

1. **Pure functions**: Utilities should be stateless and side-effect free when possible
2. **Type safety**: All functions have type hints
3. **Error handling**: Clear error messages with appropriate exception types
4. **Documentation**: Comprehensive docstrings with examples
5. **Testing**: High test coverage (≥80%) for all utilities
6. **Minimal dependencies**: Avoid heavy external dependencies

## Configuration Management

The `config` module provides a unified way to manage environment-specific settings:

```python
from nc_common.config import Settings, get_settings

# Define your settings
class AppSettings(Settings):
    api_key: str
    timeout: int = 30
    debug: bool = False

# Load from environment
settings = get_settings(AppSettings)
```text

Environment variables follow the naming pattern:

- `NC_<SERVICE>_<SETTING>` (e.g., `NC_API_TIMEOUT`, `NC_INGEST_BATCH_SIZE`)
- Use environment names: `dev`, `stg`, `prod` (see REF-002)

## Date/Time Utilities

All timestamps use ISO 8601 format with UTC timezone:

```python
from nc_common.datetime_utils import utc_now, format_iso8601, parse_iso8601

# Current UTC time
now = utc_now()

# Format as ISO 8601 string
timestamp = format_iso8601(now)
# Output: "2025-11-30T12:00:00Z"

# Parse ISO 8601 string
dt = parse_iso8601("2025-11-30T12:00:00Z")
```text

## UUIDv7 Generation

Use UUIDv7 for all new identifiers (time-ordered UUIDs):

```python
from nc_common.datetime_utils import generate_uuidv7

# Generate a UUIDv7
id = generate_uuidv7()
# Output: "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a"
```text

## Retry and Backoff

Implement resilient operations with exponential backoff:

```python
from nc_common.retry import exponential_backoff, RetryableError

@exponential_backoff(
    max_retries=5,
    initial_wait=1.0,
    max_wait=30.0,
    backoff_factor=2.0,
    jitter=True
)
def call_external_api():
    # Raises RetryableError on transient failures
    pass
```text

## Testing

Run tests from the repository root:

```bash
# Run all tests
make test

# Run only nc_common tests
pytest libs/python/nc_common/tests/ -v
```text

## Standards Compliance

All code follows:

- PEP 8 style guidelines (via Black, isort, ruff)
- Type hints for all public functions
- Google-style docstrings
- REF-001 naming conventions (snake_case for functions/variables)
- REF-002 constants (use canonical environment names)

See [REF-001](../../docs/governance/REF-001-Glossary-and-Standards-Catalog.md) for complete standards.

## Dependencies

Minimal external dependencies:

- `python-dateutil` - Date/time parsing
- `pydantic-settings` - Configuration management
- Standard library modules (no heavy dependencies)

## Contributing

When adding utilities:

1. Ensure the utility is truly reusable across services
2. Write comprehensive unit tests (≥80% coverage)
3. Include docstrings with examples
4. Add type hints for all parameters and return values
5. Follow the principle of least surprise
6. Document any non-obvious behavior
7. Update this README if adding new modules

## Related Packages

- **nc_models** - Canonical Pydantic models and data contracts
- **nc_observability** - Logging, metrics, tracing
- **nc_security** - Security primitives and validation
