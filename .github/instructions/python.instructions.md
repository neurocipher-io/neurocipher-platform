---
description: Python coding standards for Neurocipher platform
applyTo: '**/*.py'
---

# Python Coding Standards

## General Principles

- Follow PEP 8 style guidelines
- Use Black formatter with default settings (88-char lines, 4-space indent)
- Apply isort for import ordering
- Run ruff for linting
- Write type hints for all public functions and methods
- Prefer explicit over implicit behavior

## Code Style

### Formatting

- **Indentation**: 4 spaces (no tabs)
- **Line length**: 88 characters maximum (Black default)
- **Imports**: Organize using isort
  - Standard library imports first
  - Third-party imports second
  - Local application imports last
  - Separate groups with blank lines

### Naming Conventions

- **Variables and functions**: `snake_case`
- **Classes**: `CapitalizedCamelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Private attributes**: Prefix with single underscore `_private_attr`
- **Module names**: Short, all lowercase, use underscores if needed

### Type Hints

Always include type hints for:
- Function parameters
- Function return types
- Class attributes
- Module-level variables

Example:
```python
from typing import Dict, List, Optional

def process_data(items: List[str], config: Optional[Dict[str, str]] = None) -> Dict[str, int]:
    """Process items and return counts."""
    if config is None:
        config = {}
    return {item: len(item) for item in items}
```

## Package Structure

### Shared Libraries (libs/python/)

- `nc_models/`: Canonical Pydantic models
- `nc_common/`: Shared utilities
- `nc_observability/`: Logging, metrics, tracing

### Services Structure

Each service under `services/` should have:
```
service-name/
├── src/
│   └── # Application code
├── tests/
│   ├── fixtures/
│   └── test_*.py
├── pyproject.toml
└── README.md
```

## Testing

### Test Organization

- Place tests in `tests/` directory parallel to `src/`
- Test files must start with `test_` prefix
- Test fixtures go in `tests/fixtures/`
- Use pytest as the testing framework

### Coverage Requirements

- Maintain ≥80% line coverage
- Run tests with: `pytest --cov=src --cov-report=xml --cov-fail-under=80`
- Include both unit and integration tests

### Test Style

```python
import pytest
from src.module import function_to_test

def test_function_happy_path():
    """Test function with valid input."""
    result = function_to_test("valid_input")
    assert result == "expected_output"

def test_function_edge_case():
    """Test function with edge case."""
    with pytest.raises(ValueError):
        function_to_test("")
```

## Error Handling

### Exceptions

- Use specific exception types, never bare `except:`
- Prefer built-in exceptions when appropriate
- Create custom exceptions for domain-specific errors
- Include meaningful error messages

```python
# Bad
try:
    risky_operation()
except:  # Never use bare except
    pass

# Good
try:
    risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise
except IOError as e:
    logger.error(f"I/O error: {e}")
    return None
```

### RFC 7807 Problem Details

For API errors, use RFC 7807 format:
```python
from typing import Dict, Optional

def create_problem_detail(
    type_uri: str,
    title: str,
    status: int,
    detail: Optional[str] = None,
    instance: Optional[str] = None
) -> Dict[str, any]:
    """Create RFC 7807 Problem Details response."""
    problem = {
        "type": type_uri,
        "title": title,
        "status": status,
    }
    if detail:
        problem["detail"] = detail
    if instance:
        problem["instance"] = instance
    return problem
```

## Data Models

### Pydantic Models

- Use Pydantic for data validation and serialization
- Define models in `libs/python/nc_models/`
- Include docstrings and field descriptions

```python
from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID

class SecurityFinding(BaseModel):
    """Represents a security finding."""
    
    id: UUID = Field(..., description="Unique identifier (UUIDv7)")
    severity: str = Field(..., description="Severity level: critical, high, medium, low")
    title: str = Field(..., description="Finding title")
    description: str = Field(..., description="Detailed description")
    created_at: datetime = Field(..., description="Creation timestamp (ISO 8601)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
                "severity": "high",
                "title": "Unencrypted S3 bucket",
                "description": "S3 bucket lacks default encryption",
                "created_at": "2025-11-26T18:00:00Z"
            }
        }
