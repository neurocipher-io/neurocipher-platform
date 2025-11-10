# Document ID: LIN-001
**Title:** Data Lineage and Catalog Specification  
**Status:** Final v1.0  
**Owner:** Data Platform Lead / Governance Engineering  
**Applies to:** Neurocipher Core and AuditHound Module  
**Last Reviewed:** 2025-11-09  
**References:** ING-001–003, PROC-001–003, DM-001–005, DCON-001, SRG-001, LAK-001, DQ-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the unified, cross-platform data lineage and catalog framework used to track, audit, and visualize data asset flows across all ingestion, processing, and serving layers.  
Provides end-to-end visibility of schema evolution, data dependencies, transformations, and quality lineage to meet operational, compliance, and audit requirements.

---

## 2. Scope
**In scope:**  
- Automated capture of column-level and dataset-level lineage across **ING**, **PROC**, and **DM** pipelines.  
- Cataloging of assets, schemas, contracts, and data-quality metadata per **DQ-001**.  
- Integration with observability stack for cross-reference of quality, performance, and lineage signals.  
- Supports compliance requirements under **GOV-002** (SOC 2 Type II, retention, auditability).  

**Out of scope:**  
- Business glossary or data governance workflow automation (covered under future GOV-003).  

---

## 3. Lineage Model Overview
Lineage is modeled as a **directed acyclic graph (DAG)** linking datasets, transformations, and assets across systems.

| Entity | Description | Source of Record |
|---------|--------------|------------------|
| **Dataset** | Logical data collection within Iceberg, Weaviate, or RDS | LAK-001 |
| **Schema Contract** | JSON Schema defining dataset structure | DCON-001 / SRG-001 |
| **Transformation** | Batch or stream process altering data state | PROC-001–003 |
| **Quality Event** | Validation or anomaly trigger per DQ-001 | DQ-001 |
| **Catalog Entry** | Metadata record with ownership, retention, and lineage refs | LIN-001 |
| **Asset Version** | Immutable version with timestamp, digest, and lineage refs | DM-003 / DM-005 |

Each entity emits lineage metadata in JSON format with deterministic identifiers (`urn:nc:<entity>:<uuidv7>`).

---

## 4. Architecture
**Pattern:** Event-driven lineage tracking and metadata catalog built on serverless AWS primitives and synchronized with schema and quality registries.

| Layer | Component | Standard |
|--------|------------|----------|
| **Event Sources** | ING/PROC/DQ job completions emitting lineage payloads | CI/CL-001 hooks |
| **Ingestion Bus** | EventBridge bus `nc-<env>-lineage-bus` | GOV-002 |
| **Storage Layer** | DynamoDB `lineage_graph`, S3 `s3://nc-<env>-lineage-logs/` | LAK-001 |
| **Catalog API** | Lambda / FastAPI microservice with REST + GraphQL endpoints | CI/CL-002 |
| **Visualization** | OpenMetadata UI / custom Grafana panels | OBS-002 |
| **Registry Sync** | Nightly Lambda job syncing SRG-001, DCON-001, DQ-001 metadata | CI/CL-003 |

All services are provisioned using IaC and validated by automated governance checks during pipeline deployment.

---

## 5. Execution Flow
1. **Emit Lineage Event:** Each job (`ING-`, `PROC-`, or `DQ-`) emits a `lineage_event.json` including:  
   `source_urn`, `target_urn`, `schema_digest`, `contract_version`, `dq_result_id`, and `run_id`.  
2. **Ingest to EventBridge:** Event logged to `nc-<env>-lineage-bus` for downstream processing.  
3. **Normalize:** Lambda `lineage-normalize` validates schema against `lin_event_v1` (SRG-001).  
4. **Persist:** Write summary to DynamoDB, detailed payload to S3.  
5. **Linkage Update:** Graph service merges nodes and edges via `MERGE` semantics (Neo4j or Neptune API).  
6. **Catalog Update:** Catalog API updates metadata attributes—owner, retention, SLO, and dataset lineage.  
7. **Notify:** SNS topic `lineage-updates` notifies observability and governance consumers.  

---

## 6. Schema and Contracts
| Artifact | Location | Versioning | Governance |
|-----------|-----------|------------|-------------|
| **Lineage Event Schema (`lin_event_v1`)** | SRG-001 | Digest-pinned JSON Schema | DCON-001 |
| **Catalog Entry Schema (`lin_catalog_v2`)** | SRG-001 | Immutable major; minor additive | DM-005 |
| **Lineage Graph Model (`lin_graph_v1`)** | DM-002 | UUIDv7 node IDs; edge type = `TRANSFORMED_FROM` | GOV-001 |

