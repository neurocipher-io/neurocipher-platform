

PERF-001 — Performance and Cost Management Specification

  

Document ID: PERF-001

Title: Performance and Cost Management Specification

Status: Final v1.0

Owner: Platform SRE / FinOps

Applies to: Neurocipher Core and AuditHound module

Last Reviewed: 2025-11-06

References: ADR-005, ADR-009, OPS-001, OBS-001-003, REL-002, CI/CL-001-003

  

  

  

  

1 Purpose

  

  

Establish quantitative performance targets, measurement procedures, and cost-control mechanisms for all AWS-hosted workloads in the Neurocipher ecosystem. Defines SLIs/SLOs, benchmarking methodology, and FinOps optimization practices ensuring predictable latency, throughput, and expenditure.

  

  

  

  

2 Scope

  

  

Applies to ingestion APIs, embedding and normalization services, vector index, AuditHound scanning workers, and orchestration runtimes deployed on AWS Lambda, ECS Fargate, and Step Functions.

Excludes developer workstations, local test environments, and third-party SaaS tools.

  

  

  

  

3 Performance Objectives

  

|   |   |   |
|---|---|---|
|Area|Target|Metric Source|
|API latency|≤ 300 ms p95 (reads) / ≤ 600 ms p95 (writes)|CloudWatch → AMP|
|Throughput|≥ 10 000 ingest events / min sustained|SQS metrics|
|Vector index latency|≤ 200 ms p95|Weaviate telemetry|
|Batch embed rate|≥ 1 000 docs / min per worker|ECS Task metrics|
|Pipeline freshness|≥ 99 % < 5 min end-to-index|ADOT traces|
|Error rate|< 0.5 % 5xx / total|CloudWatch logs|
|Async job success|≥ 99.5 %|DLQ depth|
|Resource saturation|CPU < 80 %, Memory < 75 %|ECS/Lambda metrics|

SLOs are enforced through AMP Alertmanager and CloudWatch alarms per OPS-001 §9 and OBS-003.

  

  

  

  

4 Benchmarking Procedure

  

  

1. Load profile generation: k6 scenarios (ramp 0→1 000 req/s).
2. Warm-up window: 2 min to allow autoscaling stabilization.
3. Steady-state sampling: 10 min, 99 % confidence interval on latency histograms.
4. Regression detection: ≥ 10 % deviation from baseline flags performance ticket.
5. Recordkeeping: Grafana snapshot and JSON export archived in /perf/results/YYYYMMDD/.

  

  

All tests executed in staging (neurocipher-stg) using sanitized data.

  

  

  

  

5 Scaling and Auto-Tuning

  

  

- Lambda: Concurrency = (throughput ÷ avg duration × 1.1). Memory auto-tuned weekly for lowest cost per 100 ms.
- Fargate: Target CPU 60 %, Memory 70 %. Autoscale 1–10 tasks based on queue age > 60 s.
- SQS: Visibility Timeout = avg proc × 2. DLQ threshold = 100 messages.
- Weaviate/OpenSearch: ILM hot 30 days → warm 90 days. Shard size 50 GB max.

  

  

  

  

  

6 Cost Management Framework

  

|   |   |   |
|---|---|---|
|Category|Control|Tooling / Policy|
|Budgets|80 % warn / 100 % page per account|AWS Budgets|
|Tagging|App,Service,Env,Owner,CostCenter required|Org tag policy|
|Compute rightsizing|Weekly Fargate and Lambda analyzer|Compute Optimizer|
|Storage lifecycle|Logs → IA 30 days → Glacier 1 yr|S3 Lifecycle|
|Data egress|CDN cache hit > 95 %|CloudFront metrics|
|Idle resource shutdown|Scale-to-zero queues, stop dev clusters after 2 h idle|Automation Lambda|
|Cross-region|Replicate only critical state stores|Backup policy|
|Cost visibility|Grafana FinOps dashboard + Cost Explorer API feed|FinOps module|

Monthly cost reports attached to REL-002 Reliability Report; trend deviation > 15 % creates FinOps ticket.

  

  

  

  

7 Data Retention and Cost Balance

  

|   |   |   |   |
|---|---|---|---|
|Data Type|Hot|Archive|Policy|
|Logs|7 days (CloudWatch)|365 days (S3 IA)|Compression + partitioned Parquet|
|Metrics|30 days (AMP)|–|Cardinality guardrails|
|Traces|30 days (X-Ray)|–|10 % sampling + p99 always sample|
|Snapshots / Backups|7 days daily PITR|30 days Glacier|KMS encrypted|

  

  

  

  

8 FinOps KPI Targets

  

|   |   |   |
|---|---|---|
|KPI|Target|Source|
|Cost per 1 000 requests|≤ $0.005|AWS Cost Explorer|
|Storage cost growth|< 10 % MoM|S3 reports|
|Compute efficiency|65–80 % avg utilization (steady)|CloudWatch|
|Burst efficiency|> 85 % for ≤ 10 min bursts|CloudWatch|
|Idle resource rate|< 5 %|Config compliance|
|Total monthly spend variance|± 3 % forecast|FinOps reports|

  

  

  

  

9 Reporting and Review

  

  

- Weekly: Ops Dashboard → SRE lead, FinOps analyst.
- Monthly: Reliability & Cost Review meeting; attach trend, anomaly summary, budget status.
- Quarterly: Re-benchmark services; update autoscaling baselines; evaluate instance families and reserved capacity options.
- Annual: Comprehensive performance audit with load and cost simulation; results linked to ADR-011 Performance and Cost Evaluation Record.

  

  

  

  

  

10 Compliance and Acceptance Criteria

  

  

- All services emit RED/USE metrics and cost tags.
- Budget alarms and FinOps reports configured per account.
- Autoscaling policies validated in staging.
- Benchmark reports archived and referenced in release tickets.
- No untracked resources in AWS Config inventory.
- SLO breach or budget overrun triggers incident per OBS-003 §9.

  

  

  

  

End of PERF-001 — Performance and Cost Management Specification