```

## Logging & Observability

### Structured Logging

- Use the `nc_observability` library
- Include context in log messages
- Use appropriate log levels

```python
import logging

logger = logging.getLogger(__name__)

def process_event(event_id: str, event_data: dict) -> None:
    """Process a security event."""
    logger.info(f"Processing event", extra={
        "event_id": event_id,
        "event_type": event_data.get("type")
    })
    
    try:
        # Processing logic
        logger.debug(f"Event processed successfully", extra={"event_id": event_id})
    except Exception as e:
        logger.error(f"Failed to process event", extra={
            "event_id": event_id,
            "error": str(e)
        })
        raise
```

## AWS Lambda Handlers

### Handler Structure

```python
from typing import Dict, Any
import json

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda function handler.
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Response dictionary with statusCode and body
    """
    try:
        # Extract and validate input
        body = json.loads(event.get("body", "{}"))
        
        # Business logic
        result = process_request(body)
        
        # Return success response
        return {
            "statusCode": 200,
            "body": json.dumps(result),
            "headers": {
                "Content-Type": "application/json"
            }
        }
    except ValueError as e:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": str(e)}),
            "headers": {
                "Content-Type": "application/problem+json"
            }
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"}),
            "headers": {
                "Content-Type": "application/problem+json"
            }
        }
```

## Anti-Patterns to Avoid

### Common Mistakes

1. **Mutable default arguments**
```python
# Bad
def append_to_list(item, my_list=[]):
    my_list.append(item)
    return my_list

# Good
def append_to_list(item, my_list=None):
    if my_list is None:
        my_list = []
    my_list.append(item)
    return my_list
```

2. **Broad exception handling**
```python
# Bad
try:
    process_data()
except:  # Too broad
    pass

# Good
try:
    process_data()
except ValueError as e:
    logger.warning(f"Invalid data: {e}")
except KeyError as e:
    logger.error(f"Missing key: {e}")
    raise
```

3. **Global state**
```python
# Bad - avoid global mutable state
cache = {}

def get_data(key):
    if key not in cache:
        cache[key] = fetch_from_db(key)
    return cache[key]

# Good - pass state explicitly or use class
class DataCache:
    def __init__(self):
        self._cache = {}
    
    def get_data(self, key):
        if key not in self._cache:
            self._cache[key] = fetch_from_db(key)
        return self._cache[key]
```

## Security Best Practices

- Never hardcode credentials, API keys, or secrets
- Use AWS Secrets Manager or SSM Parameter Store
- Validate and sanitize all inputs
- Use parameterized queries for database operations
- Apply principle of least privilege for IAM roles
- Log security-relevant events

## Dependencies

- Check dependencies for known vulnerabilities before adding
- Pin dependency versions in `pyproject.toml`
- Use Poetry for dependency management
- Run `make build` to scan dependencies

## Documentation

- Include docstrings for all public functions, classes, and modules
- Use Google-style docstrings
- Document parameters, return values, and exceptions
- Provide usage examples in module docstrings

```python
def calculate_risk_score(findings: List[SecurityFinding]) -> float:
    """Calculate an aggregate risk score from security findings.
    
    The risk score is calculated based on the severity and quantity of findings.
    Critical findings have the highest weight.
    
    Args:
        findings: List of security findings to analyze
        
    Returns:
        Risk score between 0.0 and 100.0
        
    Raises:
        ValueError: If findings list is empty
        
    Example:
        >>> findings = [SecurityFinding(...), SecurityFinding(...)]
        >>> score = calculate_risk_score(findings)
        >>> print(f"Risk score: {score}")
    """
    if not findings:
        raise ValueError("Findings list cannot be empty")
    
    # Implementation
    return 0.0
```
