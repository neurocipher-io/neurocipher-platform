id: API-Error-Catalog
title: API Error Catalog
owner: Platform
status: Final v1.0
last_reviewed: 2025-11-20

API-Error-Catalog

## Purpose

Establish a single namespace for the Neurocipher API error codes, capture their HTTP semantics, retry guidance, and provide an RFC 7807-friendly payload template so every client, SDK, and gateway speaks the same language.

## References

- REF-001 Documentation Standard
- API-001 Edge and Gateway Architecture
- API-002 Service Contracts and Versioning
- docs/openapi.yaml
- SEC-005 Multitenancy policy

## Problem details envelope

Every error response uses RFC 7807 problem details plus the shared `ErrorResponse` envelope from `openapi.yaml`. The `type` field follows `https://api.neurocipher.io/errors/<CODE>` and documents the authoritative code, the `title` mirrors the code name, `status` matches the HTTP status, `detail` gives a human-friendly explanation, and `instance` tracks the request (for example `urn:nc:error:ingest-event:01H9Z4...`). The `error` object repeats the code, carries `message`, includes the required `correlation_id` ULID, and exposes `details` for domain hints such as `field`, `resource_id`, `retry_after_seconds`, or the offending `tenant_id`. Tenant identifier enforcement works per SEC-005.

## Catalog

| Code | HTTP status | Retryable? | Problem type | Notes |
|---|---|---|---|---|
| `INVALID_REQUEST` | 400 | No | `https://api.neurocipher.io/errors/INVALID_REQUEST` | Schema validation, missing or invalid fields, or malformed Tenant-Id/Idempotency headers. Include `details.field`. |
| `UNAUTHENTICATED` | 401 | No | `https://api.neurocipher.io/errors/UNAUTHENTICATED` | Missing, expired, or malformed JWT/SigV4 credentials. |
| `UNAUTHORIZED` | 403 | No | `https://api.neurocipher.io/errors/UNAUTHORIZED` | Valid credentials lacking scopes, tenant access, or policy approvals. |
| `RESOURCE_NOT_FOUND` | 404 | No | `https://api.neurocipher.io/errors/RESOURCE_NOT_FOUND` | Resource does not exist for the tenant. Include `details.resource_id` and `details.tenant_id`. |
| `CONFLICT` | 409 | No | `https://api.neurocipher.io/errors/CONFLICT` | Concurrent writes, duplicate keys, or state mismatch when mutation cannot be applied. Include `details.resource_id`. |
| `UNPROCESSABLE_ENTITY` | 422 | No | `https://api.neurocipher.io/errors/UNPROCESSABLE_ENTITY` | Domain rule violation (e.g., business validation, calculated quota breach). Include `details.rule`. |
| `RATE_LIMITED` | 429 | Yes (after wait) | `https://api.neurocipher.io/errors/RATE_LIMITED` | Tenant throttle or quota exceeded. Include `details.retry_after_seconds` and honor `X-RateLimit-*` headers. |
| `INTERNAL` | 500 | Yes (idempotent requests) | `https://api.neurocipher.io/errors/INTERNAL` | Unexpected server error; fingerprint is logged but never returned. Retry idempotent operations once after a short delay. |
| `UNAVAILABLE` | 503 | Yes (after wait) | `https://api.neurocipher.io/errors/UNAVAILABLE` | Service brownout, maintenance, or dependency outage. Honor `retry_after_seconds`. |

## RFC 7807 examples

### INVALID_REQUEST example

```json
{
  "type": "https://api.neurocipher.io/errors/INVALID_REQUEST",
  "title": "INVALID_REQUEST",
  "status": 400,
  "detail": "Missing required field 'source'.",
  "instance": "urn:nc:error:ingest-event:01H9Z4Q7A6M8T1N9ZK7N1H2B3C",
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Request payload failed schema validation.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2B3C",
    "details": {
      "field": "source"
    }
  }
}
```

### UNAUTHENTICATED example

```json
{
  "type": "https://api.neurocipher.io/errors/UNAUTHENTICATED",
  "title": "UNAUTHENTICATED",
  "status": 401,
  "detail": "Authorization header is missing or invalid.",
  "instance": "urn:nc:error:query:01H9Z4Q7A6M8T1N9ZK7N1H2B4D",
  "error": {
    "code": "UNAUTHENTICATED",
    "message": "Credentials are required.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2B4D"
  }
}
```

