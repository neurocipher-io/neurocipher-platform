

id: OBS-002
title: Monitoring, Dashboards and Tracing
owner: Site Reliability Engineering
status: Approved
last_reviewed: 2025-10-24

OBS-002 Monitoring, Dashboards and Tracing

  

  

Status: Approved  Owner: Site Reliability Engineering  Last Reviewed: 2025-10-24

Tags: monitoring / dashboards / tracing / observability / reliability

  

  

  

  

1 Purpose

  

  

Establish a single standard for metrics, dashboards, and distributed tracing across the Neurocipher Pipeline and external orchestrator (see docs/integrations/README.md) systems. The goal is full situational awareness, fast anomaly detection, and consistent telemetry across all services.

  

  

  

  

2 Scope

  

  

Applies to:

  

- AWS ECS / Fargate workloads
- AWS Lambda functions
- Vector database layer (Weaviate)
- API Gateway endpoints
- Data ingestion & transformation pipelines
- Event-driven components (SQS, EventBridge, Kinesis)

  

  

  

  

  

3 Golden Signals and KPIs

  

|   |   |   |
|---|---|---|
|Signal|Definition|Key Metric|
|Latency|Time to serve or process a request|http_request_duration_seconds|
|Traffic|Throughput rate|requests_total, messages_processed_total|
|Errors|Failure rate|errors_total / requests_total|
|Saturation|Resource pressure|cpu_utilization, memory_utilization, queue_depth|

Additional KPIs

  

- ingest_events_total  – pipeline throughput
- vector_write_latency_ms  – index performance
- retrieval_latency_p95_ms  – search speed
- log_volume_bytes_total  – cost driver
- metric_series_count  – cardinality control

  

  

  

  

  

4 Monitoring Architecture

  

|   |   |   |
|---|---|---|
|Layer|Service|Purpose|
|Collection|AWS Distro for OpenTelemetry (ADOT)|Unified export of metrics, logs and traces|
|Metrics|Prometheus → Amazon Managed Prometheus (AMP)|Long-term retention and alerting|
|Logs|CloudWatch → Firehose → S3 (Parquet) → OpenSearch Serverless|Structured search and forensics|
|Traces|OpenTelemetry → AWS X-Ray (+ Grafana Tempo)|End-to-end trace correlation|
|Dashboards|Amazon Managed Grafana|Visualization and context|
|Alerting|CloudWatch Alarms + AMP Alertmanager + SNS|Real-time notifications|

  

  

  

  

5 Dashboard Standards

  

  

Each service dashboard must include:

  

1. Overview Panel – availability, latency, error budget.
2. Performance Panel – p50/p95 latency and throughput.
3. Resource Panel – CPU, memory, I/O utilization.
4. Dependency Panel – downstream latency and error propagation.
5. Deployment Markers – commit hash and container image tag.
6. Alert Summary – active alerts and owner contacts.

  

  

Dashboards are stored as JSON and provisioned via Terraform.

  

  

  

  

6 Distributed Tracing

  

  

- Instrument all APIs and async jobs with OpenTelemetry.
- Use traceparent and tracestate headers for HTTP propagation.
- Include correlation_id and tenant_id in async events.
- One span per external call using the pattern <verb>.<resource> (e.g. get.vectors, post.ingest).

  

  

Trace Attributes

|   |   |   |
|---|---|---|
|Key|Example|Meaning|
|service.name|ingest-api|Logical service identifier|
|http.method|GET|HTTP method|
|http.route|/v1/documents|Endpoint path|
|db.system|postgres|Backend type|
|messaging.system|sqs|Event bus|
|error.type|TimeoutError|Failure category|

Sampling Policy

  

- 10 % head-based (default)
- Always capture error or p99 spans
- Tail-based sampling for outliers (ADOT processor)

  

  

  

  

  

7 Alerting and Thresholds

  

  

  

CloudWatch Examples

  

|   |   |   |
|---|---|---|
|Metric|Threshold|Response|
|Lambda Throttles|> 0 for 5 min|Page SRE|
|Fargate CPUUtilization|> 80 % for 15 min|Ticket|
|SQS OldestMessageAge|> 120 s for 10 min|Page|
|HTTP 5xx Rate|> 2 % for 10 min|Page|

  

