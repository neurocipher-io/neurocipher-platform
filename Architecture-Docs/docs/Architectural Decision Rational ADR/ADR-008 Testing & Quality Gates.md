  

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