### UNAUTHORIZED example

```json
{
  "type": "https://api.neurocipher.io/errors/UNAUTHORIZED",
  "title": "UNAUTHORIZED",
  "status": 403,
  "detail": "Token lacks the `jobs:write` scope for tenant 01H9Z4Q7.",
  "instance": "urn:nc:error:jobs:01H9Z4Q7A6M8T1N9ZK7N1H2D5E",
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Scope or policy denied the request.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2D5E",
    "details": {
      "tenant_id": "01H9Z4Q7A6M8T1N9ZK7N1H2"
    }
  }
}
```

### RESOURCE_NOT_FOUND example

```json
{
  "type": "https://api.neurocipher.io/errors/RESOURCE_NOT_FOUND",
  "title": "RESOURCE_NOT_FOUND",
  "status": 404,
  "detail": "Job job_01H9Z3T was not found for tenant 01H9Z4Q7.",
  "instance": "urn:nc:error:jobs:01H9Z4Q7A6M8T1N9ZK7N1H2F0",
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The requested resource is unavailable under the current tenant.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2F0",
    "details": {
      "resource_id": "job_01H9Z3T",
      "tenant_id": "01H9Z4Q7A6M8T1N9ZK7N1H2"
    }
  }
}
```

### CONFLICT example

```json
{
  "type": "https://api.neurocipher.io/errors/CONFLICT",
  "title": "CONFLICT",
  "status": 409,
  "detail": "Job job_01H9Z3T already exists with idempotency key 01H9Z4Q7.",
  "instance": "urn:nc:error:jobs:01H9Z4Q7A6M8T1N9ZK7N1H2G1",
  "error": {
    "code": "CONFLICT",
    "message": "State conflict detected.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2G1",
    "details": {
      "resource_id": "job_01H9Z3T"
    }
  }
}
```

### UNPROCESSABLE_ENTITY example

```json
{
  "type": "https://api.neurocipher.io/errors/UNPROCESSABLE_ENTITY",
  "title": "UNPROCESSABLE_ENTITY",
  "status": 422,
  "detail": "Priority 'super-fast' violates plan constraints for tenant 01H9Z4Q7.",
  "instance": "urn:nc:error:jobs:01H9Z4Q7A6M8T1N9ZK7N1H2H2",
  "error": {
    "code": "UNPROCESSABLE_ENTITY",
    "message": "Domain rule failed.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2H2",
    "details": {
      "rule": "premium_priority_plan"
    }
  }
}
```

### RATE_LIMITED example

```json
{
  "type": "https://api.neurocipher.io/errors/RATE_LIMITED",
  "title": "RATE_LIMITED",
  "status": 429,
  "detail": "Tenant 01H9Z4Q7 exceeded the Pro plan burst limit.",
  "instance": "urn:nc:error:ingest-event:01H9Z4Q7A6M8T1N9ZK7N1H2I3",
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Try again after reset.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2I3",
    "details": {
      "retry_after_seconds": 60
    }
  }
}
```

### INTERNAL example

```json
{
  "type": "https://api.neurocipher.io/errors/INTERNAL",
  "title": "INTERNAL",
  "status": 500,
  "detail": "Unexpected exception while writing to the tenant 01H9Z4Q7 job log.",
  "instance": "urn:nc:error:jobs:01H9Z4Q7A6M8T1N9ZK7N1H2J4",
  "error": {
    "code": "INTERNAL",
    "message": "Server error; retry if the request is idempotent.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2J4"
  }
}
```

### UNAVAILABLE example

```json
{
  "type": "https://api.neurocipher.io/errors/UNAVAILABLE",
  "title": "UNAVAILABLE",
  "status": 503,
  "detail": "Regional vector search is temporarily in brownout mode.",
  "instance": "urn:nc:error:query:01H9Z4Q7A6M8T1N9ZK7N1H2K5",
  "error": {
    "code": "UNAVAILABLE",
    "message": "Service is temporarily unavailable.",
    "correlation_id": "01H9Z4Q7A6M8T1N9ZK7N1H2K5",
    "details": {
      "retry_after_seconds": 120
    }
  }
}
```