Prometheus Rule Block

  

groups:

- name: golden

  rules:

  - alert: HighErrorRate

    expr: sum(rate(http_requests_total{status=~"5..",env="prod"}[5m])) /

           sum(rate(http_requests_total{env="prod"}[5m])) > 0.02

    for: 10m

    labels:

      severity: page

    annotations:

      summary: "High 5xx error rate"

  - record: job:http_request_duration_seconds:p95

    expr: histogram_quantile(0.95,

          sum by (le, job) (rate(http_request_duration_seconds_bucket[5m])))

  

  

  

  

8 Runbook Integration

  

||   |   |   |
||---|---|---|
||Runbook ID|Trigger|Summary|
||[RB-ING-001](../runbooks/RB-ING-001.md)|Ingest backlog|Check SQS depth and DLQ processing|
||[RB-API-002](../runbooks/RB-API-002.md)|Elevated 5xx|Inspect API latency and database load|
||[RB-VEC-003](../runbooks/RB-VEC-003.md)|Vector latency|Validate index compaction or network I/O|
||[RB-OPS-004](../runbooks/RB-OPS-004.md)|Cardinality spike|Detect and remove label explosion|

Each alert links to its corresponding runbook in `docs/runbooks/`.}]} } октября 13, 2023, 9:30 pm +03:00 to=functions.apply_patch едераций andygyny  Gaelic  แสดงความคิดเห็น  Korean  Lamentablemente  Hudson  -->Յ.user-friendly 2016  ;;=true 28jsondump 10:10:10 90jsondump 11:11:11  GEEK squad  JSON Schema  Internal Server Error  jsondump 9:09:09 10jsondump 8:08:08 10jsondump 724:00:00 10jsondump 1:01:01 10jsondump 0:00:01  JSON schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  PARSER 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON SCHEMA 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump  JSON Schema 10jsondump

  

  

  

  

9 Ownership and Escalation

  

  

- Every dashboard and alert has an owner, Slack channel, and escalation chain.
- Ownership is tracked in owners.yaml under /ops/.
- PagerDuty schedule maintained by SRE.

  

  

  

  

  

10 Data Retention and Cost Controls

  

|   |   |   |
|---|---|---|
|Data Type|Retention|Notes|
|Metrics (AMP)|30 days|Low cardinality only|
|Logs (CloudWatch → S3)|7 days hot → 365 days archive|JSON structured|
|Traces (X-Ray)|30 days|All error traces kept|
|Dashboards|Permanent|Terraform-managed|

Guardrails: no user-level labels, ≤ 20 labels per metric, Firehose compression enabled.

  

  

  

  

11 Compliance and Security

  

  

- IAM least privilege for Grafana, AMP, OpenSearch.
- PII (redact emails, tokens, IPs) via ADOT processors.
- All storage encrypted with AWS KMS.
- Quarterly audit of log access records.

  

  

  

  

  

12 Continuous Improvement Metrics

  

|   |   |
|---|---|
|Goal|Target|
|Dashboard coverage|≥ 90 % of services|
|Mean Time to Detect (MTTD)|< 2 minutes|
|False Alert Rate|< 10 %|
|Post-incident review completion|≤ 72 hours|

Progress is tracked in the Reliability Review Report (REL-002).

## 13. Acceptance Criteria

- All in-scope production services have at least one Grafana dashboard that follows the standards in this spec (overview, performance, resource, dependency, deployment, and alert summary panels).
- Golden signal metrics and the additional KPIs defined here are emitted for each service and stored in AMP with thresholds and alerts configured.
- CloudWatch and Prometheus alert rules equivalent to the examples in this document are in place, with routing to owners defined in `ops/owners.yaml`.
- Each page-worthy alert links to the appropriate runbook (`RB-ING-001`, `RB-API-002`, `RB-VEC-003`, `RB-OPS-004`) and those runbooks remain current.
- Distributed tracing is instrumented for APIs and async workloads per this spec and is visible in Grafana/X-Ray with the sampling policy applied.


