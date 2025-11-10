1. Scope and objectives

  

  

- Build the AWS-native ingestion and vectorization backbone for Neurocipher.
- Inputs: files, APIs, webhooks, logs, DB dumps.
- Outputs: normalized objects, embeddings, metadata, search APIs.

  

  

  

2. Success criteria

  

  

- Ingest ≥ 1M objects per day with backpressure control.
- P95 end-to-end latency ≤ 5 minutes for streaming sources.
- Search recall@10 ≥ 0.9 on golden set.
- Zero plaintext secrets in repo. SBOM produced for builds.
- One-click deploy to dev and staging. Change-tracked data contracts.

  

  

  

3. Deliverables

  

  

- Monorepo with IaC, services, libs, runbooks.
- ADRs 001-010.
- Data Contracts v1 (JSON Schema + examples).
- Golden dataset + evaluation scripts.
- Dashboards, alerts, SLOs.
- API reference (OpenAPI) and Postman collection.

  

  

  

4. Tech baseline

  

  

- AWS: S3, Lambda, Fargate, SQS, EventBridge, Step Functions, DynamoDB, OpenSearch Serverless, ECR, KMS, IAM, CloudWatch.
- Vector DB: Weaviate (AWS EC2/EKS or Weaviate Cloud on AWS).
- Build: GitHub Actions, OIDC to AWS, CodeQL, Trivy.
- IaC: Terraform + Terragrunt.
- Runtime: Python 3.11, FastAPI, pydantic, uv.
- Packaging: Poetry. Containers: distroless base.

  

  

  

5. Repository layout

  

neurocipher-data-pipeline/

  ADRS/

    ADR-001-architecture.md

  docs/

    api/

    runbooks/

  infra/

    terragrunt.hcl

    envs/           # dev, stg, prod

    modules/        # vpc, weaviate, opensearch, ecs, s3, sqs

  services/

    ingest/         # connectors, webhooks

    normalize/      # parsers, schema mapping

    embed/          # embedding workers

    index/          # Weaviate + OpenSearch writers

    api/            # query + admin APIs (FastAPI)

    batch/          # Step Functions jobs

  libs/

    contracts/      # JSON Schemas + validators

    common/         # logging, tracing, auth, errors

  ops/

    pipelines/      # GitHub Actions workflows

    dashboards/     # grafana/json

    alerts/         # cloudwatch alarms

  tests/

    e2e/

    perf/

  tools/

    loadgen/

    eval/

  .github/

    workflows/

  Makefile

  pyproject.toml

  openapi.yaml

  CODEOWNERS

  SECURITY.md

  CONTRIBUTING.md

  README.md

  

6. Branching and release

  

  

- Main: protected. Release via tags vX.Y.Z.
- Dev flow: feature/* → PR → main.
- Hotfix: hotfix/* → PR → main → tag.

  

  

  

7. Environments

  

  

- dev: ephemeral per PR using preview stacks.
- stg: shared, production-like data shape.
- prod: dedicated account. Manual approval only.

  

  

  

8. Secrets and identity

  

  

- GitHub OIDC to AWS. No long-lived keys.
- Secrets in AWS Secrets Manager. Inject at runtime.
- KMS keys per env. Separate key for embeddings buckets.

  

  

  

9. Data contracts

  

  

- JSON Schema per entity. Versioned with semver.
- Breaking changes require new version + migrator.
- Contract tests block deploys on mismatch.

  

  

  

10. Ingestion policy

  

  

- Sources: S3 drops, HTTPS webhooks, API pulls, DB snapshots.
- All events go through SQS. Dead letters with retention 14 days.
- Idempotency key = source_id + content_hash.

  

  

  

11. Normalization

  

  

- Parser per MIME type. Output to canonical schema.
- PII detection with detectors library. Redact or tokenize per policy.

  

  

  

12. Embeddings

  

  

- Model selector by modality and token budget.
- Store vectors in Weaviate. Store raw in S3. Store metadata in DynamoDB.
- Batch size and concurrency controlled by SQS visibility.

  

  

  

13. Indexing and retrieval

  

  

- Weaviate for vector search. OpenSearch for keyword and aggregations.
- Hybrid ranker: BM25 + vector with reciprocal rank fusion.
- API: /query, /ingest, /admin, /health.

  

  

  

14. Observability

  

  

- Structured logs (JSON). Trace with AWS X-Ray.
- Dashboards: ingest rate, queue depth, error rate, p95 latency, vector upserts.
- Alerts: SQS age, DLQ growth, 5xx rate, embedding lag, Weaviate health.

  

  

  

15. Security

  

  

- Least privilege IAM per service.
- Private subnets. VPC endpoints for S3 and Secrets Manager.
- TLS everywhere. Signed URLs for S3 access.
- Supply chain: lockfiles, provenance attestations, Trivy scan.

  

  

  

16. Performance targets

  

  

- Ingest workers autoscale on SQS depth.
- Embed throughput ≥ 2k docs/min in dev target.
- Query p95 ≤ 300 ms for cached, ≤ 900 ms uncached hybrid.

  

  

  

17. Testing

  

  

- Unit, contract, integration, e2e, load.
- Golden set for relevance with fixed queries and expected hits.
- Canary on stg before prod.

  

  

  

18. CI/CD workflow order

  

  

19. Lint, type check, unit tests.
20. Contract diff and schema validation.
21. Build containers. SBOM + scan.
22. Deploy preview stack. Run e2e.
23. Promote to stg with manual gate.
24. Run load and relevance tests.
25. Manual approval to prod.

  

  

  

26. Operational runbooks

  

  

- Queue backlog recovery.
- Reindex vectors.
- Rotate keys and secrets.
- Rollback procedure for bad schema.
- DLQ triage and replay.

  

  

  

20. Definition of done

  

  

- Code, tests, docs merged.
- Dashboards and alerts in place.
- Runbooks written.
- OpenAPI updated and published.
- Stg pass on load and relevance.
- Tag released and artifact immutability verified.

  

  

  

21. Initial milestone plan

  

  

- M1: Repo, IaC skeleton, VPC, CI bootstrap.
- M2: S3 ingest, SQS, normalization service, contracts v1.
- M3: Weaviate deploy, embed worker, indexer.
- M4: Query API, hybrid search, golden set + eval.
- M5: Observability, SLOs, alerts, runbooks.
- M6: Hardening, perf tuning, prod cutover.

  

  

  

22. Make targets (starter)

  

make init          # bootstrap dev env

make fmt           # format + lint

make test          # run unit + contract

make build         # container build + scan

make deploy-dev    # deploy preview

make e2e           # run end-to-end tests

make loadgen       # synthetic ingest

make eval          # relevance evaluation

  

23. Coding standards

  

  

- PEP 8, type hints required. mypy strict.
- pydantic models for all IO.
- No print. Use structured logger.

  

  

  

24. API governance

  

  

- OpenAPI as source of truth.
- Backward compatibility enforced by contract tests.
- Rate limits and auth via JWT or IAM SigV4 per endpoint class.

  

  

  

25. Non-goals

  

  

- No Nexis integration.
- No desktop clients.
- No on-prem support in v1.

  

  

If you want, I can generate ADR-001 to ADR-004 next.