All schemas are validated in CI during contract and pipeline updates. Schema evolution follows SRG-001 and DCON-001 governance flows.

---

## 7. IAM and Security Controls
| Domain | Implementation |
|--------|----------------|
| **Authentication** | GitHub OIDC role for deploy; runtime IAM roles per service (Lambda, ECS). |
| **Authorization** | Fine-grained IAM policies per component; ABAC tenant tags; API Gateway scopes for Catalog API. |
| **Encryption** | S3, DynamoDB, and EventBridge encrypted with KMS CMKs per environment. |
| **Secrets Management** | All database credentials and tokens stored in Secrets Manager. |
| **Audit Logging** | CloudTrail for API and EventBridge activity; logs linked to `lineage_event_id`. |
| **Compliance** | SOC 2 Type II and GDPR Article 30 mapping per GOV-002. |

---

## 8. Observability and Metrics
| Metric | Target | Source |
|---------|---------|---------|
| **Lineage Event Lag (p95)** | ≤ 60 s | CloudWatch / Prometheus |
| **Catalog Sync Success Rate** | ≥ 99.5 % | Lambda metrics |
| **Schema Drift Detected** | 0 | SRG-001 diff |
| **Missing Lineage Links** | < 0.1 % total nodes | Graph analyzer |
| **API Availability** | ≥ 99.9 % | ALB / API Gateway logs |

All metrics are visualized under Grafana dashboard `LIN-001` with integrated alerts defined in **OBS-003** escalation catalog.

---

## 9. CI/CD Integration
- **CI (Ref: CI/CL-001):** Validates lineage event schema compliance, lint, and unit tests.  
- **CD (Ref: CI/CL-002):** Deploys lineage Lambda, Catalog API, and EventBridge rules via IaC.  
- **Change Control (Ref: CI/CL-003):** CAB approval required for schema or contract version bump.  
- **Rollback:** Previous schema and graph snapshot restored from S3 versioned bucket.  

---

## 10. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|-----------|
| Lineage Logs (S3) | LAK-001 | Versioned, 7 years |
| DynamoDB `lineage_graph` | DM-003 | PITR 7 days |
| Catalog Metadata | DM-005 | 2-year retention |
| Schema Registry Sync | SRG-001 | Immutable |
| DQ Lineage Correlation | DQ-001 | 30 days |
| Observability Metrics | OBS-001 | 90 days |

All resources follow the naming convention `nc-<env>-lin-<component>` and encryption per GOV-002.

---

## 11. Acceptance Criteria
1. All ingestion and processing jobs emit lineage events successfully.  
2. Lineage event validation passes SRG-001 schema check.  
3. No schema drift or missing linkage detected for 30-day rolling window.  
4. Catalog synchronization job executes daily with ≥ 99.5 % success rate.  
5. Evidence pack (logs, lineage graph snapshot, catalog digest, metrics) attached to CAB ticket.  

---

## 12. Change Log
| Version | Date | Description | Author |
|----------|-------|-------------|--------|
| 1.0 | 2025-11-09 | Initial board-ready release validated against REF-001 standards | Data Platform Lead |

---

## Appendix A — Example Lineage Event Payload
```json
{
  "event_id": "urn:nc:lineage:uuidv7:018f81ac-3b29-11ef-8a9b-0242ac120002",
  "source_urn": "urn:nc:dataset:ing-001-raw-users",
  "target_urn": "urn:nc:dataset:proc-001-normalized-users",
  "schema_digest": "sha256:9b3c7f45c0...",
  "contract_version": "v3.1",
  "dq_result_id": "urn:nc:dq:result:7f8910...",
  "run_id": "proc-001-run-2025-11-09-0001",
  "timestamp": "2025-11-09T18:45:00Z",
  "status": "SUCCEEDED"
}
```

---

## Appendix B — GitHub Actions Runner Snippet
```yaml
name: Lineage and Catalog Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]
    paths:
      - 'lin/**'

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

      - name: Deploy Lineage Components
        run: |
          aws cloudformation deploy             --template-file lin/lin-stack.yaml             --stack-name nc-core-lin             --capabilities CAPABILITY_NAMED_IAM

      - name: Register Deployment
        run: echo "LIN-001 Lineage and Catalog deployed successfully"
```
