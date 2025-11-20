id: API-002
title: Service Contracts and Versioning
owner: Platform
status: Final v1.0
last_reviewed: 2025-11-15

# API-002 Service Contracts and Versioning

Owner: Platform  
Scope: Neurocipher Pipeline public APIs on AWS. Consumer-specific additions are tracked in `docs/integrations/`.  
Status: Final v1.0  
Related: API-001 Edge and Gateway, DM-005 Governance and Migrations, ADR-006 Security and Identity, ADR-009 Cost and Autoscaling, ADR-010 DR and Backups, OBS-003 Performance Monitoring, - ADR-011 System Boundary and Orchestrator Placement

---

## 1. Goals

Stable contracts. Predictable evolution. Safe deprecations. Automated compatibility checks. One source of truth for SDKs, docs, mocks, tests.

Outcomes

- Clear versioning scheme with support windows.
    
- OpenAPI-first workflow with linting and gating.
    
- Strong rules for additive changes and removals.
    
- Consistent errors, pagination, filtering, and webhooks.
    
- Generated SDKs and test artifacts.
    
- Security action surfaces (`/v1/security/actions*`) stay in the same version set as ingest/query and follow the contracts defined in `schemas/events/`.
    

---

## 2. Versioning model

Surface version

- URI major: `/v1`, `/v2`. Major denotes breaking change.
    
- Minor and patch are non-breaking and not encoded in path.
    
- Advertise minor.patch via `X-API-Version: 1.4.2`.
    

Semantic rules

- Additive changes only within a major.
    
- Enums only expand. Never repurpose symbols.
    
- Required fields cannot be added to existing request bodies.
    
- Response fields may be added. Never remove or change type.
    

Deprecation policy

- Minimum support window per major: 12 months after next major GA.
    
- Send `Sunset`, `Deprecation`, and `Link: <url>; rel="deprecation"` headers on deprecated endpoints.
    
- Include `X-API-Deprecated: true` and `X-API-Removal-Date: YYYY-MM-DD`.
    

Compatibility signaling

- `Accept: application/vnd.neurocipher+json;v=1`.
    
- If header present and mismatched, return `406 NOT_ACCEPTABLE`.
    

---

## 3. Names, ids, types

JSON only. UTF-8. snake_case.

Identifiers

- Public ids: ULID string. Prefix resource if exposed, e.g., `job_01J...`.
    
- Internal PKs never exposed.
    

Timestamps

- RFC 3339 UTC with Z suffix.
    

Booleans and numbers

- No stringly typed numbers or booleans.
    
- Monetary values use integer minor units with currency code.
    

Binary and large payloads

- Use pre-signed URLs. Do not embed binary.
    

---

## 4. Error contract

