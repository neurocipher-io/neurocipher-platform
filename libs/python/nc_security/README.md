# nc_security

Security primitives and validation utilities for the Neurocipher platform.

## Scope and Responsibilities

`nc_security` provides security-focused utilities and validation logic. This package contains:

- **Input validation and sanitization** - Prevent injection attacks, XSS, etc.
- **Cryptographic utilities** - Hashing, signing, encryption helpers
- **Secret handling** - Safe secret retrieval and management
- **IAM and RBAC helpers** - Role checking, permission validation
- **Request authentication** - Token validation, JWT handling
- **Security headers** - CORS, CSP, security header generation
- **Audit logging** - Security event logging
- **Data classification** - PII detection and handling per DM-006

### What MUST Live Here

- Input validation and sanitization
- Cryptographic functions (hashing, signing, verification)
- Secret retrieval from AWS Secrets Manager/Parameter Store
- JWT validation and decoding
- Security header generation
- IAM policy validation helpers
- PII detection and redaction
- Security audit logging
- Rate limiting and throttling
- Security decorators and middleware

### What MUST NOT Live Here

- Domain models (use `nc_models` instead)
- Business logic
- Observability code (use `nc_observability` instead)
- General utilities (use `nc_common` instead)
- Infrastructure/Terraform code
- Service-specific authentication logic (use this as building blocks)

## Architecture and Specifications

This package implements security controls from:

- **[SEC-001](../../docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md)** - Threat Model and Mitigation Matrix
- **[SEC-002](../../docs/security-controls/SEC-002-IAM-Policy-and-Trust-Relationship-Map.md)** - IAM Policy and Trust Relationship Map
- **[SEC-003](../../docs/security-controls/SEC-003-Network-Policy-and-Segmentation.md)** - Network Policy and Segmentation
- **[SEC-004](../../docs/security-controls/SEC-004-Secrets-and-KMS-Rotation-Playbook.md)** - Secrets and KMS Rotation Playbook
- **[SEC-005](../../docs/security-controls/SEC-005-Multitenancy-Policy.md)** - Multitenancy Policy
- **[DM-006](../../docs/data-models/DM-006-Event-and-Telemetry-Contract-Catalog.md)** - Event and Telemetry Contract Catalog (data classification)

## Structure

```text
nc_security/
├── src/
│   └── nc_security/
│       ├── __init__.py          # Package exports
│       ├── validation.py        # Input validation and sanitization
│       ├── crypto.py            # Cryptographic utilities
│       ├── secrets.py           # Secret management
│       ├── auth.py              # Authentication helpers
│       ├── headers.py           # Security headers
│       ├── audit.py             # Security audit logging
│       ├── pii.py               # PII detection and redaction
│       └── decorators.py        # Security decorators
├── tests/                       # Unit tests
└── README.md                    # This file
```text

## Usage

### Input Validation

```python
from nc_security.validation import (
    sanitize_html,
    validate_email,
    validate_arn,
    sanitize_sql_identifier,
    validate_json_schema
)

# Sanitize user input
clean_input = sanitize_html(user_input)

# Validate formats
if not validate_email(email):
    raise ValueError("Invalid email address")

if not validate_arn(resource_arn):
    raise ValueError("Invalid AWS ARN")

# Sanitize SQL identifiers (prevent SQL injection)
safe_table_name = sanitize_sql_identifier(table_name)
```text

### Cryptographic Utilities

```python
from nc_security.crypto import (
    hash_password,
    verify_password,
    generate_hmac,
    verify_hmac,
    encrypt_field,
    decrypt_field
)

# Password hashing (using bcrypt/argon2)
hashed = hash_password(password)
is_valid = verify_password(password, hashed)

# HMAC signing
signature = generate_hmac(data, secret_key)
is_valid = verify_hmac(data, signature, secret_key)

# Field-level encryption (using AWS KMS)
encrypted = encrypt_field(sensitive_data, kms_key_id)
decrypted = decrypt_field(encrypted, kms_key_id)
```text

### Secret Management

```python
from nc_security.secrets import (
    get_secret,
    get_parameter,
    cache_secret,
    rotate_secret
)

# Retrieve from Secrets Manager (with caching)
db_password = get_secret("nc-dp-dev-db-password")

# Retrieve from Parameter Store
api_key = get_parameter("/nc/dev/api-key")

# Use cached secret (TTL-based caching)
@cache_secret(ttl=3600)
def get_api_credentials():
    return get_secret("api-credentials")
```text

### Authentication

```python
from nc_security.auth import (
    validate_jwt,
    decode_jwt,
    extract_bearer_token,
    validate_cognito_token
)

# Extract and validate JWT from request
token = extract_bearer_token(request.headers)
claims = validate_jwt(token, public_key)

# Validate AWS Cognito token
user_info = validate_cognito_token(
    token,
    user_pool_id="us-east-1_XXXXXXXXX",
    client_id="xxxxxxxxxxxxxxxxxxxxx"
)
```text

### Security Headers

```python
from nc_security.headers import (
    get_security_headers,
    get_cors_headers,
    get_csp_header
)

# Get standard security headers
headers = get_security_headers()
# Returns:
# {
#     "X-Content-Type-Options": "nosniff",
#     "X-Frame-Options": "DENY",
#     "X-XSS-Protection": "1; mode=block",
#     "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
#     "Content-Security-Policy": "default-src 'self'"
# }

# CORS headers for API
cors_headers = get_cors_headers(
    allowed_origins=["https://app.neurocipher.io"],
    allowed_methods=["GET", "POST", "PUT", "DELETE"],
    allowed_headers=["Content-Type", "Authorization"]
)
```text

