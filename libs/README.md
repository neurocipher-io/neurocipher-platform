# Shared Libraries

Shared Python packages for the Neurocipher platform.

## Packages

| Package | Purpose | Status |
|---------|---------|--------|
| `nc_models` | Canonical Pydantic models per DCON-001 | Placeholder |
| `nc_common` | Shared utilities, config, env handling | Placeholder |
| `nc_observability` | Logging, metrics, tracing per REF-001 §12 | Placeholder |

## Usage

Services import from these packages:
```python
from nc_models.finding import SecurityFinding
from nc_common.config import get_settings
from nc_observability.logging import get_logger
```

## Standards

- Package names use snake_case per REF-001 §4.2
- All models follow DCON-001 contracts
- Logging follows REF-001 §12.1 required keys
