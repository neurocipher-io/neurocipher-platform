# API-001 Edge and Gateway Architecture

**Owner**: Platform  
**Scope**: Neurocipher Pipeline and AuditHound. AWS only. No shared code with Nexis.  
**Status**: Final v1.0  
**Related**: ADR-006 Security and Identity, ADR-009 Cost Control and Autoscaling, ADR-010 Disaster Recovery and Backups, REL-001 High Availability and Fault Tolerance, DM-005 Governance and Migrations, OBS-003 Performance Monitoring and Optimization

---

## 1. Purpose and outcomes

Provide a stable, secure, multi-tenant external API surface with predictable performance, clear quotas, strong isolation, and full observability. Minimize blast radius. Keep costs bounded.

**Outcomes**

- Public HTTPS entry with WAF and caching
    
- Authenticated access with per-tenant quotas and rate limits
    
- Back pressure for spikes with graceful degradation
    
- Standardized errors, pagination, and idempotency
    
- Turnkey webhooks with signed delivery and replay
    
- Full tracing and log correlation
    
- Tested failover and restore
    

---

## 2. Reference architecture

**Edge**

- Route 53
    
- CloudFront for GET caching and TLS termination
    
- AWS WAF with managed and custom rules
    
- API Gateway HTTP APIs for public endpoints
    

**Core**

- API Gateway → ALB → Fargate services (ECS). Lambda for light endpoints
    
- Private APIs via VPC endpoints. Service discovery via Cloud Map
    
- EventBridge for async. SQS for work queues. DLQ per queue
    
- NAT for controlled egress. VPC endpoints for AWS services
    

**Data paths**

- S3 for object payloads. S3 pre-signed URLs for upload and download
    
- RDS Postgres or DynamoDB per service
    
- KMS for envelope encryption. Secrets Manager for secrets
    

---

## 3. Domains and routing

- `api.neurocipher.io` for Neurocipher Pipeline
    
- `api.audithound.cloud` for AuditHound
    
- `status.{zone}` for status pages (read only)
    
- CloudFront behaviors
    
    - Cache GET and HEAD for static and catalog endpoints
        
    - Bypass cache for POST, PUT, PATCH, DELETE
        
- API Gateway stages
    
    - `dev`, `test`, `stg`, `prod` mapped to subdomains per account
        

---

## 4. Authentication and authorization

**End users**

- Cognito User Pools as OIDC provider
    
- JWT access tokens in Authorization header
    
- Token lifetime 60 minutes. Refresh via OIDC flow only
    
- Required scopes example: `jobs:read`, `jobs:write`, `webhooks:manage`
    

**Service to service**

- SigV4 with IAM roles and resource policies
    
- Optional mTLS for partners using SPIFFE IDs
    
- Short lived credentials via STS. Max 1 hour
    

**Policy engine**

- Resource based checks in API Gateway and ALB
    
- Fine grained checks in services using Cedar or OPA bundles
    
- Every request includes `Tenant-Id` header
    

---

## 5. Multi tenancy and isolation

**Decision**: Row level isolation with strict tenant column and RLS in Postgres for control planes. Separate databases for noisy data planes. S3 prefixes per tenant with bucket policies.

**Controls**

- Mandatory `Tenant-Id` header. Validated against token claims
    
- RLS policies enforce tenant match on all queries
    
- Per tenant KMS data keys for at rest encryption where feasible
    
- Per tenant rate limits and quotas
    

---

## 6. Request and response standards

**Headers required**

- `Authorization: Bearer <jwt or sigv4>`
    
- `Tenant-Id: <ulid>`
    
- `Idempotency-Key: <uuidv4 or ulid>` on POST, PUT, PATCH that write
    
- `Correlation-Id: <ulid>` created if absent and echoed back
    

**Formats**

- JSON only. UTF-8. `Content-Type: application/json`
    
- snake_case field names
    
- Timestamps RFC 3339 UTC with Z
    
- ULID for public ids
    

**Pagination**

- Cursor based
    
- `?limit=50&after=<cursor>`
    
- `limit` max 200. Default 50
    

**Filtering and sort**

- `filter[field]=value`
    
- `sort=field` or `sort=-field`
    
- Stable sort on id as tiebreaker
    

---

## 7. Idempotency

**Scope**: All non GET write operations.  
**Storage**: DynamoDB table `idempotency_store` with 24 hour TTL.  
**Key**: Hash of `Idempotency-Key` + route + tenant + body hash.  
**Behavior**

- First request executes and stores response code, body hash, headers subset, expiry, and execution fingerprint
    
