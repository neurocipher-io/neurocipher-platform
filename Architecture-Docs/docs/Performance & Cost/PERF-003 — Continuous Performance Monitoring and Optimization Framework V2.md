

PERF-003 — Continuous Performance Monitoring and Optimization Framework

  

Document ID: PERF-003

Title: Continuous Performance Monitoring and Optimization Framework

Status: Final v1.0

Owner: Platform SRE / FinOps / Performance Engineering

Applies to: Neurocipher Core and AuditHound module

Last Reviewed: 2025-11-06

References: PERF-001, PERF-002, OPS-001, OBS-001-003, REL-002, ADR-011

  

  

  

  

1 Purpose

  

  

Define the production-grade system for continuous measurement, drift detection, and automated optimization of runtime performance and cost efficiency across all AWS workloads. Converts one-time benchmarks (PERF-002) into ongoing telemetry loops integrated with CI/CD, observability, and FinOps controls.

  

  

2 Scope

  

  

Applies to every deployed service (API, Lambda, Fargate worker, Step Function, and AuditHound scanner) in all managed AWS accounts (dev, stg, prod).

Excludes local development and third-party SaaS components.

  

  

3 Architecture Overview

  

  

Flow

Service → ADOT Exporter → AMP + CloudWatch → FinOps ETL → Grafana Dashboards → Anomaly & Optimizer Lambdas → Jira/Slack Ticket

Core Components

|   |   |   |
|---|---|---|
|Layer|Service|Purpose|
|Collection|AWS Distro for OpenTelemetry (ADOT)|Unified metrics and traces|
|Metrics Store|Amazon Managed Prometheus (AMP)|Time-series analysis|
|Logs|CloudWatch → Firehose → S3 Parquet|Long-term trend correlation|
|Analysis|AWS Glue + Athena|Historical trend queries|
|Visualization|Amazon Managed Grafana|Service and FinOps dashboards|
|Automation|EventBridge + Lambda Optimizers|Autoscale and rightsizing|
|Alerting|AMP Alertmanager + SNS|SLO breach paging|
|Ticketing|AWS SDK → Jira API|Automatic remediation tasks|

  

4 Continuous Performance Monitoring

  

  

Metric Groups

|   |   |   |
|---|---|---|
|Category|Example Metric|SLO Target|
|Latency|http_request_duration_seconds_p95|≤ 300 ms (reads) / ≤ 600 ms (writes)|
|Throughput|ingest_events_total|≥ 10 000/min|
|Queue Health|ApproximateAgeOfOldestMessage|≤ 120 s|
|Resource Use|cpu_utilization, memory_utilization|< 80 % / 75 %|
|Error Rate|errors_total/requests_total|< 0.5 %|
|Cost Rate|aws_billing_estimatedCharges|within budget|

Collection Interval

  

- Real-time: 15 s for RED/USE metrics.
- Aggregate rollups: 5 min, 1 h, 24 h windows.
- Retention: 30 days AMP hot, 1 year S3 archive.

  

  

Drift Detection

  

- Baseline = last stable release mean ± 10 %.
- Auto-ticket if 3 consecutive windows breach threshold.
- Auto-rollback flag if p95 latency > 1.5× baseline for 10 min.

  

  

  

5 Cost and Utilization Telemetry

  

  

AWS Cost Explorer → FinOps ETL

  

- Nightly export via Athena to finops_cost_daily.parquet.
- Dimensions: service,env,owner,cost_center,usageType.
- Lambda job computes cost-per-1k-requests.
- Grafana FinOps board shows trend lines and unit cost variance.

  

  

Automatic Optimization Lambdas

|   |   |
|---|---|
|Trigger|Action|
|CPU > 85 % 5 min|Scale ECS task +1|
|CPU < 30 % 1 h|Scale ECS task −1|
|Lambda mem waste > 25 % avg|Reduce memory tier one step|
|Cost > 10 % budget|Post FinOps ticket and Slack alert|

All changes logged to /perf/optimizer/audit.log and approved via feature flag workflow.

  

  

6 Dashboards and Visualization

  

  

- Service Performance Panel – Latency, Error Rate, Saturation.
- Pipeline Health Panel – Queue depth, freshness, throughput.
- Cost Efficiency Panel – Spend vs usage, top cost drivers.
- Release Impact Markers – Overlay Git SHA and version tags.

  

  

Dashboards are JSON files managed through Terraform (ops/dashboards/).

  

  

7 CI/CD Integration

  

  

Pre-deploy checks

  

- Run perf-baseline-compare GitHub Action.
- Abort deploy if perf drift > 10 % without CAB waiver.
- Attach comparison artifact to release ticket.

  

  

Post-deploy validation

  

- Bake period = 30 min.
- Auto-collect metrics and publish perf_verification.json to S3.
- If SLO breach → invoke CodeDeploy rollback (OPS-001 §10).

  

  

  

8 Data Retention and Evidence Archive

  

|   |   |   |
|---|---|---|
|Artifact|Location|Retention|
|Perf metrics snapshot|s3://nc-perf-results/daily/YYYYMMDD/|365 days|
|Optimizer audit logs|/perf/optimizer/audit.log|2 years|
|Grafana snapshots|/perf/dashboards/archives/|1 year|
|Cost ETL parquet|s3://nc-finops/daily/|3 years Glacier|

All buckets KMS-encrypted; access restricted to PerfOps IAM role.

  

  

9 KPIs and Thresholds

  

|   |   |   |
|---|---|---|
|KPI|Target|Owner|
|Mean Time to Detect (MTTD)|< 5 min|SRE Lead|
|Mean Time to Optimize (MTTO)|< 24 h|FinOps Analyst|
|Performance Drift Events|0 critical / month|QA Lead|
|Budget Deviation|≤ 3 % forecast|Finance Ops|
|Automation Success Rate|≥ 95 %|Platform SRE|

  

10 Governance and Compliance

  

  

- Optimizer Lambdas use least-privilege IAM.
- Audit logs retained per REL-002.
- Changes mapped to ADR-011 “Performance-Cost gate.”
- Quarterly FinOps review validates budget and rightsizing.
- Annual load audit required to renew production readiness certificate.

  

  

  

11 Acceptance Criteria

  

  

- Real-time monitoring active for all services.
- Drift alerts validated in staging.
- FinOps dashboards render without errors.
- Optimization Lambda audits signed and reviewed.
- CI/CD gates enforce perf baseline comparison before release.

  

  

  

  

End of PERF-003 — Continuous Performance Monitoring and Optimization Framework

  

Confirm, then I’ll reproduce PERF-004 with the single authorized note in the thresholds clause.