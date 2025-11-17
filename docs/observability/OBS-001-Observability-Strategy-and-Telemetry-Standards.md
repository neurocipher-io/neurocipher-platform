

id: OBS-001
title: Observability Strategy and Telemetry Standards
owner: Platform Engineering
status: Approved
last_reviewed: 2025-10-24

OBS-001 Observability Strategy and Telemetry Standards

  

  

  

Scope

  

  

Neurocipher Pipeline on AWS. Applies to ingestion services, external orchestrator (see docs/integrations/README.md) orchestrator, model workers, vector store, data transforms, APIs.

  

  

Objectives

  

  

- Full-fidelity traces for every request path.
- Metrics with clear RED and USE coverage.
- Logs as structured events with correlation IDs.
- Low overhead via sampling and tiered retention.

  

  

  

Telemetry stack

  

  

- Collection: AWS Distro for OpenTelemetry (ADOT) on ECS Fargate and Lambda extensions.
- Tracing: OpenTelemetry Trace API. Export to AWS X-Ray and OTLP to Managed Grafana AMP for exemplars.
- Metrics: Prometheus Remote Write to Amazon Managed Service for Prometheus. System metrics via CloudWatch.
- Logs: JSON to CloudWatch Logs. Firehose to S3 parquet. Optional index: OpenSearch Serverless for short-lived search.
- Dashboards: Amazon Managed Grafana.
- Alerting: CloudWatch Alarms, AMP Alertmanager, SNS, PagerDuty webhook.

  

  

  

Context propagation

  

  

- HTTP: W3C traceparent and tracestate. Fallback to X-Amzn-Trace-Id for AWS services.
- Async: embed correlation_id and trace_id in message headers for SQS, EventBridge, Kinesis.

  

  

  

Event taxonomy

  

  

- Metrics: service, component, stage, region, env.
- Logs: level, event_name, correlation_id, trace_id, span_id, user_scope, outcome, latency_ms.
- Traces: span kind, db.system, messaging.system, net.peer.name, error.type.

  

  

  

Metrics catalog

  

  

- RED for APIs: requests_total, errors_total, request_duration_seconds histogram.
- USE for workers: cpu_utilization, memory_utilization, queue_depth, saturation_ratio.
- Pipeline KPIs: ingest_events_total, dedup_rate, vector_write_latency_ms, retrieval_latency_ms, hit_ratio, batch_retries_total.

  

  

  

Log schema

  

{

  "ts": "RFC3339",

  "service": "ingest-api",

  "env": "prod",

  "level": "INFO",

  "event_name": "document_ingested",

  "correlation_id": "uuid",

  "trace_id": "hex",

  "span_id": "hex",

  "user_scope": "tenant-id",

  "latency_ms": 42,

  "bytes": 1048576,

  "outcome": "success",

  "tags": ["source:web","format:pdf"]

}

  

Sampling policy

  

  

- Default traces 10 percent head-based.
- Always sample errors and p99 slow spans.
- Background jobs 5 percent with tail-based upsample on anomalies.

  

  

  

PII and security

  

  

- Redact emails, tokens, IPs by ADOT processors. Never log secrets.
- Tenant isolation tag required on all metrics and logs.
- Tenant identifier handling and header propagation follow docs/security-controls/SEC-005-Multitenancy-Policy.md.
- S3 buckets encrypted with KMS. Access via IAM least privilege.
- Masking and PII handling follow the classification tiers in `docs/governance/REF-001-Glossary-and-Standards-Catalog.md §8` alongside the DQ-001 masking rules.

  

  

  

Retention

  

  

- CloudWatch Logs hot 7 days. S3 parquet warm 365 days. OpenSearch 14 days.
- AMP time series 30 days. X-Ray 30 days. Grafana dashboards persistent.

  

  

  

Cost controls

  

  

- Metric cardinality guardrails. No high-cardinality labels like user_id.
- Log sampling for verbose components. Compression in Firehose.

  

  

  

