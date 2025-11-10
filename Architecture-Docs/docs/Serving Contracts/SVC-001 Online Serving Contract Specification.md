# Document ID: SVC-001
**Title:** Online Serving Contract Specification  
**Status:** Final v1.0  
**Owner:** Platform SRE / Data Platform Lead  
**Applies to:** Neurocipher Core and AuditHound Module  
**Last Reviewed:** 2025-11-09  
**References:** PROC-001–003, DM-001–005, DCON-001, LIN-001, DQ-001, CAP-001, OBS-001–003, CI/CL-001–003, GOV-001, GOV-002, ADR-011

---

## 1. Purpose
Define the governed contract and service interface for real-time and near-real-time data serving within the Neurocipher Core platform.  
Ensures consistent API design, version control, authentication, and data schema alignment across all online endpoints exposing processed data from the Lakehouse and Vector stores.

---

## 2. Scope
**In scope:**  
- Definition of online serving interfaces for REST and GraphQL APIs.  
- Contract governance between core services (Weaviate, OpenSearch, RDS) and external clients.  
- Versioning and schema pinning to **DCON-001** and **SRG-001**.  
- Integration of metrics, capacity, and SLO monitoring per **OBS-003** and **CAP-001**.  

**Out of scope:**  
- Offline batch delivery and bulk data exports (covered by PROC-001 and LAK-001).  

---

## 3. Service Model
Each serving API follows a contract-first model stored in the Schema Registry and deployed through CI/CD.

| Component | Protocol | Purpose | Contract Source |
|------------|-----------|----------|-----------------|
| **Weaviate Serving API** | REST / GraphQL | Vector semantic search and embedding retrieval | DCON-001 (schema: svc_weaviate_v2) |
| **OpenSearch API** | REST | Search, filtering, faceting on indexed metadata | DCON-001 (schema: svc_opensearch_v1) |
| **RDS Query Gateway** | GraphQL | Transactional lookup and reference data access | DCON-001 (schema: svc_rds_v1) |
| **Inference Endpoint** | REST POST | Low-latency prediction and embedding generation | DCON-001 (schema: svc_infer_v1) |

All schemas emit OpenAPI specifications automatically through the registry pipeline per **SRG-001**.

---

## 4. Architecture
**Pattern:** Contract-driven serving tier backed by API Gateway and ECS/Lambda compute.

| Layer | Component | Standard |
|-------|------------|----------|
| **Gateway** | AWS API Gateway with custom domain and WAF | GOV-002 |
| **Compute** | ECS Fargate (REST) + Lambda (GraphQL) | CAP-001 Tier T3 |
| **Storage** | Weaviate cluster, OpenSearch domain, RDS Aurora PostgreSQL | LAK-001 |
| **Schema Registry** | Contract validation via SRG-001 digest pinning | DCON-001 |
| **Monitoring** | ADOT Collector + Prometheus + Grafana dashboards | OBS-002/003 |

---

## 5. Contract Structure
Contracts use OpenAPI 3.1 and JSON Schema v2020-12 under digest governance.  
Each endpoint must specify the following:
```yaml
openapi: "3.1.0"
info:
  title: "Neurocipher Online Serving API"
  version: "v2.0"
paths:
  /search:
    get:
      summary: "Semantic and keyword search"
      parameters:
        - name: q
          in: query
          required: true
          schema:
            type: string
      responses:
        "200":
          description: "Search results"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/SearchResponse"
components:
  schemas:
    SearchResponse:
      type: object
      properties:
        results:
          type: array
          items:
            $ref: "urn:nc:schema:svc_opensearch_v1"
```
---

## 6. IAM and Security Controls
| Domain | Implementation |
|--------|----------------|
| **Authentication** | JWT / Cognito OIDC tokens enforced at API Gateway; IAM role assumed for internal services. |
| **Authorization** | ABAC tags (`env`, `service`, `team`); least-privilege roles for Lambda and ECS tasks. |
| **Encryption** | TLS 1.3 in transit; KMS CMK per environment for storage. |
| **Secrets Management** | AWS Secrets Manager for API keys and DB credentials. |
| **Audit** | CloudTrail events linked to `svc_request_id`; logs retained per GOV-002. |
| **Compliance** | SOC 2 Type II API security controls; WAF rules per OWASP Top 10. |

---

## 7. Observability and SLOs
| Metric | Target | Alert Threshold | Source |
|---------|---------|----------------|---------|
| **P95 Latency** | ≤ 250 ms | ≥ 400 ms (5 min) | CloudWatch / APM |
| **Availability** | ≥ 99.9 % | < 99.5 % (rolling 24 h) | ALB / Route 53 |
| **Error Rate** | ≤ 0.1 % | ≥ 1 % 5 min | ADOT Collector |
| **Throughput** | ≥ 500 req/s steady | < 300 req/s drop | Prometheus |
| **Cold-start Duration** | ≤ 500 ms | ≥ 1 s | Lambda metrics |

---

## 8. Versioning and Change Management
- Semantic Versioning (`major.minor.patch`) applied to contract URIs.  
- Breaking changes require new major version and CAB approval.  
- Minor changes auto-published with digest and signature per SRG-001.  
- Rollback mechanism: API Gateway stage revert and ECR image rollback under CI/CL-002.  

---

## 9. CI/CD Integration
- **CI (CI/CL-001):** Contract lint and OpenAPI schema validation.  
- **CD (CI/CL-002):** Blue/green deployment through API Gateway + CodeDeploy.  
- **Change Control (CI/CL-003):** CAB approval for major contract releases and new resources.  
- **Rollback:** Triggered if error rate > 1 % or latency > 400 ms sustained 10 min.  

---

## 10. Data Governance and Storage Compliance
| Asset | Standard | Lifecycle |
|--------|-----------|-----------|
| OpenAPI Specs | SRG-001 | Versioned immutable digests |
| Service Logs | OBS-001 | 90 days |
| Metrics and Traces | OBS-002 | 90 days rolling |
| Contract Change Tickets | GOV-002 | 7 years |
| Request Audit Trails | GOV-001 | 2 years |

---

## 11. Acceptance Criteria
1. All API contracts validated and published through SRG-001 pipeline.  
2. P95 latency ≤ 250 ms and availability ≥ 99.9 %.  
3. No schema drift between contract digest and deployment.  
4. All IAM and WAF rules pass security audit.  
5. Evidence pack (SBOM, logs, metrics, contract digests) attached to CAB ticket.  

---

## 12. Change Log
| Version | Date | Description | Author |
|----------|------|-------------|--------|
| 1.0 | 2025-11-09 | Initial board-ready release validated against REF-001 standards | Platform SRE / Data Platform Lead |