- Subsequent requests return stored response with `Idempotent-Replay: true`
    
- Safe to retry on 5xx or network failure
    
- Not applied to endpoints marked as non idempotent in spec
    

---

## 8. Error model

JSON envelope:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The job was not found",
    "correlation_id": "01J9Z1Q7A6M8T1N9ZK7N1A2B3C",
    "details": {"resource_id":"job_01H..."}
  }
}
```

**HTTP mapping**

|HTTP|Code|Notes|
|--:|---|---|
|400|INVALID_REQUEST|Schema or semantic validation|
|401|UNAUTHENTICATED|Missing or invalid token|
|403|UNAUTHORIZED|Scope or policy denied|
|404|RESOURCE_NOT_FOUND|No existence under tenant|
|409|CONFLICT|State conflict|
|422|UNPROCESSABLE_ENTITY|Domain rule violated|
|429|RATE_LIMITED|Rate or quota exceeded|
|500|INTERNAL|Unhandled error|
|503|UNAVAILABLE|Brownout or dependency outage|

Do not leak internal stack traces. Put the fingerprint in logs only.

---

## 9. Rate limits and quotas

**Keys**

- Per API key or per user for public apps
    
- Also enforced per tenant
    

**Burst algorithm**

- Token bucket at API Gateway. Refill every second
    

**Plans**

|Plan|Requests per second|Burst|Daily quota|Concurrent jobs|
|---|---|---|---|---|
|Free|5|25|50k|2|
|Pro|20|100|500k|10|
|Enterprise|100|500|5M|50|

Headers returned

- `X-RateLimit-Limit`
    
- `X-RateLimit-Remaining`
    
- `X-RateLimit-Reset`
    

---

## 10. Webhooks

**Subscription**

- Create with `POST /v1/webhooks` providing `url`, `events[]`, `secret`, `version`
    
- Verification challenge on create
    

**Security**

- HMAC SHA256 signatures using shared secret
    
- Header `X-Webhook-Signature: t=<unix>, v1=<hex>`
    
- Body canonical string is raw payload bytes
    

**Delivery**

- Retries 5 times with exponential backoff starting at 15 seconds
    
- Timeout 10 seconds
    
- DLQ on permanent failure
    
- Replay by `POST /v1/webhooks/{delivery_id}/replay`
    

**Event envelope**

```json
{
  "id": "evt_01J9Z2...",
  "type": "job.completed",
  "created_at": "2025-10-27T20:15:03Z",
  "tenant_id": "01H...",
  "data": { "...": "..." }
}
```

---

## 11. WAF and edge security

**Managed rules**

- AWS Managed Core
    
- SQLi and XSS
    
- Anonymous IP list
    
- Bot Control Standard
    

**Custom rules**

- Geo blocks as required
    
- IP allow lists for admin paths
    
- Rate based rule on path groups
    
- Block request bodies over 1.5 MB at edge
    

**TLS**

- TLS 1.2 minimum
    
- HSTS max age 6 months include subdomains preload
    
- mTLS for partner subdomains where approved
    

---

## 12. Network egress policy

- Egress through NAT with prefix list allow rules
    
- No direct internet from tasks
    
- VPC endpoints for S3, SQS, EventBridge, STS, KMS, CloudWatch
    
- DNS split horizon for internal services
    

---

## 13. Observability

**Logging**

- JSON line logs
    
- Fields: `ts`, `correlation_id`, `tenant_id`, `sub`, `route`, `method`, `status`, `latency_ms`, `ip`, `user_agent`, `bytes_in`, `bytes_out`
    
- PII redaction on known keys
    
- WAF logs to S3. 30 days hot, 365 days cold
    

**Metrics**

- RED for APIs
    
    - Request rate by route and tenant
        
    - Error rate by code class
        
    - Duration p50 p95 p99
        
- USE for infra
    
- Quota consumption per tenant
    

**Tracing**

- X-Ray and OpenTelemetry
    
- Propagate `traceparent` header
    
- Span for gateway, service, DB, and external calls
    

**Dashboards**

- API overview
    
- Tenant health
    
- Webhook success and latency
    
- Idempotency hit rate
    

---

## 14. SLOs and alerting

**SLOs**

- Availability 99.9 percent monthly per public API
    
- Latency p95 GET under 500 ms at gateway, writes under 800 ms
    
- Webhook delivery success 99 percent within 5 minutes
    
- Async job freshness 95 percent within 2 minutes
    

**Alerts**

- Burn rate alerts at 2 hour and 24 hour windows
    
- 5xx error rate over 1 percent for 5 minutes pages
    
- 429 surge per tenant creates ticket, not page
    
- Dead letter queue depth over 100 pages
    

---

## 15. Brownout and overload controls

- Global toggle per route to shed optional features
    
- Return 503 with `Retry-After` during controlled brownout
    
- Queue back pressure thresholds. Pause producers if DLQ grows
    
- Feature flags via AppConfig for rapid off
    

---

## 16. Compliance and privacy

- Data classification tags on fields
    
- Access logging to immutable S3 with Glacier tier after 90 days
    
- GDPR and PIPEDA request flows documented
    
- DSR endpoints require verified identity and tenant admin role
    
- Residency honored per tenant region choice where enabled
    

---

## 17. Cost controls

- Usage plans and quotas per plan
    
- CloudFront cache on eligible GET to reduce origin hits
    
- API Gateway detailed metrics off by default, on for prod only
    
- Right size Fargate weekly. Scale to zero workers when queues idle
    
- AWS Budgets at 80 and 100 percent. Anomaly detection on
    

---

## 18. DR and HA

- Multi AZ for gateways and services
    
- Cross region backups for state stores
    
- RPO 15 minutes. RTO 60 minutes for public API
    
- Regional failover runbook with Route 53 health checks and weighted records
    
- Quarterly game day. Include webhook replay test and idempotency restore
    

---

## 19. Change management

- All breaking changes require ADR with rollback plan
    
- Contract tests in CI must pass for release
    
- Canary for Lambda via CodeDeploy
    
- Blue green for Fargate behind ALB
    
- Rollback requires automated DB contract safety nets
    

---

## 20. Testing

- Schema validation tests against OpenAPI
    
- Security tests for auth flows and scope boundaries
    
- WAF rule regression tests with synthetic attacks
    
- Load tests with k6 at plan limits and burst
    
- Chaos tests for dependency failure and timeouts
    

---

## 21. Example endpoint pattern

```
POST /v1/jobs
Headers:
  Authorization: Bearer <jwt>
  Tenant-Id: 01H9...
  Idempotency-Key: 5b7f2c0e-0a4e-4d63-8b0a-9c2f7f8a1f10
  Content-Type: application/json
