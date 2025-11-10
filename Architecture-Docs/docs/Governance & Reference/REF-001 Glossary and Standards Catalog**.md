
# **REF-001 Glossary and Standards Catalog**

  

Status: Approved

Owner: Architecture Lead

Approvers: Architecture Board

Last updated: 2025-10-28

Applies to: Neurocipher Pipeline, AuditHound, Agent Forge

Related: GOV-001, GOV-002, SEC-001..004, ADR-007, ADR-011, DM-001..005

  

## **1. Purpose**

  

Provide a single canonical source for terms, styles, naming, tagging, regions, formats, and documentation rules. Eliminate ambiguity and enforce consistency across code, data, infrastructure, and docs.

  

## **2. Scope**

  

All repositories, services, data stores, schemas, APIs, events, CI, CD, infrastructure, and documentation in scope.

  

## **3. Glossary**

  

Terms are normative.

- ADR: Architecture Decision Record. Immutable after finalization except status and links.
    
- API Contract: Machine readable spec for a public interface. OpenAPI 3.1.
    
- Artifact: Built, signed, and versioned output promoted between environments. Also known as artifact.
    
- Attestation: Build provenance metadata for Artifact and dependencies.
    
- Availability: Percent of time a service meets SLO targets.
    
- Baseline: Metric window used for canary comparison. Use the last 7 business days during business hours at p50 unless stated.
    
- Business hours: 09:00 to 18:00 America/Toronto, Monday to Friday. Used for baseline calculations.
    
- CAB: Change Advisory Board. Performs release gating.
    


- Canary: Progressive rollout that compares SLIs to baselines before full traffic.
    
- CI: Continuous Integration. Build, test, scan, sign.
    
- CD: Continuous Delivery or Deployment. Promote signed Artifacts with policy gates.
    
- CloudEvents 1.0: Standard event envelope for async messages.
    
- Confidentiality: Protection from unauthorized disclosure.
    
- Data Contract: Schema and rules for APIs, events, and storage. Versioned.
    
- Data Steward: Role owning data quality, lineage, retention, and contracts.
    
- DORA Metrics: Deployment frequency, lead time for changes, change failure rate, mean time to restore.
    
- DR: Disaster Recovery. Procedures to meet RPO and RTO.
    
- Environment: Isolated stage such as Dev, Test, Preprod, Prod.
    
- Feature Flag: Runtime toggle for code or config. Must support a kill switch.
    
- Incident: Unplanned event that degrades service. Categorized by severity.
    
- Integrity: Protection from unauthorized modification.
    
- KMS: Key Management Service for envelope encryption and rotation.
    
- Kill Switch: Flag or config that disables a change without redeploy.
    
- MTTA: Mean time to acknowledge.
    
- MTTD: Mean time to detect.
    
- MTTR: Mean time to recover or repair.
    
- RPO: Recovery point objective. Max tolerable data loss interval.
    
- RTO: Recovery time objective. Max tolerable downtime to restore service.
    
- RFC 7807: Problem Details for HTTP APIs. Error response standard.
    
- SAST/DAST: Static and dynamic security testing.
    
- SBOM: Software bill of materials listing all dependencies.
    
- Sev1..Sev4: Incident severity levels. See GOV-002 table.
    
- SLI: Service level indicator. Measurable metric of performance.
    
- SLO: Service level objective. Target for an SLI with error budget.
    
- SLA: Service level agreement. Contracted commitment to a user.
    
- STRIDE: Threat categories: Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege.
    
- Waiver: Time bound exception with compensating controls. See GOV-001.
    

  

## **4. Naming Standards**

  

### **4.1 Repositories**

- Format: neurocipher-{area}-{service} or audithound-{area}-{service} or agent-forge-{area}-{service}
    
- Case: kebab case. ASCII only. No underscores.
    

  

### **4.2 Services and Packages**

- Runtime service name: svc.{domain}.{service}
    
- Container image: ghcr.io/org/{service}:{semver}
    
- Python package: org_{service} snake case
    
- Node package: @org/{service}
    

  

### **4.3 APIs**

- Base path: /v{major}
    
- Resource paths: kebab case nouns. Example /v1/user-profiles/{user_id}
    
- JSON fields: snake_case
    
- Idempotency key header: Idempotency-Key UUIDv7
    

  

### **4.4 Events**

- Name: domain.service.event.v{major}
    
- Envelope: CloudEvents 1.0
    
- Data schema: JSON Schema 2020-12
    
- Partition key: stable business key
    

  

### **4.5 Data Stores**

- Database: db_{domain}
    
- Schema: sc_{bounded_context}
    
- Tables and columns: snake_case
    
- Primary key: id UUIDv7
    
- Timestamps: created_at, updated_at in UTC, ISO 8601 with Z
    

  