## **5. Retention & SLO matrix**

| Surface | Target / SLO | SLI / Observability | Retention / RPO |
|---|---|---|---|
| **Ingest API** | 99.9 % availability per month; p95 latency ≤ 300 ms; 5xx < 0.5 % (OBS-003, REL-002) | `http_request_duration_seconds`, `ingest_success_total`, API Gateway `5xx` gauges, AMP/Prometheus dashboards | Logs hot 7 days (CloudWatch) → S3 365 days, metrics 30 days (AMP), traces 30 days (X-Ray), RPO 15 min / RTO 120 min (DR-001) |
| **Query & Vector search (Weaviate NcChunkV1)** | p95 latency ≤ 200 ms; index error ≤ 0.1 %; error budget burn alerts as per OBS-003 | `weaviate_query_duration_seconds`, `weaviate_replica_health`, `vector_write_latency_ms`, OpenSearch `query_duration_seconds` | Vector data retention RC2 2 years (DM-001/DM-003), Weaviate nightly snapshots to S3, RPO 60 min / RTO 240 min (DR-001) |
| **Pipeline freshness & indexing** | 99 % of documents searchable ≤ 5 min after ingest; queue lag < 2 min | `document_processing_latency_seconds`, `queue_age_seconds`, `embedding_ref` metrics | Normalized data retention RC3/RC2 (DM-001, LAK-001), RPO 60 min (DR-001) |
| **Security actions & remediation** | Decision latency p95 ≤ 90 s; audit trails complete (OBS-003) | `security_engine.decision_latency_ms`, `security_engine.command_queue_age_s`, EventBridge audit events | Audit logs & command traces retained 2 years in S3 (OBS-003), RPO aligned with control plane recovery |
| **Observability telemetry** | Metrics retention 30 days, traces 30 days, logs 90 days hot / 365 days archived; alert history 1 year (REL-002, OBS-003) | AMP/Prometheus, Grafana dashboards, Log archives | Metrics retention 30 days (AMP), traces 30 days, logs 90 days hot → 365 days warm (S3), alert history 1 year (AMP) |

The table above is the canonical source for SLO targets and retention durations cited throughout OBS-003, REL-002, OPS-001, and DR-001. Alert routing, burn-rate policies, and incident readiness refer to these targets when they mention availability, latency, or retention-specific evidence.

Capacity and cost assumptions that tune these targets (baseline QPS, queue margin, Weaviate throughput, and cost levers) live in `docs/CAP-001-Capacity-Model.md`; reference that document when tuning alarms or adjusting SLO thresholds.

OBS-002 Monitoring, Dashboards, and Tracing

  

  

  

Golden signals

  

  

- Availability, latency, throughput, saturation per service.
- Queue depth and age for SQS and Kinesis.
- Vector store ops per second and p95 latency.
- Error budget burn per SLO.

  

  

  

Dashboards

  

  

- Service Overview: RED, error budget, deploy markers.
- Pipeline Health: ingest rate, backpressure, DLQ, reprocess success.
- Storage and Index: Weaviate write latency, shards health, compactions.
- Cost and Cardinality: metrics series count, label tops, log volume.

  

  

  

Tracing standards

  

  

- One span per external call. Name as verb.resource, example get:/v1/ingest.
- Record attributes: http.method, http.route, http.status_code, net.host.name, db.statement sanitized.
- Link background spans to the originating request via parent trace_id.
- Add exemplars from histograms to traces.

  

  

  

Example Prometheus rules

  

groups:

- name: golden

  rules:

  - alert: HighErrorRate

    expr: sum(rate(http_requests_total{status=~"5..",env="prod"}[5m])) 

          / sum(rate(http_requests_total{env="prod"}[5m])) > 0.02

    for: 10m

    labels: {severity: page}

    annotations:

      summary: High 5xx error rate

  - record: job:http_request_duration_seconds:p95

    expr: histogram_quantile(0.95, sum by (le, job) (rate(http_request_duration_seconds_bucket[5m])))

  