Envelope

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The job was not found",
    "correlation_id": "01J9Z1Q7A6M8...",
    "details": { "resource_id": "job_01J..." }
  }
}
```

HTTP to code mapping is canonicalized in docs/api-ops/API-Error-Catalog.md; do not create duplicate tables.

Do not leak stack traces. Fingerprints live in logs.

---

## 5. Pagination, filtering, sorting

Pagination

- Cursor-based paging with the shared `page_size` + `next_cursor` pattern defined under `components/parameters` and `components/schemas` in `openapi.yaml`. `page_size` defaults to 50, caps at 200, and is scoped per tenant, route, and `next_cursor`.
- Every pageable response embeds `pagination` metadata (`PaginationMetadata`) that reiterates the `page_size`, the opaque `next_cursor`, and hints whether more pages exist. Clients should return the prior `next_cursor` as the `next_cursor` query parameter.
- Sorting and filtering options stay the same (stable sort on `id`, `sort=field` or `sort=-field`, `filter[field]=value`, `filter[field][gte]`, `filter[field][lte]`), and the pagination cursor encodes tenant and sort state.

List response shape

```json
{
  "data": [ ... ],
  "pagination": {
    "page_size": 50,
    "next_cursor": "opaque-cursor-token-01"
  }
}
```

---

## 6. Idempotency and concurrency

Idempotency

- All write verbs require `Idempotency-Key`. See API-001 for storage, TTL, and conflict semantics.
- On replay return the identical status/body and `Idempotent-Replay: true`. Divergent payloads return `409 CONFLICT`.

Optimistic concurrency

- `etag` header supports conditional updates.
- Requests may send `If-Match: "<etag>"`. On mismatch return `409 CONFLICT`.

---

## 7. Webhooks contract

Subscription

- `POST /v1/webhooks` with `url`, `events[]`, `secret`, optional `api_version`.
    
- Verification challenge response required within 10 seconds.
    

Envelope

```json
{
  "id": "evt_01J...",
  "type": "job.completed",
  "api_version": "1.4",
  "created_at": "2025-10-27T20:15:03Z",
  "tenant_id": "01H...",
  "data": { ... }
}
```

Security

- HMAC SHA256 over `t.timestamp + "." + raw_body`.
    
- Header `X-Webhook-Signature: t=<unix>, v1=<hex>`.
    

Retries and replay

- 5 attempts. Exponential backoff starting at 15 seconds.
    
- `POST /v1/webhook_deliveries/{id}/replay`.
    

---

## 8. OpenAPI workflow

Spec layout

- Monorepo `api/` root with per-service specs:
    
    - `api/neurocipher/openapi.yaml`
        
    - `api/audithound/openapi.yaml`
        
- Shared components in `api/_components.yaml` referenced via `$ref`.
    

Required sections

- `securitySchemes` (bearer JWT and SigV4 notes).
    
- Global error schema.
    
- Pagination parameters and schemas.
    
- Common headers: `Correlation-Id`, `Tenant-Id`, `Idempotency-Key`.
    
- Webhook components.
    

Style and lint rules (spectral)

- No unnamed schemas.
    
- No `nullable: true`.
    
- Explicit `additionalProperties` policy per object.
    
- Examples required for all 2xx responses.
    
- OperationId unique and verb-noun: `createJob`, `listJobs`.
    

Examples policy

- Provide request and response examples including error.
    
- Use realistic ULIDs and RFC 3339 timestamps.
    

Breaking-change detection

- Use `oasdiff` or `openapi-diff` in CI.
    
- CI fails on:
    
    - Removed or renamed paths.
        
    - Required request fields added.
        
    - Type or format changes.
        
    - Narrowed enums.
        
    - Status code removals.
        

Mocking and tests

- Generate Prism or WireMock stubs from OpenAPI for integration tests.
    
- Contract tests: consumer Pacts stored in `contracts/` and verified in CI.
    

---

## 9. SDK generation

Targets

- TypeScript, Python, Go.
    

Versioning

- SDK major mirrors API major. SDK minor mirrors spec minor.
    

Generation

- Use `openapi-generator-cli` pinned version.
    
- TS: Axios client. Python: httpx. Go: native net/http.
    
- Add retry middleware with idempotency header for safe verbs.
    
- Publish to private registry. Tag with commit SHA and semver.
    

Quality gates

- Compile and unit test the generated SDKs in CI.
    
- Lint generated TS with ESLint, Python with ruff, Go with staticcheck.
    

---

## 10. Standard components (canonical)

Security schemes

```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

Common headers

```yaml
parameters:
  CorrelationId:
    name: Correlation-Id
    in: header
    required: false
    schema: { type: string }
  TenantId:
    name: Tenant-Id
    in: header
    required: true
    schema: { type: string, pattern: '^[0-9A-HJKMNP-TV-Z]{26}$' }
  IdempotencyKey:
    name: Idempotency-Key
    in: header
    required: true
    schema: { type: string, maxLength: 128 }
```

Error schema

```yaml
schemas:
  Error:
    type: object
    required: [error]
    properties:
      error:
        type: object
        required: [code, message, correlation_id]
        properties:
          code: { type: string }
          message: { type: string }
          correlation_id: { type: string }
          details: { type: object, additionalProperties: true }
```

Pagination schema

```yaml
schemas:
  ListResponse:
    type: object
    properties:
      data: { type: array, items: { $ref: '#/components/schemas/Any' } }
      next: { type: string, nullable: true }
      limit: { type: integer, minimum: 1, maximum: 200 }
```

---

## 11. Example path excerpts

Jobs

