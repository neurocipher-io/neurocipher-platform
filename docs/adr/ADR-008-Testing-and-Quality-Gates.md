id: ADR-008
title: Testing and Quality Gates
owner: QA Lead
status: Accepted
last_reviewed: 2025-10-23

ADR-008 Testing and Quality Gates

  

  

- Status: Accepted
- Date: 2025-10-23
- Owners: QA Lead

  

  

  

Context

  

  

Complex data pipelines require reproducible test stages to ensure schema stability, performance, and search quality.

  

  

Decision

  

  

Define mandatory test gates in CI/CD.

  

- Unit: ≥ 85 % coverage.
- Contract: schema validation before build.
- Integration: SQS, S3, Dynamo, Weaviate mocks.
- End-to-End: deployed preview environment.
- Load: synthetic ingest with loadgen tool.
- Relevance: golden query set measuring recall@10.

  

  

  

Alternatives

  

  

1. Manual regression runs only.
2. Vendor-hosted test harness.

  

  

Rejected for unreliability or cost.

  

  

Consequences

  

  

- Prevents regressions.
- Adds compute time to CI.
- Guarantees production data fidelity.

## Acceptance Criteria

- CI pipelines enforce a minimum unit test coverage threshold (≥ 85 %) for in-scope services and fail builds that fall below this threshold.
- Contract tests (schema validation) run before build/package steps and block promotion when breaking changes are detected without appropriate versioning and migrators.
- Integration tests covering SQS, S3, DynamoDB, Weaviate, and other critical dependencies are executed in CI or dedicated test environments for core services.
- End-to-end, load, and relevance tests (as defined in TEST-00x and PERF-00x) are run against preview or staging environments before promoting to production.
- The set of mandatory gates and thresholds is documented in CI-001..003 and TEST-001..003 and kept in sync with this ADR.
