---
description: OpenAPI and JSON Schema standards for Neurocipher platform
applyTo: '{openapi.yaml,schemas/**/*.json}'
---

# OpenAPI and JSON Schema Standards

API specifications and data schemas are critical documentation for the Neurocipher platform. All API definitions use OpenAPI 3.0, and data schemas use JSON Schema.

## OpenAPI Specifications

### File Location

- Main API spec: `openapi.yaml` (repository root)
- Service-specific specs: `services/{service}/openapi.yaml`

### OpenAPI Structure

```yaml
openapi: 3.0.0
info:
  title: Neurocipher API
  version: 1.0.0
  description: Cloud security platform API
  contact:
    name: Platform Engineering
    email: platform@neurocipher.io

servers:
  - url: https://api.neurocipher.io/v1
    description: Production API
  - url: https://api-stg.neurocipher.io/v1
    description: Staging API

paths:
  /findings:
    get:
      summary: List security findings
      operationId: listFindings
      tags:
        - Findings
      parameters:
        - name: severity
          in: query
          schema:
            type: string
            enum: [critical, high, medium, low]
      responses:
        '200':
          description: List of findings
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FindingList'
        '400':
          $ref: '#/components/responses/BadRequest'
        '500':
          $ref: '#/components/responses/InternalError'

components:
  schemas:
    Finding:
      type: object
      required:
        - id
        - severity
        - title
      properties:
        id:
          type: string
          format: uuid
          description: UUIDv7 identifier
          example: 018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a
        severity:
          type: string
          enum: [critical, high, medium, low]
        title:
          type: string
        created_at:
          type: string
          format: date-time
          example: 2025-11-26T18:00:00Z
  
  responses:
    BadRequest:
      description: Bad request
      content:
        application/problem+json:
          schema:
            $ref: '#/components/schemas/ProblemDetail'
```

### Path Design

- Use kebab-case for paths: `/security-findings`, not `/securityFindings`
- Version APIs: `/v1/findings`, `/v2/findings`
- Use plural nouns: `/findings`, not `/finding`
- Nest resources logically: `/findings/{id}/actions`

### HTTP Methods

- `GET`: Retrieve resources (idempotent)
- `POST`: Create resources or trigger actions
- `PUT`: Replace entire resource (idempotent)
- `PATCH`: Partial update
- `DELETE`: Remove resource (idempotent)

### Request/Response Examples

Always include examples:

```yaml
paths:
  /findings:
    post:
      summary: Create a security finding
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateFindingRequest'
            example:
              severity: high
              title: Unencrypted S3 bucket
              description: S3 bucket lacks default encryption
              resource_id: arn:aws:s3:::my-bucket
      responses:
        '201':
          description: Finding created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Finding'
              example:
                id: 018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a
                severity: high
                title: Unencrypted S3 bucket
                created_at: 2025-11-26T18:00:00Z
```

### Error Responses

Use RFC 7807 Problem Details:

```yaml
components:
  schemas:
    ProblemDetail:
      type: object
      required:
        - type
        - title
        - status
      properties:
        type:
          type: string
          format: uri
          description: URI reference identifying the problem type
          example: https://api.neurocipher.io/problems/validation-error
        title:
          type: string
          description: Short, human-readable summary
          example: Validation Error
        status:
          type: integer
          description: HTTP status code
          example: 400
        detail:
          type: string
          description: Detailed explanation
          example: The 'severity' field must be one of critical, high, medium, low
        instance:
          type: string
          format: uri
          description: URI reference identifying the specific occurrence
          example: /v1/findings
```

### Security Schemes

Define authentication methods:

```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    apiKey:
      type: apiKey
      in: header
      name: X-API-Key

security:
  - bearerAuth: []
```

## JSON Schema Standards

### Schema Location

- Event schemas: `schemas/events/event.{domain}.{name}.v{major}.json`
- Command schemas: `schemas/events/cmd.{domain}.{name}.v{major}.json`
- Examples: `schemas/events/examples/`