### **4.6 Feature Flags**

- Key: svc.{domain}.{service}.{flag_name}
    
- Environment suffix as needed: dev, test, preprod, prod
    
- Owner tag required
    

  

### **4.7 Branches and Tags**

- Branch: feature/{ticket}-{slug}, fix/{ticket}-{slug}, hotfix/{ticket}-{slug}
    
- Tags: SemVer v{major}.{minor}.{patch}
    

  

### **4.8 Decision Records**

- File: /docs/adr/ADR-{zero_padded_id}.md
    
- Title: imperative and scoped
    
- Link to tickets, PRs, and rollbacks
    

  

## **5. Versioning**

- SemVer for releases. Breaking changes require a major bump.
    
- API version in path. Support N and N-1 at minimum.
    
- Event version in the event name. Never break existing fields. Only add optional fields.
    

  

## **6. Tagging and Metadata**

  

### **6.1 AWS Resource Tags**

| **Key**         | **Example**                             | **Rule**                  |
| --------------- | --------------------------------------- | ------------------------- |
| Name            | svc.reliability.release-runner          | Human label               |
| Project         | Neurocipher or AuditHound or AgentForge | Enum                      |
| Component       | ingest, api, worker, db, queue          | Enum                      |
| Service         | svc.reliability.release-runner          | Matches 4.2               |
| Environment     | dev test preprod prod                   | Enum                      |
| Owner           | team-platform                           | Team slug                 |
| CostCenter      | CC-1001                                 | Finance code              |
| DataClass       | Public Internal Confidential Restricted | See 8                     |
| Confidentiality | Low Medium High                         | CIA rating                |
| Integrity       | Low Medium High                         | CIA rating                |
| Availability    | Low Medium High                         | CIA rating                |
| RPO             | 15m 1h 24h                              | ISO 8601 duration allowed |
| RTO             | 15m 4h 24h                              | ISO 8601 duration allowed |
| SLOTier         | Gold Silver Bronze                      | Maps to SLO set           |
| ADRID           | ADR-0031                                | Latest related ADR        |
| GitSHA          | abc1234                                 | Short commit              |
| PII             | true or false                           | Required for data stores  |

### **6.2 Commit Trailers**

- ADR-ID: ADR-0031
    
- Ticket: PROJ-1234
    
- Change-Type: standard|normal|emergency
    
- Co-authored-by: as needed
    

  

## **7. Environments and Regions**

  

### **7.1 Environments**

- dev: ephemeral and shared
    
- test: integration and contract tests
    
- preprod: production like, final checks
    
- prod: customer traffic
    

  

### **7.2 Regions and Residency**

- Primary AWS region: ca-central-1
    
- DR region: us-east-1
    
- Data with residency constraints stays in Canada unless a signed waiver exists.
    

  

### **7.3 Networking Names**

- VPC: vpc-{project}-{env}
    
- Subnets: sub-{tier}-{az} where tier is public, app, or data
    

  

## **8. Data Classification**

|**Class**|**Definition**|**Examples**|**Controls (minimum)**|
|---|---|---|---|
|Public|Safe for open publication|Public docs|No auth, read only|
|Internal|Non public operational data|Build logs|Auth, TLS, basic RBAC|
|Confidential|Business sensitive or PII|Customer records|Strong RBAC, KMS at rest, audit logs, masked in logs|
|Restricted|Highest sensitivity or regulated|Credentials, keys|HSM or KMS, tight network policy, break glass only, quarterly access review|

- PII and Restricted data cannot be used in non prod without anonymization or synthetic fixtures.
    

  

## **9. Time, Locale, and Units**

- Store times in UTC. Use ISO 8601 with Z suffix.
    
- Display times with user locale as needed.
    
- Currency in minor units with ISO 4217 code.
    
- Distances and temperatures in metric. Celsius for temperature.
    
- Durations use ISO 8601 period format.
    
- Business hours are defined in the glossary.
    

  

## **10. API Standards**

  

### **10.1 Protocol**

- HTTP over TLS 1.2 or higher
    
- JSON only unless an ADR specifies otherwise
    
- Pagination: cursor based via next_cursor
    
- Rate limit headers: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
    

  

### **10.2 Errors**

- Use RFC 7807 Problem Details
    
- Content type application/problem+json
    
- Fields: type, title, status, detail, instance, optional errors[]
    

  

### **10.3 Idempotency**

- Required for POST that creates resources
    
- Header Idempotency-Key with UUIDv7
    
- Server keeps keys for at least 24 hours
    

  

## **11. Event Standards**

- Envelope: CloudEvents 1.0
    
- Transport: HTTP or queue per ADR
    
- Keys: id UUIDv7, source, type, specversion, time, datacontenttype, data
    
