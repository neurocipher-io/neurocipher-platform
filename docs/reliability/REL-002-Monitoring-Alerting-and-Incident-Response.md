id: REL-002
title: Monitoring, Alerting and Incident Response
owner: Reliability Engineering
status: Approved
last_reviewed: 2025-10-24

Document ID: REL-002

Title: Monitoring, Alerting & Incident Response

Project: Neurocipher Data Pipeline

Version: 1.0

Status: Approved

Date: 2025-10-24

  

  

  

  

1. Objective

  

  

Provide unified observability, proactive alerting, and structured incident response to maintain reliability and minimize downtime across the Neurocipher Data Pipeline.

The capacity and cost assumptions that drive these targets are described in `docs/observability/CAP-001-Capacity-and-Scalability-Model.md`; align alerts, dashboards, and incident escalations with that model’s QPS, queue, and vector throughput expectations.

  

  

  

  

2. Scope

  

  

Applies to all core AWS components: ingestion (API Gateway, Lambda, ECS), data storage (RDS, S3, Weaviate), and message processing (SQS, Kinesis). Covers metrics, logs, traces, alert thresholds, and escalation workflow.

  

  

  

  

3. Observability Stack

  

|               |                                        |                                              |
| ------------- | -------------------------------------- | -------------------------------------------- |
| Layer         | Tool                                   | Purpose                                      |
| Metrics       | Amazon CloudWatch                      | System health, resource utilization          |
| Logs          | CloudWatch Logs, OpenSearch Serverless | Centralized log aggregation                  |
| Tracing       | AWS X-Ray                              | Distributed tracing of pipeline transactions |
| Visualization | Grafana (via AMP datasource)           | Unified dashboards                           |
| Notifications | Amazon SNS + Slack webhook             | Real-time alert routing                      |

  

  

  

  

4. Key Metrics

The canonical SLO / retention matrix lives in OBS-001 §5 and also drives the targets listed below; these metrics feed the SLIs that keep the ingest API, vector store, pipeline freshness, and security actions within error budget.

  

|   |   |   |
|---|---|---|
|Category|Metric|Target / Threshold|
|Availability|Uptime %|≥ 99.9|
|Performance|Latency (p95)|< 300 ms per request|
|Throughput|Ingestion rate|> 10 000 events/min|
|Queue Health|SQS/Kinesis lag|< 2 min|
|Database|CPU/IOPS usage|< 70% sustained|
|Errors|5xx rate|< 0.5% of total requests|
|Storage|S3 object growth|< 10% weekly deviation|
|Vector Index|Weaviate cluster replication health|100% nodes active|

  

  

  

  

5. Log Policy

  

  

- Structured JSON logging across all services.
- Trace IDs propagated via OpenTelemetry headers.
- Logs retained for 90 days, cold-archived to S3 Glacier after 90 days.
- Security-sensitive events flagged with SEC_HIGH tag.

  

  

  

  

  

6. Alerting Rules

  

|   |   |   |
|---|---|---|
|Event|Trigger|Action|
|Pipeline failure|Lambda/ECS error rate > 2%|PagerDuty notification|
|Queue backlog|Lag > 120s|Autoscale consumer tasks|
|RDS replication lag|> 10s|Promote standby|
|CPU exhaustion|> 85% for 5 min|Scale out ECS task count|
|Security breach|GuardDuty finding severity ≥ 5|Trigger IR playbook|
|Cost anomaly|>15% deviation week-to-week|Notify FinOps channel|

  

  

  

  

7. Dashboards

  

  

- Pipeline Overview: ingestion rate, queue depth, latency histogram.
- System Health: ECS task health, Lambda duration, RDS replication.
- Security Lens: failed auths, API rate anomalies, KMS activity.
- Cost Lens: AWS Cost Explorer + Grafana FinOps plugin integration.

  

  

  

  

  

8. Incident Response Workflow

  

|   |   |   |
|---|---|---|
|Phase|Description|Owner|
|Detection|Automated alert or manual report|System or on-call|
|Classification|Assign severity (P1–P4)|Incident Commander|
|Containment|Isolate failing service|Infra Ops|
|Resolution|Apply fix or rollback|DevOps|
|Postmortem|Root cause + prevention actions|Reliability Lead|

  

  

  

  

9. Severity Levels

  

|   |   |   |
|---|---|---|
|Level|Definition|SLA|
|P1|Complete outage|Resolve < 60 min|
|P2|Partial degradation|Resolve < 4 hr|
|P3|Minor incident|Resolve < 24 hr|
|P4|Cosmetic / informational|Resolve < 72 hr|

  

  

  

  

10. Automation & Self-Healing

  

  

- CloudWatch → Lambda responders restart failed ECS tasks.
- Route 53 failover DNS automation triggers regional fallback.
- Incident tickets auto-created in Jira via SNS → API Gateway bridge.

  

  

  

  

  

11. Reporting & Review

  

  

- Weekly reliability reports in PDF format from Grafana snapshots.
- Monthly postmortem summary log (linked to ADRs).
- SLA adherence metrics stored in DynamoDB.

  

  

  

  

  

12. Dependencies

  

  

- REL-001 High Availability & Fault Tolerance
- ADR-010 Disaster Recovery & Backups
- SEC-001 Threat Model & Mitigation

  

  

  

  

  

13. Change Control

  

  

Alert thresholds, notification policies, or escalation trees require review by Reliability Engineering and approval from the CTO prior to deployment.

## Acceptance Criteria

- The observability stack (metrics, logs, traces, dashboards) described in this document is deployed for all in-scope services, with key metrics and SLOs wired into dashboards.
- Alerting rules for pipeline failure, queue backlog, RDS replication lag, CPU exhaustion, security findings, and cost anomalies are implemented with correct routing (PagerDuty, Slack, FinOps) and tested.
- Severity levels (P1–P4) and the incident response workflow are in active use; incidents are classified and handled according to the defined SLAs.
- Weekly or monthly reliability reports and postmortem summaries are produced and retained as specified, with SLIs/SLOs tracked over time.
- Changes to alert thresholds or escalation policies follow the change-control process and are approved by Reliability Engineering and the appropriate leadership.
- Incident postmortems and dashboards reference the classification/masking evidence from `docs/governance/REF-001-Glossary-and-Standards-Catalog.md §8` and DQ-001 when PII data contributed to the event.

  
