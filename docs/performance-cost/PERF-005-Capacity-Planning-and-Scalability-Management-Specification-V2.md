id: PERF-005
title: Capacity Planning and Scalability Management Specification
owner: Platform SRE / FinOps / Infrastructure Architecture
status: Final v1.0
last_reviewed: 2025-11-06

PERF-005 — Capacity Planning and Scalability Management Specification

  

Document ID: PERF-005

Title: Capacity Planning and Scalability Management Specification

Status: Final v1.0

Owner: Platform SRE / FinOps / Infrastructure Architecture

Applies to: Neurocipher Core pipeline (see docs/integrations/)

Last Reviewed: 2025-11-06

References: PERF-001–004, OPS-001, CI/CL-003, ADR-009, REL-001, REL-002, CAP-001

  

  

  

  

1 Purpose

  

  

Define quantitative methods and operational policies for predicting, provisioning, and maintaining compute, storage, and network capacity at optimal cost. Provide scaling models, forecasting rules, and review cadence ensuring SLO adherence during sustained or peak load.

  

  

  

  

2 Scope

  

  

Applies to all production and staging AWS environments (neurocipher-prod, neurocipher-stg, audithound-prod, audithound-stg).

Covers ECS/Fargate clusters, Lambda concurrency, SQS/Kinesis buffers, DynamoDB, Weaviate, OpenSearch, and S3.

Excludes local developer environments and synthetic test stacks.

  

  

  

  

3 Capacity Planning Framework

  

  

Objectives

  

- Maintain ≥30 % buffer headroom for compute and storage.
- Forecast 3-month growth horizon with ±10 % accuracy.
- Keep cost per throughput unit ≤ baseline + 5 %.

  

  

Forecast Method

  

- Inputs: historical metrics from AMP, CloudWatch, and Cost Explorer.
- Model: exponential weighted moving average (EWMA) with daily smoothing factor = 0.3.
- Tooling: AWS Forecast (optional) or Athena queries on perf_capacity.parquet.

  

  

  

  

  

4 Compute Capacity Model

  

|   |   |   |   |   |
|---|---|---|---|---|
|Workload|Baseline (steady)|Max (burst)|Scaling Policy|Notes|
|Ingest API (Fargate)|2 vCPU / 4 GB × 4 tasks|2 vCPU / 4 GB × 12 tasks|Target CPU 60 %, queue depth > 50 msgs|Blue-green deploy pattern|
|Normalize Lambda|512 MB × 20 concurrency|512 MB × 60 concurrency|SQS depth > 100 msgs|Memory tuned weekly|
|Embed Worker (ECS)|2 vCPU / 4 GB × 3 tasks|4 vCPU / 8 GB × 10 tasks|Step scaling on CPU > 75 %|Runs on SPOT 40 %|
|Query API (Fargate)|2 vCPU / 4 GB × 2 tasks|2 vCPU / 4 GB × 8 tasks|Target CPU 65 %, p95 latency > 500 ms|Always on Graviton|
|compliance module Scan Worker|1 vCPU / 2 GB × 5 tasks|1 vCPU / 2 GB × 15 tasks|Parallel scan count > 10|Burst billing budgeted|

All policies codified in Terraform modules /iac/modules/ecs_autoscale/ and /iac/modules/lambda_autoscale/.

  

  

  

  

5 Storage and Database Capacity

  

|   |   |   |   |   |
|---|---|---|---|---|
|Store|Baseline|Max Growth|Policy|Monitoring|
|DynamoDB|50 R/WCU per table|Auto-scaling × 5|On-demand; throttle alert > 1 %|CloudWatch metric ConsumedReadCapacityUnits|
|S3 (raw + norm)|5 TB hot → IA after 30 days|Unlimited|Lifecycle tiers (IA → Glacier)|Storage Lens + Cost Explorer|
|Weaviate|500 GB per shard|Add shard ≥ 70 % used|Horizontal scale EC2 or managed cluster|Custom health probe /v1/meta|
|OpenSearch Serverless|2 collections, 200 GB each|Add collection > 75 % full|ILM hot/warm rollover|Index stats dashboard|

  

  

  

  

