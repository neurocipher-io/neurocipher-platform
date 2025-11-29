---
id: ARCH-BLUEPRINT-001
title: System Architecture Blueprint
owner: Architecture Lead
status: Existing
last_reviewed: 2025-11-29
---

# Neurocipher Data Pipeline — System Architecture Blueprint

## 1. High level

```
  

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

  N --> PGMeta[(Postgres metadata)]

  N --> E[SQS embed]

  

  E --> WU[Embed Worker on Fargate]

  WU --> WV[(Weaviate vectors)]

  WU --> OS[(OpenSearch index)]

  WU --> PGMeta

  

  subgraph Query tier

    API[FastAPI on Fargate]

    API --> WV

    API --> OS

    API --> PGMeta

  end

  

  U[Clients] --> API
```

  

2. Network and security

  

```
flowchart TB

  subgraph VPC

    subgraph Private subnets

      F1[Fargate services]

      L1[Lambda]

      EP1[VPCE S3]

      EP2[VPCE Secrets]

      EP3[VPCE Dynamo]

    end

    subgraph Isolated data

      S3R[(S3 raw)]

      S3N[(S3 norm)]

      PGMeta[(Postgres metadata)]

      WV[(Weaviate)]

      OS[(OpenSearch Srvless)]

    end

  end

  I[API Gateway or ALB TLS] --> F1

  IAM[OIDC GitHub Actions] -. deploy .-> AWS[Accounts dev stg prod]

```
  

- Private subnets only. No public IPs on services.
- Ingress via ALB or API Gateway with TLS 1.2+.
- Secrets in Secrets Manager. KMS per environment.
- IAM roles per service. GitHub Actions uses OIDC assume role.

  

  

  

3. Data flow

  

```
sequenceDiagram

  participant Src as Source

  participant SQS as SQS ingest

  participant Norm as Normalize Lambda

  participant S3 as S3 raw/norm

  participant PGMeta as Postgres metadata

  participant EMB as Embed Worker

  participant W as Weaviate

  participant OS as OpenSearch

  participant API as Query API

  

  Src->>SQS: Enqueue event

  SQS->>Norm: Batch receive

  Norm->>S3: Write raw + normalized

  Norm->>PGMeta: Upsert metadata

  Norm->>SQS: Enqueue embed task

  SQS->>EMB: Batch tasks

  EMB->>W: Upsert vectors

  EMB->>OS: Upsert keywords

  API->>W: Vector search

  API->>OS: Keyword search

  API->>API: Fuse results RRF

  API-->>Client: Response

  

```
4. Storage model

  

  

- S3 raw: s3://nc-dp-raw/{source}/{y}/{m}/{d}/{uuid}.bin
- S3 normalized: s3://nc-dp-norm/{entity}/{version}/{uuid}.json
- DynamoDB documents:  
    

- PK: DOC#{doc_id}
- SK: VER#{schema_version}
- GSI1: SOURCE#{source}#DATE#{yyyymmdd}
- Fields: checksum, mime, pii_flags, policy, timestamps

-   
    
- Weaviate:  
    

- Class per modality: TextDoc, ImageDoc, AudioDoc
- Vectorizer external. Shards by doc_id hash.

-   
    
- OpenSearch:  
    

- Index per entity type with ILM. BM25. Keyword and filters.

-   
    

  

  

  

5. Services

  

  

- ingest  
    

- Webhook handlers. API pulls via Step Functions.
- Writes to SQS ingest.

-   
    
- normalize  
    

- MIME router. Parsers. PII detect and tokenize.
- Emits S3 normalized and metadata.

-   
    
- embed  
    

- Batch text and media. Calls embedding model.
- Upserts to Weaviate and OpenSearch.

-   
    
- api  
    

- Endpoints: /query, /ingest, /admin, /health
- Query fusion and filtering.

-   
    
- batch  
    

- Reindex, backfill, migrations, DR drills.

-   
    

  

  

  

6. Scaling and resiliency

  

  

- Lambda scales on SQS depth.
- Fargate service autoscaling on CPU, memory, and queue age.
- DLQs for ingest and embed queues.
- S3 versioning. DynamoDB PITR. Weaviate nightly snapshot.
- Cross region replication for S3 and backups.

  

  

  

7. Observability

  

  

- CloudWatch Logs JSON.
- X-Ray traces across hops.
- Metrics: ingest rate, queue age, normalize p95, embed p95, upsert errors, query p95.
- Alerts: DLQ growth, queue age over SLO, API 5xx, Weaviate health fail, OpenSearch red.

  

  

  

8. API surface

  

  

- POST /ingest/event  
    

- Auth: SigV4 or JWT. Body: source payload.

-   
    
- GET /query  
    

- Params: q, filters, top_k, mode in {hybrid, vector, keyword}.

-   
    
- POST /admin/reindex  
    

- Auth: admin role only.

-   
    
- GET /health  
    

- Liveness and dependency checks.

-   
    

  

  

  

9. IAM summary

  

  

- Role dp-ingest-exec: SQS SendMessage, CloudWatch logs.
- Role dp-normalize-exec: S3 PutObject, Postgres metadata insert/upsert, SQS SendMessage, KMS Decrypt.
- Role dp-embed-exec: Weaviate API, OpenSearch write, Postgres metadata update, S3 GetObject.
- Role dp-api-exec: Weaviate query, OpenSearch query, Postgres metadata query, limited S3 GetObject.

  

  

  

10. Infra modules

  

  

- vpc with three AZs.
- s3_buckets raw and normalized with lifecycle rules.
- sqs ingest and embed with DLQs.
- ecs_services api and embed workers.
- lambda_normalize with reserved concurrency.
- weaviate_cluster on EC2 or managed.
- opensearch_serverless collections.
- observability dashboards and alarms.

  

  

  

11. Deployment topology

  

  

- Three AWS accounts: nc-dp-dev, nc-dp-stg, nc-dp-prod.
- Terragrunt per env.
- Preview stacks per PR in dev with short TTL.

  

  

  

12. Failure modes and handling

  

  

- Parser failure: send to DLQ with sample payload.
- Embed backlog: autoscale and raise alert if age exceeds SLO.
- Weaviate outage: queue writes, serve keyword only with warning flag.
- OpenSearch partial failure: serve vector only with degraded flag.
- Schema break: block deploy via contract tests. Provide migrators.