- Schema evolution is additive. Remove fields only after an N and N-1 deprecation period.
    

  

## **12. Observability Standards**

  

### **12.1 Logs**

- JSON structured logs
    
- Required keys: ts, level, svc, env, adr_id, release, trace_id, span_id, msg
    
- No PII unless class is Restricted and approved. Mask by default.
    

  

### **12.2 Metrics**

- Naming: svc.{domain}.{service}.{metric}
    
- Types: counter, gauge, histogram
    
- SLI alignment: availability, latency, errors, saturation, and domain correctness
    

  

### **12.3 Tracing**

- W3C Trace Context
    
- Propagate traceparent and tracestate
    

  

## **13. Documentation Style**

- Markdown first. Render in Obsidian and GitHub.
    
- Heading depth limited to H1 to H4.
    
- Use Mermaid for diagrams.
    
- English, active voice, present tense.
    
- No em dashes.
    
- Code fences for samples.
    
- One concept per file. Link with relative paths.
    
- File naming: AREA-NNN Title.md with spaces allowed after numeric code.
    

  

### **13.1 Required Sections per Spec**

- Status, Owner, Approvers, Last updated, Applies to, Related
    
- Purpose, Scope, References
    
- Normative requirements as bullet rules
    

  

## **14. Templates and Locations**

- STRIDE checklist: /docs/security/templates/stride-checklist.md
    
- IAM diff: /docs/security/templates/iam-diff.md
    
- Secrets rotation playbook: /docs/security/templates/secrets-rotation.md
    
- Data contract change: /docs/data/templates/contract-change.md
    
- Schema migration plan: /docs/data/templates/migration-plan.md
    
- SLO sheet: /docs/reliability/templates/slo.md
    
- Observability plan: /docs/observability/templates/plan.md
    
- Cost estimate: /docs/cost/templates/estimate.md
    
- Canary plan: /docs/release/templates/canary.md
    
- Rollback plan: /docs/release/templates/rollback.md
    
- Release ticket: /docs/release/templates/release-ticket.md
    
- Incident report: /docs/ops/templates/incident.md
    
- ADR: /docs/governance/templates/adr.md
    
- Meeting agenda: /docs/governance/templates/agenda.md
    
- Meeting minutes: /docs/governance/templates/minutes.md
    
- Standard change catalog: /docs/release/standard-change-catalog.md
    
- Evidence export location: s3://org-audit/releases/{yyyy}/{mm}/
    

  

## **15. Examples**

  

### **15.1 API Error**

```
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{
  "type": "https://docs.example.com/errors/conflict",
  "title": "Conflict",
  "status": 409,
  "detail": "user_id already exists",
  "instance": "/v1/user-profiles/u_123"
}
```

### **15.2 Event Envelope**

```
{
  "id": "018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a",
  "source": "svc.identity.user",
  "type": "identity.user.created.v1",
  "specversion": "1.0",
  "time": "2025-10-28T18:00:00Z",
  "datacontenttype": "application/json",
  "data": {
    "user_id": "u_123",
    "email": "redacted"
  }
}
```

### **15.3 Resource Tags JSON**

```
{
  "Name": "svc.identity.api",
  "Project": "Neurocipher",
  "Component": "api",
  "Service": "svc.identity.api",
  "Environment": "prod",
  "Owner": "team-platform",
  "CostCenter": "CC-1001",
  "DataClass": "Confidential",
  "Confidentiality": "High",
  "Integrity": "High",
  "Availability": "High",
  "RPO": "PT15M",
  "RTO": "PT4H",
  "SLOTier": "Gold",
  "ADRID": "ADR-0031",
  "GitSHA": "abc1234",
  "PII": "true"
}
```

## **16. Validation Checklist**

- Terms in GOV-001 and GOV-002 match this glossary.
    
- All template paths resolve.
    
- Region and residency rules align with security and reliability docs.
    
- Logging keys present in all services.
    
- API errors conform to RFC 7807.
    
- Events conform to CloudEvents 1.0.
    
- Baseline phrase is exact and references business hours.
    

  

## **17. Change Control**

- Changes to this document require an ADR and GOV-001 gates.
    
- Minor term additions can ship as a Standard change when they do not alter policy.
    
- Severity, SLO, RPO, and RTO definitions must remain consistent with GOV-002 and reliability docs.
    

  

## **18. Appendices**

  

### **18.1 Regex Reference**

- ADR file: ^ADR-\d{3,5}\.md$
    
- SemVer tag: ^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$
    
- UUIDv7 (simplified): ^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$
    

  

### **18.2 Mermaid Diagram Snippet**

```
flowchart TD
  A[Client] --> B(API v1)
  B --> C{AuthZ}
  C -->|allow| D[Service]
  D --> E[(DB)]
  C -->|deny| F[Problem JSON 403]
```