6 Network and Throughput Planning

  

  

- API Gateway: provisioned concurrency = 50 req/s baseline; burst = 500 req/s.
- SQS: expected ingest 12 k msg/min; scale consumer pools linearly with queue age > 60 s.
- VPC Bandwidth: 10 Gbps baseline; CloudWatch NetworkOut alert > 80 %.
- CloudFront: cache hit target ≥ 95 %.

  

  

  

  

  

7 Forecasting and Review Cycle

  

|   |   |   |   |
|---|---|---|---|
|Frequency|Task|Owner|Output|
|Weekly|Review CPU/mem utilization & autoscale events|SRE|Perf summary|
|Monthly|Forecast compute & storage 3 months ahead|FinOps|Capacity forecast report|
|Quarterly|Run synthetic load test (PERF-002) for validation|QA Perf Eng|Updated baselines|
|Annual|DR and HA capacity validation (REL-001)|Platform Lead|Audit report|

Forecast outputs stored in /perf/capacity/reports/YYYYMMDD.json and plotted on Grafana Capacity Overview dashboard.

  

  

  

  

8 Cost Modeling and Efficiency

  

  

Cost per Resource Unit (USD/hr)

  

- Lambda = $0.000001667 × mem(MB)/1024 × duration(100 ms).
- Fargate = $0.04048 × vCPU + $0.004445 × GB.
- DynamoDB = $0.25 per million R/WCU.
- Weaviate EC2 = $0.096/hr (t4g.large).

  

  

Optimization Rules

  

- Favor Graviton for all ECS clusters.
- Use SPOT ≤ 40 % mix.
- Downscale to zero for idle async queues.
- Commit 1-year Savings Plans when 90-day avg util > 70 %.

  

  

  

  

  

9 Alerting Thresholds

  

|   |   |   |
|---|---|---|
|Metric|Threshold|Action|
|CPUUtilization|> 85 % for 10 min|Add 1 task|
|MemoryUtilization|> 80 % for 10 min|Scale up tier|
|QueueAge|> 120 s|Increase consumers|
|DynamoDBThrottleEvents|> 0|Double RCU/WCU|
|DiskUsage|> 75 %|Add volume/shard|
|BudgetUtilization|> 90 %|Page FinOps on Slack|

  

  

  

  

10 Tooling and Automation

  

  

- Lambda capacity-planner — nightly forecast update to DynamoDB perf_capacity_forecast.
- Step Function auto-rightsizer — analyzes utilization and modifies ECS task size.
- GitHub Action capacity-drift-check — fails PR if forecast > budget limit.
- Grafana Panel Capacity vs Demand — live variance visualization.

  

  

All changes versioned and logged under /perf/automation/audit.log.

  

  

  

  

11 KPIs

  

|   |   |   |
|---|---|---|
|KPI|Target|Source|
|Forecast accuracy|±10 %|Athena query variance|
|Compute utilization|65–80 % (steady), short bursts > 85 % allowed|CloudWatch metrics|
|Storage utilization|≤ 70 %|S3 + Weaviate stats|
|Autoscale success|≥ 95 %|EventBridge logs|
|Cost variance|≤ 3 % budget|FinOps dashboard|

  

  

  

  

12 Compliance and Acceptance Criteria

  

  

- Forecast automation operational and validated.
- Headroom ≥ 30 % on all critical paths.
- Autoscale alarms verified in staging.
- Capacity reports archived quarterly.
- SRE and FinOps jointly sign off forecast accuracy under ±10 %.
- No production throttle or OOM events in past 30 days.

  

  

  

  

End of PERF-005 — Capacity Planning and Scalability Management Specification

  

  

  

Confirm this matches your structure before I continue to COST-001 with the tag and variance corrections.
