# Document ID: PROC-003
**Title:** Embedding & Indexing Job Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Pipeline Engineering  
**Applies to:** Neurocipher Core Data Pipeline  
**Last Reviewed:** 2025-11-08  
**References:** ING-001–003, DCON-001, DM-001–005, SRG-001, LAK-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the standardized, reproducible job for chunking, embedding, and indexing documents for hybrid retrieval. Ensures deterministic chunking, model-governed embeddings, contract-safe metadata, and idempotent upserts to Weaviate and OpenSearch.

---

## 2. Scope
**In scope:** Chunking, embedding generation, vector upserts, keyword indexing, hybrid rank fusion artifacts, verification, and lineage.  
**Out of scope:** Model training and fine‑tuning; bulk schema migrations unrelated to embeddings (see PROC-001).

---

## 3. Inputs and Triggers
| Input Type | Description | Source | Validation |
|-------------|-------------|--------|-----------|
| **Normalized Docs** | Canonical records with rich metadata | PROC-001 / PROC-002 outputs | DCON-001 contract check |
| **Embedding Config** | Model, batch size, max tokens, class suffix | SSM Parameter Store | SRG-001 config schema |
| **Job Manifest** | S3 URIs or query spec for reindex/backfill | LAK-001 data lake | SHA-256 digest + schema |
| **Triggers** | Scheduled, manual change ticket, or stream branch | Step Functions / SQS | Audit trail recorded in ledger |

All records must include `{tenant, source_urn, content_hash, mime, tokens, retention_class, schema_urn, version}`.

---

## 4. Architecture
**Pattern:** Fan‑out embedding workers with idempotent writers and parallel keyword indexing.

| Layer | Component | Standard |
|------|-----------|----------|
| **Orchestration** | AWS Step Functions or ECS workflow | CI/CL-001 |
| **Workers** | ECS Fargate containers; optional GPU node group if model requires | CI/CL-002 |
| **Queues** | SQS batches with visibility tuned to batch size | OBS-001 |
| **Vector Store** | Weaviate multi‑tenant or per‑tenant classes | DM-004 |
| **Keyword Store** | OpenSearch indices `embeddings-<env>-v{n}` | DM-004 |
| **Object Store** | S3 `s3://nc-<env>-embeddings/<class>/yyyy/mm/dd/` | LAK-001 |
| **Metadata** | DynamoDB `embedding_jobs`, `embedding_batches` | DM-003 |
| **Observability** | ADOT + Prometheus + Grafana + AMP | OBS-002/003 |

---

## 5. Execution Flow
1. **Plan:** Resolve manifest → compute work shards → register run in `embedding_jobs`.  
2. **Chunk:** Deterministic splitter by MIME and token budget; assign `document_chunk_id`.  
3. **Embed:** Select model by modality; batch process; capture `embedding_model`, `model_digest`, `embedding_dim`.  
4. **Write Vectors:** Upsert to Weaviate using key `{tenant, document_chunk_id, content_hash}`; write raw artifact to S3.  
5. **Keyword Index:** Optional write to OpenSearch for hybrid retrieval.  
6. **Verify:** Random sample cosine checks, upsert/read parity, index health, and class cardinality.  
7. **Finalize:** Emit lineage event; update run ledger; publish metrics and evidence pack.

---

## 6. Contracts, Classes, and Versioning
- **Class naming:** `NcChunkV{n}` where `n` increases on incompatible changes.  
- **Dual‑read window:** When bumping class, enable dual read/write until backfill complete.  
- **Registry:** All class schemas and config registered in SRG-001 with content digest.  
- **Compatibility levels:** `NONE`, `BACKWARD`, `FORWARD`, `FULL` per DCON-001; rollout plan required for `NONE`.

---

## 7. IAM and Security Controls
| Domain | Implementation |
|--------|----------------|
| **AuthN** | GitHub OIDC for deploy; ECS task roles for runtime |
| **AuthZ** | Least privilege per target store; ABAC by tenant and environment |
| **Secrets** | Secrets Manager for API keys; SSM for non‑secret params |
| **Encryption** | TLS 1.3 in transit; KMS at rest on S3/Weaviate/OpenSearch/RDS |
| **Logging** | No PII or raw tokens; hash or drop sensitive fields |
| **Audit** | CloudTrail + DynamoDB run ledger with correlation IDs |