CloudWatch alarms

  

  

- Lambda Throttles > 0 for 5 minutes. Severity page.
- Fargate CPUUtilization > 80 percent for 15 minutes. Severity ticket.
- SQS ApproximateAgeOfOldestMessage > 120s for 10 minutes. Page.

  

  

  

Runbook links

  

  

- [RB-ING-001 Ingest backlog](../runbooks/RB-ING-001.md).
- [RB-API-002 Elevated 5xx](../runbooks/RB-API-002.md).
- [RB-VEC-003 Vector index latency](../runbooks/RB-VEC-003.md).
- [RB-OPS-004 Cardinality spike](../runbooks/RB-OPS-004.md).

  

  

  
Ownership

  

  

- Each dashboard has an owner, Slack channel, and escalation policy. Keep contacts updated per release.

  

  

  

OBS-003 Alerting, SLOs, and Incident Response

  

  

  

SLOs and SLIs

  

  

- Ingest API availability: 99.9 percent monthly. SLI = 1 − 5xx_rate.
- P95 ingest API latency: ≤ 300 ms during business hours.
- Pipeline freshness: 99 percent of documents available in index within 5 minutes.
- Vector search p95 latency: ≤ 200 ms.

  

  

  

Error budgets

  

  

- 43.2 minutes per month for 99.9 percent. Track burn rate at 1h and 6h windows.
- Page on fast burn > 2 percent per hour. Ticket on slow burn > 5 percent per day.

  

  

  

Alert policy

  

  

- Page only on user-impacting symptoms, not internal causes.
- One page per incident. Aggregate by service and tenant.
- Suppress during deploy with automatic alerts mute for 10 minutes if success.

  

  

  

Alertmanager routing

  

route:

  receiver: pagerduty

  group_by: [service, env]

  routes:

  - matchers: [severity="ticket"]

    receiver: jira

receivers:

- name: pagerduty

  pagerduty_configs:

  - routing_key: ${PAGERDUTY_KEY}

- name: jira

  webhook_configs:

  - url: https://hooks.example/jira

  

On-call

  

  

- Primary and secondary rotation weekly. Handover notes in runbook.
- Escalation: page after 5 minutes unacked, then engineering manager at 15 minutes.

  

  

  

Incident process

  

  

- Declare incident with severity, impact, start time, commander.
- Live doc with timeline, hypotheses, actions, and owner.
- Comms template for status page and tenant notice.
- Postmortem within 72 hours. Blameless. Action items with owners and due dates.

  

  

  

Automated safeguards

  

  

- Rollback on error-rate regression post deploy using canary and CloudWatch alarm integration.
- Circuit breakers on external dependencies with fallback responses and clear telemetry.

  

  

  

Compliance

  

  

- Retain incident records and alert history 2 years.
- Access to dashboards and logs via IAM roles with least privilege.
- Mask customer content in all artifacts.

 ———

OBS-001 Observability Strategy and Telemetry Standards

  

---

id: OBS-001

title: Observability Strategy and Telemetry Standards

status: Approved

owner: Platform Engineering

last_reviewed: 2025-10-24

tags: [observability, telemetry, metrics, tracing, logging]

---

  

### Scope

Neurocipher Pipeline (AWS). Applies to ingestion, external orchestrator (see docs/integrations/README.md), model workers, vector store, data transforms, APIs.

  

### Objectives

- Full-fidelity tracing for all request paths.  

- Metrics with RED/USE coverage.  

- Structured JSON logs with correlation IDs.  

- Low overhead through sampling and tiered retention.

  

### Telemetry Stack

| Function | Service |

|-----------|----------|

| Collection | AWS Distro for OpenTelemetry (ADOT) |

| Tracing | OpenTelemetry Trace API → AWS X-Ray, OTLP→Grafana AMP |

| Metrics | Prometheus Remote Write → Amazon Managed Prometheus |

| Logs | JSON → CloudWatch, Firehose→S3 Parquet, OpenSearch Serverless |