```yaml
openapi: 3.0.3
info:
  title: Neurocipher Public API
  version: 1.4.0
paths:
  /v1/jobs:
    get:
      operationId: listJobs
      security: [{ bearerAuth: [] }]
      parameters:
        - $ref: '#/components/parameters/TenantId'
        - in: query
          name: limit
          schema: { type: integer, default: 50, maximum: 200 }
        - in: query
          name: after
          schema: { type: string }
        - in: query
          name: sort
          schema: { type: string, enum: [created_at,-created_at] }
      responses:
        '200':
          description: OK
          content:
            application/json:
              examples:
                ok:
                  value:
                    data: [{ "id":"job_01J...", "status":"queued", "created_at":"2025-10-27T20:20:00Z"}]
                    next: null
                    limit: 50
    post:
      operationId: createJob
      security: [{ bearerAuth: [] }]
      parameters:
        - $ref: '#/components/parameters/TenantId'
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [input_url]
              properties:
                input_url: { type: string, format: uri }
                priority: { type: string, enum: [low, normal, high], default: normal }
      responses:
        '202':
          description: Accepted
          content:
            application/json:
              examples:
                accepted:
                  value: { "id": "job_01J...", "status": "queued", "created_at": "2025-10-27T20:20:00Z" }
        '409':
          description: Conflict
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
```

Webhooks registration

```yaml
paths:
  /v1/webhooks:
    post:
      operationId: createWebhook
      security: [{ bearerAuth: [] }]
      parameters:
        - $ref: '#/components/parameters/TenantId'
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [url, events, secret]
              properties:
                url: { type: string, format: uri }
                events: { type: array, items: { type: string } }
                secret: { type: string, minLength: 16 }
                api_version: { type: string, pattern: '^[0-9]+\\.[0-9]+$' }
      responses:
        '201':
          description: Created
```

---

## 12. Change governance

Process

- Proposed changes open as PR that updates OpenAPI, examples, and changelog.
    
- Run `spectral lint`, `oasdiff` against last GA, Pact verification, and mock tests.
    
- Generate SDKs and docs preview. Attach to PR.
    

Changelog

- Markdown `CHANGELOG.md` per product. Keepers:
    
    - Added
        
    - Changed
        
    - Deprecated
        
    - Removed
        
    - Fixed
        
    - Security
        

Rollout

- Additive fields behind response feature flags for dry runs if needed.
    
- Deprecations announce in status page and mailing list.
    
- Removal only after published removal date.
    

Rollback

- Maintain last two minor schema variants behind negotiation header for 14 days post deploy.
    
- Keep dual-writer or projection shims if needed.
    

---

## 13. Documentation

Sources

- OpenAPI serves as the single source.
    
- Human docs built by Redocly or Stoplight from the spec.
    
- Postman collection auto-exported from OpenAPI.
    

Accuracy gates

- Docs build in CI must succeed.
    
- Example payloads validated against schema.
    

---

## 14. Compliance links

- Data retention is governed by ADR-007 Data Lifecycle and Retention.
    
- Access control and scopes in ADR-006 Security and Identity.
    
- DR and backup coverage for specs and docs in ADR-010.
    
- Cost of extra fields and response sizes tracked in ADR-009.
- For orchestration-level routing and execution boundaries, see ADR-011 §4.1–4.2 and `docs/integrations/README.md`. Justification: Ensures that any new service contract understands where orchestrator-owned logic resides and keeps inter-service design consistent.

---

## 15. Acceptance criteria

- `oasdiff` shows no breaking changes for minor releases.
    
- All operations have examples for 2xx and 4xx.
    
- Spectral lint passes with zero errors.
    
- Pact tests pass for top three consumers.
    
- SDKs compile and publish in dry run.
    
- Mock server can serve smoke tests for all paths.
    

---

## 16. Deliverables

- `api/neurocipher/openapi.yaml` and `api/audithound/openapi.yaml`.
    
- `api/_components.yaml` with shared pieces.
    
- `contracts/` consumer pacts and verification config.
    
- `sdks/` generated clients with README and examples.
    
- `CHANGELOG.md` per product.
    
- CI pipeline step definitions and lint config.
    

---

## 17. CI snippets

OpenAPI lint

```bash
spectral lint api/**/openapi.yaml
```

Diff gate

```bash
oasdiff -format text -fail-on-breaking -base refs/last-ga.yaml -revision api/neurocipher/openapi.yaml
```

SDK build

```bash
openapi-generator-cli generate -i api/neurocipher/openapi.yaml -g typescript-axios -o sdks/ts
```

Pact verify

```bash
pact-verifier --provider-base-url=http://mock --pact-urls=contracts/**/*.json
```

---