---

## 8. Observability and SLOs
| Metric | Target | Source |
|--------|--------|--------|
| Vector Write Latency (p95) | ≤ 1.0 s per upsert | Prometheus / Weaviate exporter |
| Hybrid Query Latency (p95) | ≤ 200 ms | OpenSearch + application metrics |
| Batch Error Rate | < 1% | Worker metrics |
| DLQ Depth | 0 | SQS metrics |
| Embedding Throughput | ≥ 1,000 chunks/min (env‑dependent) | ECS metrics |

Dashboards show golden signals plus `embedding_batches_total`, `vector_write_latency_ms`, `index_errors_total`, and deployment markers. Alert catalog as per OBS-003.

---

## 9. Failure Handling and Rollback
- **Retries:** Exponential backoff; max 5 attempts per shard.  
- **DLQ:** Poison batch stored with compact payload and `correlation_id`.  
- **Rollback:** Revert index writes via `embedding_ref` delete after downstream delete to avoid orphans; S3 versioning for raw artifacts.  
- **Rebuild:** Use manifest to re‑embed affected ranges; idempotent keys ensure safe replays.

---

## 10. CI/CD and Promotion
- **CI (CI/CL-001):** Lint, unit tests, contract diff, container/IaC scans, SBOM, provenance, signature verification.  
- **CD (CI/CL-002):** GitHub Actions → ECS blue/green; deploy by digest only.  
- **Change Control (CI/CL-003):** CAB review required for model swap, class bump, or chunker change; evidence attached to ticket.

---

## 11. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|------|----------|----------|
| S3 Embedding Artifacts | LAK-001 | Versioned, 7‑year retention |
| Weaviate Classes | DM-004 | RC2 2‑year retention |
| OpenSearch Indices | DM-004 | ILM warm rollover at 30 days |
| Job Ledgers | DM-003 | PITR 7 days |
| Registry Entries | SRG-001 | Immutable digest‑pinned |
| Lineage | LIN-001 | 30‑day window |

---

## 12. Acceptance Criteria
1. Zero contract violations and zero DLQ growth for a representative run.  
2. Vector write p95 and hybrid query p95 within SLO for the bake window.  
3. Evidence pack attached: metrics, logs, lineage, SBOM, model digest, sample cosine checks.  
4. Dual‑read successful during class bump; no orphaned refs detected.  
5. Ledger reflects accurate start/stop and `"SUCCEEDED"` status.

---

## 13. Change Log
| Version | Date | Description | Author |
|---------|------|-------------|-------|
| 1.0 | 2025-11-08 | Initial board‑ready release validated against REF‑001 standards | Data Platform Lead |

---

## Appendix A — Example ECS Task Definition (Embedding Worker)
```json
{
  "family": "proc-003-embed-worker",
  "networkMode": "awsvpc",
  "cpu": "2048",
  "memory": "4096",
  "requiresCompatibilities": ["FARGATE"],
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/proc003-embed-task",
  "containerDefinitions": [
    {
      "name": "worker",
      "image": "<ECR_URI>@sha256:<digest>",
      "essential": true,
      "environment": [
        {"name":"EMBED_MODEL","value":"text-embedding-3-large"},
        {"name":"BATCH_SIZE","value":"128"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/proc-003",
          "awslogs-region": "ca-central-1",
          "awslogs-stream-prefix": "worker"
        }
      }
    }
  ]
}
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Embedding Indexing Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'proc/embedding/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-oidc-deploy
          aws-region: ca-central-1

      - name: Register Task Definition
        run: |
          aws ecs register-task-definition             --cli-input-json file://proc/embedding/ecs-task.json

      - name: Update Service
        run: |
          aws ecs update-service             --cluster nc-core-embed-cluster             --service proc-003-embedding             --force-new-deployment

      - name: Register Deployment
        run: echo "PROC-003 deployment complete"
```