### PII Detection and Redaction

```python
from nc_security.pii import (
    detect_pii,
    redact_pii,
    classify_data,
    mask_sensitive_fields
)

# Detect PII in text
pii_types = detect_pii(text)
# Returns: ["EMAIL", "SSN", "CREDIT_CARD"]

# Redact PII from logs
safe_text = redact_pii(text, replacement="[REDACTED]")

# Classify data per DM-006
classification = classify_data(data)
# Returns: "public", "internal", "sensitive", or "secret"

# Mask sensitive fields in objects
masked = mask_sensitive_fields(
    data,
    fields=["password", "api_key", "ssn"]
)
```text

### Audit Logging

```python
from nc_security.audit import (
    log_security_event,
    log_access_attempt,
    log_permission_change
)

# Log security events
log_security_event(
    event_type="authentication_failure",
    user_id="user123",
    source_ip="192.168.1.1",
    details={"reason": "invalid_credentials"}
)

# Log access attempts
log_access_attempt(
    resource_arn="arn:aws:s3:::sensitive-bucket",
    action="GetObject",
    user_id="user123",
    allowed=False,
    reason="insufficient_permissions"
)

# Log permission changes
log_permission_change(
    resource_id="role-123",
    change_type="role_updated",
    actor="admin-user",
    before=old_policy,
    after=new_policy
)
```text

### Security Decorators

```python
from nc_security.decorators import (
    require_auth,
    rate_limit,
    audit_access,
    validate_input
)

@require_auth(scopes=["read:findings"])
@rate_limit(max_requests=100, window=60)
@audit_access
def get_findings(user_id: str):
    """Get security findings with authentication, rate limiting, and audit logging."""
    pass

@validate_input(schema=FindingSchema)
def create_finding(data: dict):
    """Create finding with input validation."""
    pass
```text

## Security Best Practices

### Never Hardcode Secrets

```python
# BAD - Never do this!
API_KEY = "sk-1234567890abcdef"
DB_PASSWORD = "mysecretpassword"

# GOOD - Use Secrets Manager
from nc_security.secrets import get_secret

api_key = get_secret("nc-dp-dev-api-key")
db_password = get_secret("nc-dp-dev-db-password")
```text

### Validate All Inputs

```python
from nc_security.validation import sanitize_input, validate_schema

def process_request(data: dict):
    # Validate against schema
    validate_schema(data, FindingSchema)
    
    # Sanitize inputs
    title = sanitize_input(data.get("title"))
    description = sanitize_input(data.get("description"))
```text

### Use Principle of Least Privilege

```python
from nc_security.auth import require_permissions

@require_permissions(["findings:read"])
def list_findings():
    """Only users with findings:read permission can access."""
    pass

@require_permissions(["findings:write", "findings:delete"])
def delete_finding(finding_id: str):
    """Requires both write and delete permissions."""
    pass
```text

## Testing

Run tests from the repository root:

```bash
# Run all tests
make test

# Run only nc_security tests
pytest libs/python/nc_security/tests/ -v
```text

## Standards Compliance

All code follows:

- PEP 8 style guidelines (via Black, isort, ruff)
- Type hints for all public functions
- Google-style docstrings
- OWASP security best practices
- AWS security best practices
- SEC-001 through SEC-006 security controls

See [SEC-001](../../docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md) for threat model and controls.

## Dependencies

External dependencies:

- `cryptography` - Cryptographic primitives
- `boto3` - AWS SDK (Secrets Manager, KMS, Parameter Store)
- `pyjwt` - JWT validation
- `bcrypt` or `argon2-cffi` - Password hashing
- `email-validator` - Email validation
- `bleach` - HTML sanitization

## AWS Integration

### Secrets Manager

```python
from nc_security.secrets import get_secret

# Retrieve secret with automatic retry and caching
secret = get_secret(
    secret_name="nc-dp-dev-db-credentials",
    region="us-east-1"
)
```text

### KMS Encryption

```python
from nc_security.crypto import encrypt_field, decrypt_field

# Encrypt with KMS
encrypted = encrypt_field(
    data="sensitive data",
    kms_key_id="alias/nc-dp-data-dev"
)

# Decrypt with KMS
decrypted = decrypt_field(encrypted, kms_key_id)
```text

### Cognito Integration

```python
from nc_security.auth import validate_cognito_token

# Validate Cognito JWT
claims = validate_cognito_token(
    token=jwt_token,
    user_pool_id=os.environ["COGNITO_USER_POOL_ID"],
    client_id=os.environ["COGNITO_CLIENT_ID"]
)

user_id = claims["sub"]
email = claims["email"]
```text

## Contributing

When adding security features:

1. Follow OWASP security guidelines
2. Never log secrets or sensitive data
3. Use constant-time comparison for secrets
4. Implement proper error handling (don't leak information)
5. Write comprehensive security tests
6. Document security implications
7. Review SEC-001 through SEC-006 for context
8. Test with both valid and malicious inputs

## Related Packages

- **nc_models** - Canonical Pydantic models and data contracts
- **nc_common** - Shared utilities and configuration
- **nc_observability** - Logging, metrics, tracing (for audit logs)