### Schema Structure

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.neurocipher.io/events/event.security.finding.v1.json",
  "title": "Security Finding Event",
  "description": "Event emitted when a security finding is created or updated",
  "type": "object",
  "required": ["id", "specversion", "type", "source", "data"],
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid",
      "description": "Unique event identifier (UUIDv7)"
    },
    "specversion": {
      "type": "string",
      "const": "1.0",
      "description": "CloudEvents version"
    },
    "type": {
      "type": "string",
      "const": "security.finding.created.v1",
      "description": "Event type"
    },
    "source": {
      "type": "string",
      "format": "uri",
      "description": "Event source URI",
      "example": "arn:aws:lambda:us-east-1:123456789012:function:svc-scan"
    },
    "time": {
      "type": "string",
      "format": "date-time",
      "description": "Event timestamp (ISO 8601)"
    },
    "data": {
      "$ref": "#/$defs/FindingData"
    }
  },
  "$defs": {
    "FindingData": {
      "type": "object",
      "required": ["id", "severity", "title"],
      "properties": {
        "id": {
          "type": "string",
          "format": "uuid"
        },
        "severity": {
          "type": "string",
          "enum": ["critical", "high", "medium", "low"]
        },
        "title": {
          "type": "string"
        }
      }
    }
  },
  "examples": [
    {
      "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
      "specversion": "1.0",
      "type": "security.finding.created.v1",
      "source": "arn:aws:lambda:us-east-1:123456789012:function:svc-scan",
      "time": "2025-11-26T18:00:00Z",
      "data": {
        "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0b",
        "severity": "high",
        "title": "Unencrypted S3 bucket"
      }
    }
  ]
}
```

### Required Schema Fields

Every schema must include:

1. **`$schema`**: JSON Schema version
2. **`$id`**: Unique identifier URI
3. **`title`**: Human-readable name
4. **`description`**: Purpose and usage
5. **`examples`**: Valid example payloads

### Schema Versioning

- Include version in filename and `$id`
- Use semantic versioning: `v1`, `v2`, etc.
- Breaking changes require new major version
- Add new optional fields without version bump

### CloudEvents Schema

All events must follow CloudEvents 1.0:

```json
{
  "required": ["id", "specversion", "type", "source"],
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid",
      "description": "Event ID (UUIDv7)"
    },
    "specversion": {
      "type": "string",
      "const": "1.0"
    },
    "type": {
      "type": "string",
      "pattern": "^[a-z]+\\.[a-z]+\\.(created|updated|deleted)\\.v[0-9]+$",
      "description": "Event type: domain.entity.action.version"
    },
    "source": {
      "type": "string",
      "format": "uri",
      "description": "Event source identifier"
    },
    "time": {
      "type": "string",
      "format": "date-time"
    },
    "datacontenttype": {
      "type": "string",
      "default": "application/json"
    },
    "data": {
      "type": "object"
    }
  }
}
```

### Event Type Naming

Format: `domain.entity.action.version`

Examples:
- `security.finding.created.v1`
- `security.finding.updated.v1`
- `security.action.completed.v1`
- `compliance.scan.started.v1`

## Data Types

### Standard Types

- **IDs**: Use `uuid` format, describe as UUIDv7
- **Timestamps**: Use `date-time` format with ISO 8601 examples
- **URIs**: Use `uri` or `uri-reference` format
- **Emails**: Use `email` format
- **Enums**: List all valid values explicitly

```json
{
  "id": {
    "type": "string",
    "format": "uuid",
    "description": "UUIDv7 identifier",
    "example": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a"
  },
  "created_at": {
    "type": "string",
    "format": "date-time",
    "description": "Creation timestamp",
    "example": "2025-11-26T18:00:00Z"
  },
  "severity": {
    "type": "string",
    "enum": ["critical", "high", "medium", "low"],
    "description": "Finding severity level"
  }
}
```

### Validation Rules

Add constraints where appropriate:

```json
{
  "title": {
    "type": "string",
    "minLength": 1,
    "maxLength": 255,
    "description": "Finding title"
  },
  "score": {
    "type": "number",
    "minimum": 0,
    "maximum": 100,
    "description": "Risk score"
  },
  "tags": {
    "type": "array",
    "items": {
      "type": "string"
    },
    "minItems": 0,
    "maxItems": 10,
    "uniqueItems": true
  }
}
```

## Validation

### Spectral Linting

All OpenAPI specs must pass Spectral validation:

```bash
npx @stoplight/spectral-cli lint openapi.yaml
```

Configuration in `.spectral.yaml`:

```yaml
extends: spectral:oas
rules:
  operation-description: error
  operation-operationId: error
  operation-tags: error
  info-contact: error
  info-description: error
