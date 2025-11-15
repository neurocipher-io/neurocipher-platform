id: SVC-001
title: Online Serving Contract Overview
owner: platform-serving
status: Draft v0.1
last_reviewed: 2025-11-09

# SVC-001 Online Serving Contract

**References:** SVC-001-Online-Serving-Contract-Specification.md, SRG-001, DCON-001, OBS-002

---

## 1. Purpose
Summarize the enforceable contract for real-time query endpoints (Weaviate, OpenSearch, GraphQL gateway) and provide a quick reference for contributors implementing or modifying online serving components.

## 2. Interface Matrix
| Interface | Protocol | Versioning | Schema Source | Notes |
|-----------|----------|------------|---------------|-------|
| Weaviate Semantic Search | REST / GraphQL | URL versioned (`/v2`) | `schemas/openapi/weaviate-online.yaml` | Embedding + hybrid queries |
| OpenSearch Metadata API | REST | Index alias per SemVer (`discovery_v1`) | `schemas/openapi/opensearch-online.yaml` | Supports filterable facets |
| Query GraphQL Gateway | GraphQL | SDL tagged via git SHA | `schemas/openapi/query-gateway.graphql` | Aggregates RDS lookup |
| Inference Microservice | REST POST | `/v1/embed` | `schemas/openapi/embed.yaml` | Auth via SigV4-only |

## 3. Sample Endpoints & Payloads
```http
POST https://api.neurocipher.dev/v2/search
Authorization: SIGV4 <signature>
Content-Type: application/json

{
  "query": "neuro rehab",
  "tenant_id": "acme-prod",
  "limit": 5,
  "filters": {"modality": ["eeg"]}
}
```

```graphql
query PatientSnapshot($tenant: ID!, $id: ID!) {
  patient(tenantId: $tenant, id: $id) {
    id
    latestEmbedding(version: "v2")
    metadata {
      diagnosis
      updatedAt
    }
  }
}
```

## 4. Versioning Policy
| Surface | Current Version | Promotion Rule | Sunset Window |
|---------|-----------------|----------------|---------------|
| REST Search (`/search`) | `v2` | Promote after dual-write + 2 successful load tests | 90 days after announcing `v3` |
| GraphQL Gateway | `2025.10` SDL tag | Promote via schema registry approval + contract tests | 60 days after publishing new tag |
| Inference API (`/v1/embed`) | `v1` | Promote with model rollout RFC + canary traffic | Old version disabled 30 days post rollout |
| OpenSearch Metadata | `discovery_v1` alias | Promote by creating `discovery_v2` alias and backfill | 45 days before alias removal |

## 5. Contract Guardrails
- All endpoints must emit OpenAPI/SDL artifacts stored in git and published through SRG-001 automation.  
- Backward-incompatible changes require new URL/version plus migration plan documented in ADR.  
- Auth: SigV4 + IAM for internal, OAuth for partner-facing; never mix across stages.  
- Payload size hard limit 2 MB; reject larger requests with `413 Payload Too Large`.  
- Standard headers for online serving endpoints: `Authorization`, `Tenant-Id`, `Correlation-Id`, and `Idempotency-Key` for mutating writes, aligned with `openapi.yaml` (`/query`, `/ingest/event`) and API-001.  
- Pagination: cursor-based using `top_k` (or `limit`) query parameters and the `next_cursor` field in the response body, as defined in the `QueryResponse` schema.  
- Error model: HTTP 4xx/5xx responses use the `ErrorResponse` envelope from `openapi.yaml` with stable error codes for INVALID_REQUEST (400), UNAUTHENTICATED (401), UNAUTHORIZED (403), RESOURCE_NOT_FOUND (404), CONFLICT (409), RATE_LIMITED (429), and INTERNAL/UNAVAILABLE (5xx).  
- Quotas: default per-tenant QPS and burst limits must match the rate-limit header values (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) and the plans defined in API-001 / OBS-003; overrides require documented exceptions.

## 6. Observability & SLOs
- Availability ≥ 99.9%, p95 latency < 250 ms (search) / < 400 ms (hybrid).  
- Log every request ID + tenant for traceability; propagate headers (`x-nc-request-id`).  
- Alerts link to RB-API-002 and RB-VEC-003 for remediation.

## 7. Validation Workflow
1. Update schema → run `npm run spectral`.  
2. Execute `make test` (ensures contract tests under `services/query-api/tests/contracts`).  
3. Provide changelog entry referencing Jira + consumer teams.  
4. Obtain approvals from platform-serving owner plus impacted service owners (ops/owners.yaml).

## 8. Change Log
|| Version | Date | Summary |
||---------|------|---------|
|| v0.1 | 2025-11-09 | Initial digest derived from SVC-001 specification |

## 9. Acceptance Criteria
- All online query endpoints expose `Tenant-Id`, `Correlation-Id`, and (where applicable) `Idempotency-Key` headers and map 4xx/5xx errors to the shared `ErrorResponse` envelope in `openapi.yaml`.  
- Effective QPS and burst limits per tenant follow the quotas defined in API-001 and are observable via rate-limit headers.  
- Pagination behavior for `/query` and any related search endpoints matches the cursor and `next_cursor` semantics in the OpenAPI contract.  
- SLOs for availability and latency are measured and surfaced in dashboards, with alerts pointing to RB-API-002 and RB-VEC-003.  
- Any backward-incompatible surface change is shipped via a new versioned URL or alias and documented in the SVC-001 specification.
