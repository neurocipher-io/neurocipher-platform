

# Neurocipher Data Pipeline — Architecture

  

## 1. Overview

Foundation for AWS native ingestion, normalization, embeddings, and hybrid retrieval. No shared code or schema with Nexis.

  

### Goals

- Unify inputs. Normalize and secure data. Generate embeddings. Serve hybrid search.

- Operate in private subnets. Zero standing credentials. Full observability.

  

### Non goals

- Nexis integration.

- On prem support in v1.

  

---

  

## 2. High level diagram

```mermaid

flowchart LR

  subgraph Sources

    A[Files S3 drop]

    B[Webhooks]

    C[API pulls]

    D[DB dumps]

  end

  

  A --> Q[SQS ingest]

  B --> Q

  C --> Q

  D --> Q

  

  Q --> N[Normalize Lambda]

  N --> S3R[(S3 raw)]

  N --> S3N[(S3 normalized)]

  N --> DDB[(DynamoDB metadata)]

  N --> E[SQS embed]

  

  E --> WU[Embed Worker on Fargate]

  WU --> WV[(Weaviate vectors)]

  WU --> OS[(OpenSearch index)]

  WU --> DDB

  

  subgraph Query tier

    API[FastAPI on Fargate]

    API --> WV

    API --> OS

    API --> DDB

  end

  

  U[Clients] --> API

  

  

  

  

3. Network and security

  

flowchart TB

  subgraph VPC

    subgraph Private subnets

      F1[Fargate services]

      L1[Lambda]

      EP1[VPCE S3]

      EP2[VPCE Secrets]

      EP3[VPCE Dynamo]

    end

    subgraph Data planes

      S3R[(S3 raw)]

      S3N[(S3 norm)]

      DDB[(DynamoDB)]

      WV[(Weaviate)]

      OS[(OpenSearch Srvless)]

    end

  end

  I[ALB or API Gateway TLS] --> F1

  IAM[GitHub OIDC] -. assume role .-> AWS[Accounts dev stg prod]

  

- Private subnets only. No public IP on services.
- TLS 1.2 plus. Secrets in Secrets Manager. KMS per environment.
- IAM roles per service. GitHub Actions uses OIDC.

  

  

  

  

  

4. Data flow sequence

  

sequenceDiagram

  participant Src as Source

  participant SQS as SQS ingest

  participant Norm as Normalize Lambda

  participant S3 as S3 raw and norm

  participant DDB as DynamoDB meta

  participant EMB as Embed Worker

  participant W as Weaviate

  participant OS as OpenSearch

  participant API as Query API

  

  Src->>SQS: Enqueue event

  SQS->>Norm: Batch receive

  Norm->>S3: Write raw and normalized

  Norm->>DDB: Upsert metadata

  Norm->>SQS: Enqueue embed task

  SQS->>EMB: Batch tasks

  EMB->>W: Upsert vectors

  EMB->>OS: Upsert keywords

  API->>W: Vector search

  API->>OS: Keyword search

  API->>API: Fuse results via RRF

  API-->>Client: Response

  

  

  

  

5. Storage model

  

  

S3 raw: s3://nc-dp-raw/{source}/{y}/{m}/{d}/{uuid}.bin

S3 normalized: s3://nc-dp-norm/{entity}/{version}/{uuid}.json

  

DynamoDB table documents

  

- PK: DOC#{doc_id}
- SK: VER#{schema_version}
- GSI1: SOURCE#{source}#DATE#{yyyymmdd}
- Fields: checksum, mime, pii_flags, policy, timestamps

  

  

Weaviate

  

- Classes: TextDoc, ImageDoc, AudioDoc
- External vectorizer. Shards by doc_id hash

  

  

OpenSearch

  

- Index per entity
- ILM enabled
- BM25 for keyword and filters

  

  

  

  

  

6. Services

  

  

ingest

  

- Webhook handlers
- API pulls via Step Functions
- Writes to SQS ingest

  

  

normalize

  

- MIME router and parsers
- PII detect and tokenize
- Emit S3 normalized and metadata

  

  

embed

  

- Batch text and media
- Call embedding model
- Upsert Weaviate and OpenSearch

  

  

api

  

- Endpoints: /query, /ingest, /admin, /health
- Hybrid fusion and filters

  

  

batch

  

- Reindex, backfill, migrations, DR drills

  

  

  

  

  

7. API surface

  

  

- POST /ingest/event  
    Auth SigV4 or JWT. Body source payload
- GET /query  
    Params q, filters, top_k, mode in {hybrid, vector, keyword}
- POST /admin/reindex  
    Admin only
- GET /health  
    Liveness and dependency checks

  

  

  

  

  

8. Scaling and resiliency

  

  

- Lambda scales on SQS depth
- Fargate autoscaling on CPU, memory, and queue age
- DLQs for ingest and embed
- S3 versioning. DynamoDB PITR
- Weaviate nightly snapshot
- Cross region replication for S3 and backups

  

  

  

  

  

9. Observability

  

  

- CloudWatch Logs JSON
- AWS X Ray for traces
- Grafana dashboards
- Metrics: ingest rate, queue age, normalize p95, embed p95, upsert errors, query p95
- Alerts: DLQ growth, queue age over SLO, API 5xx, Weaviate health fail, OpenSearch red

  

  

  

  

  

10. IAM summary

  

  

- dp-ingest-exec: SQS SendMessage, logs
- dp-normalize-exec: S3 PutObject, DDB PutItem, SQS SendMessage, KMS Decrypt
- dp-embed-exec: Weaviate write, OpenSearch write, DDB UpdateItem, S3 GetObject
- dp-api-exec: Weaviate query, OpenSearch query, DDB Query, limited S3 GetObject

  

  

  

  

  

11. Terraform modules

  

  

- vpc three AZs
- s3_buckets raw and normalized with lifecycle
- sqs ingest and embed with DLQs
- ecs_services api and embed workers
- lambda_normalize with reserved concurrency
- weaviate_cluster EC2 or managed
- opensearch_serverless collections
- observability dashboards and alarms
- backup cross region replication and snapshots

  

  

  

  

  

12. Bill of materials

  

  

Compute

  

- AWS Lambda
- AWS Fargate on ECS

  

  

Storage and data

  

- S3 raw and normalized
- DynamoDB on demand
- Weaviate cluster
- OpenSearch Serverless

  

  

Messaging and orchestration

  

- SQS standard with DLQs
- EventBridge
- Step Functions for pulls and batch

  

  

Security

  

- IAM roles per service
- KMS keys per environment
- Secrets Manager
- VPC endpoints for S3 and Secrets

  

  

Edge and ingress

  

- ALB or API Gateway
- Route 53
- ACM certificates

  

  

CI CD

  

- GitHub Actions with OIDC
- Terraform plus Terragrunt
- Trivy and CodeQL
- SBOM and provenance

  

  

Observability

  

- CloudWatch Logs, Metrics, Alarms
- AWS X Ray
- Managed Grafana

  

  

  

  

  

13. SLOs

  

  

- Ingest end to end p95 ≤ 5 minutes streaming
- Query p95 ≤ 300 ms cached, ≤ 900 ms uncached hybrid
- Recall at 10 ≥ 0.9 on golden set
- Error budget 1 percent monthly

  

  

  

  

  

14. Failure modes and handling

  

  

- Parser failure → DLQ with sample payload and trace id
- Embed backlog → autoscale and alert if age exceeds SLO
- Weaviate outage → queue writes and serve keyword only with degraded flag
- OpenSearch partial failure → serve vector only with degraded flag
- Schema break → block deploy via contract tests and run migrator

  

  

  

  

  

15. References

  

  

- ADR 001 to 010 in ADRS/
- OpenAPI at repo root
- Runbooks under docs/runbooks/
- Dashboards under ops/dashboards/