Body:
  { "input_url": "https://s3...", "priority": "normal" }

202 Accepted
{
  "id": "job_01J9Z3...",
  "status": "queued",
  "created_at": "2025-10-27T20:20:00Z"
}
```

---

## 22. Example error

```
429 Too Many Requests
Headers:
  X-RateLimit-Limit: 20
  X-RateLimit-Remaining: 0
  X-RateLimit-Reset: 1730060000
Body:
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Try again after reset.",
    "correlation_id": "01J9Z4..."
  }
}
```

---

## 23. Example webhook signature verification (pseudocode)

```python
def verify(signature_header, body_bytes, secret):
    items = dict(part.split("=", 1) for part in signature_header.split(","))
    ts = items["t"]
    v1 = items["v1"]
    base = f"{ts}.{body_bytes.decode('utf-8')}".encode("utf-8")
    mac = hmac.new(secret.encode("utf-8"), base, hashlib.sha256).hexdigest()
    ok = hmac.compare_digest(mac, v1)
    skew_ok = abs(time.time() - int(ts)) < 300
    return ok and skew_ok
```

---

## 24. Operational runbooks

- Token revocation and forced logout
    
- API brownout enable and disable
    
- Hotfix flow with verification checklist
    
- Webhook replay from DLQ
    
- Regional failover and return
    
- Idempotency store purge and rebuild
    

---

## 25. Artifacts to publish

- OpenAPI per product with security schemes, errors, pagination, webhooks
    
- SDKs for TypeScript, Python, Go generated from OpenAPI
    
- Postman collections and k6 scripts
    
- WAF rule sets and IP list YAML
    
- Terraform or CDK stacks for edge and gateway
    
- Dashboards JSON and alert policies
    

---

## 26. Acceptance criteria

- Load at Pro plan limits for 30 minutes with p95 under SLO
    
- WAF blocks synthetic attacks with no false positives over sample set
    
- Regional failover completes in under 15 minutes in test
    
- Webhook delivery success meets SLO with retries
    
- Idempotency replay works across service restarts
    

---

## 27. Field glossary

- `Tenant-Id`: ULID of tenant. Required
    
- `Correlation-Id`: ULID carried end to end
    
- `Idempotency-Key`: client supplied unique key per write
    
- `traceparent`: W3C trace context header
    

---