```

### JSON Schema Validation

Validate schema files:

```bash
# Install ajv-cli
npm install -g ajv-cli

# Validate schema against meta-schema
ajv compile -s schemas/events/event.security.finding.v1.json

# Validate examples against schema
ajv validate -s schemas/events/event.security.finding.v1.json \
  -d schemas/events/examples/finding-created.json
```

## Documentation

### Schema Documentation

Each schema should be self-documenting:

1. **Descriptions**: Every field needs a description
2. **Examples**: Include realistic examples
3. **Constraints**: Document validation rules
4. **Relationships**: Note referenced schemas

### API Documentation

Generate documentation from OpenAPI:

```bash
# Using Redoc
npx @redocly/cli build-docs openapi.yaml

# Using Swagger UI
npx swagger-ui-watcher openapi.yaml
```

## Examples

### Complete Finding Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.neurocipher.io/events/event.security.finding.v1.json",
  "title": "Security Finding Event",
  "description": "CloudEvents envelope for security findings",
  "type": "object",
  "required": ["id", "specversion", "type", "source", "data"],
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid",
      "description": "Event identifier (UUIDv7)",
      "example": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a"
    },
    "specversion": {
      "type": "string",
      "const": "1.0"
    },
    "type": {
      "type": "string",
      "const": "security.finding.created.v1"
    },
    "source": {
      "type": "string",
      "format": "uri",
      "description": "Source service ARN"
    },
    "time": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp"
    },
    "data": {
      "type": "object",
      "required": ["id", "severity", "title", "resource_id"],
      "properties": {
        "id": {
          "type": "string",
          "format": "uuid"
        },
        "severity": {
          "type": "string",
          "enum": ["critical", "high", "medium", "low"]
        },
        "title": {
          "type": "string",
          "minLength": 1,
          "maxLength": 255
        },
        "description": {
          "type": "string"
        },
        "resource_id": {
          "type": "string",
          "description": "AWS resource ARN or ID"
        },
        "remediation": {
          "type": "object",
          "properties": {
            "steps": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "automated": {
              "type": "boolean"
            }
          }
        }
      }
    }
  },
  "examples": [
    {
      "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
      "specversion": "1.0",
      "type": "security.finding.created.v1",
      "source": "arn:aws:lambda:us-east-1:123456789012:function:svc-scan",
      "time": "2025-11-26T18:00:00Z",
      "data": {
        "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0b",
        "severity": "high",
        "title": "Unencrypted S3 bucket",
        "description": "S3 bucket lacks default encryption",
        "resource_id": "arn:aws:s3:::my-bucket",
        "remediation": {
          "steps": [
            "Enable default encryption on S3 bucket",
            "Choose KMS key for encryption"
          ],
          "automated": true
        }
      }
    }
  ]
}
```

## Integration with Documentation

When updating schemas or APIs:

1. Update the schema file
2. Update corresponding documentation in `docs/`
3. Update examples in `schemas/events/examples/`
4. Run validation: `make lint`
5. Verify Spectral checks pass in CI

## Anti-Patterns to Avoid

1. **Missing descriptions**: Every field needs documentation
2. **No examples**: Always include realistic examples
3. **Inconsistent naming**: Use snake_case in JSON
4. **Missing validation**: Add constraints where appropriate
5. **Breaking changes without versioning**: Bump version for breaking changes
6. **Hardcoded values**: Use enums or patterns
7. **Unclear error responses**: Always use RFC 7807 format

## Review Checklist

Before submitting schema/API changes:

- [ ] All required fields (`$schema`, `$id`, `title`, `description`, `examples`) present
- [ ] Descriptions for all properties
- [ ] Examples are valid and realistic
- [ ] Versioning follows conventions
- [ ] CloudEvents structure for events
- [ ] RFC 7807 for error responses
- [ ] Spectral validation passes
- [ ] JSON Schema validation passes
- [ ] Documentation updated in `docs/`
- [ ] Examples in `schemas/events/examples/` updated

## References

- `.spectral.yaml` - Linting rules
- `openapi.yaml` - Main API specification
- `schemas/events/` - Event schemas
- REF-001 - Standards catalog
- See AGENTS.md for validation automation