| Dashboards | Amazon Managed Grafana |

| Alerting | CloudWatch Alarms + AMP Alertmanager + SNS/PagerDuty |

  

### Context Propagation

HTTP uses `traceparent` and `tracestate`.  

Async uses `correlation_id` and `trace_id` in SQS/EventBridge/Kinesis headers.

  

### Event Taxonomy

Metrics: `service`, `component`, `stage`, `region`, `env`.  

Logs: `level`, `event_name`, `correlation_id`, `trace_id`, `span_id`, `user_scope`, `outcome`, `latency_ms`.  

Traces: `span_kind`, `db.system`, `messaging.system`, `net.peer.name`, `error.type`.

  

### Metrics Catalog

- **RED** for APIs: `requests_total`, `errors_total`, `request_duration_seconds`.  

- **USE** for workers: `cpu_utilization`, `memory_utilization`, `queue_depth`.  

- Pipeline KPIs: `ingest_events_total`, `dedup_rate`, `vector_write_latency_ms`, `retrieval_latency_ms`.

- Security Engine: `security_engine.decision_latency_ms`, `security_engine.command_queue_age_s`, `security_engine.action_status_failures_total`, `security_engine.action_status_lag_ms`.

Security Engine spans/logs must include `action_id`, `status_id`, `schema_urn`, and `tenant_id`.

  

### Log Schema

```json

{

  "ts": "RFC3339",

  "service": "ingest-api",

  "env": "prod",

  "level": "INFO",

  "event_name": "document_ingested",

  "correlation_id": "uuid",

  "trace_id": "hex",

  "span_id": "hex",

  "user_scope": "tenant-id",

  "latency_ms": 42,

  "bytes": 1048576,

  "outcome": "success",

  "tags": ["source:web","format:pdf"]

}

  

Sampling

  

  

- 10 % head-based (default)
- Always sample errors and p99 spans
- 5 % for background jobs + tail-based upsample on anomalies

  

  

  

Security and PII

  

  

- Redact tokens/IPs via ADOT processors.
- Tenant tag mandatory.
- See docs/security-controls/SEC-005-Multitenancy-Policy.md for the canonical tenant-id format and propagation rules.
- S3 encrypted (KMS). IAM least privilege.

  

  

  

Retention

  

|   |   |   |   |
|---|---|---|---|
|Source|Hot|Warm|Cold|
|CloudWatch Logs|7 days|–|S3 365 days|
|OpenSearch|14 days|–|–|
|AMP/X-Ray|30 days|–|–|

  

Cost Controls

  

  

- Limit metric cardinality.
- Sample verbose logs.
- Compress Firehose streams.

### Acceptance Criteria

- All in-scope services emit metrics, logs, and traces following the field and tag conventions in this spec (including `service`, `component`, `stage`, `region`, and `env`).
- HTTP and async context propagation (`traceparent`, `tracestate`, `correlation_id`, `trace_id`) is implemented across ingestion, workers, vector store, and APIs.
- The telemetry stack (ADOT, AMP, CloudWatch → Firehose → S3, OpenSearch, Grafana, Alertmanager) is deployed and wired together as described here.
- Sampling, PII handling, retention, and cost-control policies (cardinality guardrails, log sampling, KMS encryption) are enforced for all production environments.
- Security Engine events and actions include the required observability fields (`action_id`, `status_id`, `schema_urn`, `tenant_id`) in metrics, logs, and traces.

---

---

  

## **OBS-002 Monitoring, Dashboards, and Tracing**

  

```markdown

---

id: OBS-002

title: Monitoring, Dashboards, and Tracing

status: Approved

owner: Site Reliability Engineering

last_reviewed: 2025-10-24

tags: [monitoring, dashboards, tracing]

---

  

### Golden Signals

Availability, latency, throughput, saturation per service.  

Queue depth/age (SQS, Kinesis).  

Vector store p95 latency.  

Error budget burn.

  

### Dashboards

