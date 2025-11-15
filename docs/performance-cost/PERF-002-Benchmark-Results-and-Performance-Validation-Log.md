id: PERF-002
title: Benchmark Results and Performance Validation Log
owner: Platform SRE / QA Performance Engineering
status: Final v1.0
last_reviewed: 2025-11-06

Document ID: PERF-002

Title: Benchmark Results and Performance Validation Log

Status: Final v1.0

Owner: Platform SRE / QA Performance Engineering

Applies to: Neurocipher Core pipeline (see docs/integrations/)

Last Reviewed: 2025-11-06

References: PERF-001, OPS-001, OBS-001-003, REL-002, ADR-011

  

  

  

  

1. Purpose

  

  

Capture empirical performance and cost efficiency results from controlled benchmark runs. Validate compliance with SLOs and identify optimization opportunities across compute, storage, and data pipelines.

  

  

  

  

2. Scope

  

  

Covers all production-equivalent environments (neurocipher-stg, neurocipher-prod) and the following workloads:

  

- Ingest API (FastAPI on Fargate)
- Normalize Lambda
- Embed Worker (ECS Fargate)
- Query API (hybrid search layer)
- compliance module compliance scanners

  

  

Synthetic and anonymized data only in staging. All results stored in S3 (s3://nc-perf-results/YYYYMMDD/).

  

  

  

  

3. Benchmark Configuration

  

|   |   |   |
|---|---|---|
|Parameter|Value / Tool|Notes|
|Load Tool|k6 v0.51|1 000 req/s ramp, 10 min steady-state|
|Region|ca-central-1|Same as production|
|Metrics Source|CloudWatch, AMP, X-Ray|Pulled via boto3 scripts|
|Baseline Data|perf_baseline.json|Contains previous run medians|
|Comparison Policy|≥ 10 % deviation triggers ticket|CI auto-flag|
|Storage Sink|S3 Parquet + Dynamo summary|Partitioned by date/service|
|Dashboards|Grafana FinOps + SRE panels|Linked to OBS-002 JSON|

  

  

  

  

4. Raw Test Scenarios

  

|   |   |   |   |   |   |
|---|---|---|---|---|---|
|ID|Service|Scenario|Load Pattern|Duration|Env|
|T-001|Ingest API|1 KB payload POST /ingest|0 → 1 000 rps|15 min|stg|
|T-002|Normalize Lambda|50 MB batch PDF|SQS batch 10|10 min|stg|
|T-003|Embed Worker|5 000 text chunks|Continuous queue feed|20 min|stg|
|T-004|Query API|hybrid search 512-token query|500 rps|15 min|stg|
|T-005|compliance module scan|IAM misconfig rule set|10 concurrent scans|30 min|stg|

Each scenario uses identical warm-up, sampling, and reporting defined in PERF-001 §4.

  

  

  

  

5. Summary Results

  

  

  

5.1 Aggregate KPIs

  

|   |   |   |   |
|---|---|---|---|
|Metric|Target|Achieved|Status|
|API latency (p95)|≤ 500 ms|412 ms|✅ Pass|
|Throughput|≥ 10 000 ev/min|12 480 ev/min|✅ Pass|
|Vector index latency|≤ 200 ms p95|178 ms|✅ Pass|
|Embed rate|≥ 1 000 docs/min|1 260 docs/min|✅ Pass|
|Pipeline freshness|≥ 99 % < 5 min|99.3 %|✅ Pass|
|Error rate|< 0.5 %|0.21 %|✅ Pass|
|Resource saturation|CPU < 80 %, Mem < 75 %|CPU 68 %, Mem 71 %|✅ Pass|

  

5.2 Cost KPIs

  

|   |   |   |   |   |
|---|---|---|---|---|
|KPI|Target|Observed|Variance|Notes|
|Cost / 1 000 req|≤ $0.005|$0.0047|-6 %|within budget|
|Storage growth MoM|< 10 %|+8 %|–|expected data rise|
|Compute efficiency|> 85 %|88 %|+3 %|optimized CPU sizing|
|Idle resource rate|< 5 %|3 %|-2 %|autoscale verified|
|Monthly spend variance|± 3 %|+1.4 %|ok|forecast alignment|

  

  

  

  

6. Detailed Breakdown by Service

  

  

  

6.1 Ingest API

  

  

- Mean latency = 410 ms, p95 = 487 ms, max = 605 ms.
- 0.18 % 5xx errors during cold start.
- Network TLS overhead 7 %.
- CloudFront cache hit ratio = 97 %.
- Improvement: enable gzip compression at gateway to cut 4 % bandwidth.

  

  

  

6.2 Normalize Lambda

  

  

- Avg duration = 1.8 s; concurrency peak = 14.
- Memory 512 MB → cost $0.0000012 per invocation.
- CPU bound 60 %, IO 35 %.
- Recommend 384 MB config for optimal cost/runtime trade-off.

  

  

  

6.3 Embed Worker (ECS)

  

  

- CPU 68 %, Mem 73 %, IO wait 5 %.
- Task count scaled 3 → 6 automatically at queue depth > 50.
- Avg embedding throughput = 1 260 docs/min.
- Cost ≈ $0.0021 per 1 000 embeds.
- Recommendation: reserve CPU 1024 Mi for steady loads; no change required.

  

  

  

6.4 Query API

  

  

- Hybrid search fusion latency = 178 ms p95.
- Weaviate 120 ms vector + OpenSearch 45 ms keyword.
- RRF fusion overhead = 13 ms.
- P95 success 99.8 %.
- Cost $7.12 / month for Weaviate compute.

  

  

  

6.5 compliance module Scan Workers

  

  

- IAM policy parse 3.2 s avg per account.
- Parallelism = 10 threads.
- Total scan time reduced 18 % vs previous run (ADR-011 ref).
- Lambda concurrency scale stable.
- Budget $24.6 / month → -11 % from baseline.

  

  

  

  

  

7. Anomalies and Remediations

  

|   |   |   |   |
|---|---|---|---|
|ID|Observation|Impact|Resolution|
|A-001|Occasional SQS lag spike to > 150 s|Minor (queue drained < 2 min)|Increased consumer concurrency threshold to 8|
|A-002|Trivy scan latency +20 % on Fargate images|None (user inactive window)|Scheduled scan off-peak|
|A-003|Grafana dashboard API 429 errors during test|Visualization lag only|Raised AMP API quota|
|A-004|Weaviate snapshot delay > 10 min|None|Move snapshot to separate IO-optimized volume|

  

  

  

  

8. Recommendations

  

  

- Reduce Lambda memory to 384 MB (-11 % cost).
- Evaluate Graviton-based Fargate profiles for 5–10 % savings.
- Implement automatic compression for normalized JSON in S3.
- Enable CloudFront tiered caching for Query API.
- Continue monthly FinOps audit and re-benchmark after next release.

  

  

  

  

  

9. Evidence Archive

  

|   |   |
|---|---|
|Artifact|Location|
|k6 raw results|s3://nc-perf-results/20251106/k6_results.json|
|CloudWatch metrics dump|s3://nc-perf-results/20251106/metrics.parquet|
|Grafana snapshot|/perf/results/20251106/dashboard-snapshot.json|
|Cost Explorer export|/finops/reports/20251106_cost.json|
|Signed verification hash|/perf/results/20251106/SHA256SUMS.txt|

All files KMS-encrypted; retention = 2 years per PERF-001 §7.

  

  

  

  

10. Acceptance Criteria

  

  

- All benchmarks executed with versioned IaC and code SHA.
- Every SLO met or exceeded.
- Cost deviation ≤ 3 % from forecast.
- Evidence artifacts uploaded and checksummed.
- CAB acknowledgment recorded under ADR-011 entry.

  

  

  

  

End of PERF-002 — Benchmark Results and Performance Validation Log