- **Service Overview** – RED metrics, deploy markers.  

- **Pipeline Health** – ingest rate, DLQ, reprocess success.  

- **Storage & Index** – Weaviate latency, shard health.  

- **Cost & Cardinality** – metric series count, log volume.

  

### Tracing Standards

- One span per external call. Name as `verb.resource`.  

- Attributes: `http.method`, `http.route`, `http.status_code`, `db.statement` (sanitized).  

- Link async spans to parent `trace_id`.  

- Add exemplars from histograms.

  

### Prometheus Rules

```yaml

groups:

- name: golden

  rules:

  - alert: HighErrorRate

    expr: sum(rate(http_requests_total{status=~"5..",env="prod"}[5m]))

          / sum(rate(http_requests_total{env="prod"}[5m])) > 0.02

    for: 10m

    labels: {severity: page}

    annotations:

      summary: High 5xx error rate

  - record: job:http_request_duration_seconds:p95

    expr: histogram_quantile(0.95, sum by (le, job) (rate(http_request_duration_seconds_bucket[5m])))

  

CloudWatch Alarms

  

  

- Lambda Throttles > 0 for 5 min.
- Fargate CPUUtilization > 80 % for 15 min.
- SQS OldestMessageAge > 120 s for 10 min.

  

  

  

Runbook Links

  

  

- [RB-ING-001 Ingest Backlog](../runbooks/RB-ING-001.md)
- [RB-API-002 Elevated 5xx](../runbooks/RB-API-002.md)
- [RB-VEC-003 Vector Latency](../runbooks/RB-VEC-003.md)
- [RB-OPS-004 Cardinality Spike](../runbooks/RB-OPS-004.md)

  

  
Ownership

  

  

Each dashboard has an owner, Slack channel, and escalation policy. Update contacts per release.

---

  

## **OBS-003 Alerting, SLOs, and Incident Response**

  

```markdown

---

id: OBS-003

title: Alerting, SLOs, and Incident Response

status: Approved

owner: Reliability Engineering

last_reviewed: 2025-10-24

tags: [alerting, SLO, incident-response]

---

  

### SLOs and SLIs

| Metric | Target | SLI |

|---------|---------|------|

| Ingest API availability | 99.9 % / month | 1 − 5xx_rate |

| P95 API latency | ≤ 300 ms | p95(latency_ms) |

| Pipeline freshness | 99 % ≤ 5 min | time_to_index |

| Vector search latency | ≤ 200 ms | p95(query_latency_ms) |

  

### Error Budgets

43.2 min/month for 99.9 %.  

Burn-rate alerts: > 2 % / h (page), > 5 % / day (ticket).

  

### Alert Policy

Page only on user-impacting symptoms.  

Aggregate by service and tenant.  

Mute deploys for 10 min if healthy.

  

### Alertmanager Routing

```yaml

route:

  receiver: pagerduty

  group_by: [service, env]

  routes:

  - matchers: [severity="ticket"]

    receiver: jira

receivers:

- name: pagerduty

  pagerduty_configs:

  - routing_key: ${PAGERDUTY_KEY}

- name: jira

  webhook_configs:

  - url: https://hooks.example/jira

  

On-Call

  

  

Primary and secondary weekly rotation.

Escalate: 5 min unacked → secondary, 15 min → manager.

  

  

Incident Process

  

  

1. Declare incident (severity, impact, start, commander).
2. Live doc with timeline and actions.
3. Status page and tenant notice.
4. Postmortem within 72 h (blameless, action owners).

  

  

  

Safeguards

  

  

- Auto-rollback on error-rate regression.
- Circuit breakers for external calls with fallback telemetry.

  

  

  

Compliance

  

  

- Retain incident records 2 years.
- IAM least-privilege for logs/dashboards.
- Mask customer data in artifacts.

  

---

  

Would you like me to compile these three into a single PDF (`Observability_Docs.pdf`) or keep as separate `.md` files for direct inclusion in the `/docs/observability/` folder?
