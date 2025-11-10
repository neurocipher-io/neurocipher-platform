
PERF-004 — Performance Regression Testing and Release Certification

  

Document ID: PERF-004

Title: Performance Regression Testing and Release Certification

Status: Final v1.0

Owner: QA Performance Engineering / Platform SRE

Applies to: Neurocipher Core and AuditHound module

Last Reviewed: 2025-11-06

References: PERF-001-003, OPS-001, CI/CL-001-003, ADR-011, REL-002

  

  

  

  

1 Purpose

  

  

Define a repeatable, automated process to detect and prevent performance regressions before production promotion. Establish pass/fail certification criteria tied to SLO compliance, benchmark deltas, and cost thresholds for every release.

  

  

2 Scope

  

  

Applies to all deployable services—APIs, Lambdas, Fargate workers, Step Functions, and scheduled jobs—in dev, stg, and prod AWS accounts.

Covers load, stress, endurance, and scalability testing phases integrated into CI/CD workflows.

  

  

3 Objectives

  

  

- Detect regressions ≥ 5 % against previous baselines.
- Certify every release against SLOs and cost ceilings.
- Generate machine-readable performance certificates archived in GitHub and S3.
- Automate gating and rollback triggers when regressions exceed tolerance.

  

  

  

4 Test Architecture

  

|   |   |   |
|---|---|---|
|Component|Service|Function|
|Generator|k6 / Locust|Synthetic HTTP and async load|
|Orchestrator|GitHub Actions + Step Functions|Parallel test execution|
|Observability|ADOT → AMP → Grafana|Real-time metrics ingestion|
|Data Store|S3 nc-perf-results bucket|Raw test logs & reports|
|Comparator|Lambda perf-compare|Delta vs baseline and SLO matrix|
|Reporter|GitHub Action / Slack bot|Publish results and certification status|

  

  

  

  

5 Test Categories

  

|   |   |   |   |
|---|---|---|---|
|Category|Purpose|Duration|Metrics|
|Smoke|Validate endpoints live & healthy|< 5 min|availability, 5xx rate|
|Load|Validate throughput & latency at target load|15 min|p95 latency, throughput|
|Stress|Identify max sustainable throughput|20 min ramp|error rate, saturation|
|Endurance|Detect leaks or throttling|60 min steady|memory, CPU trends|
|Cost Drift|Validate cost/1 000 req within ± 5 %|after run|Cost Explorer export|

All categories run automatically per release tag.

  

  

  

  

6 Regression Detection Logic

  

  

Inputs: baseline.json, current.json, perf_thresholds.yml

  

Algorithm

for metric in metrics:

    delta = (current[metric] - baseline[metric]) / baseline[metric]

    if delta > threshold[metric]:

        status = "FAIL"

Thresholds

|   |   |
|---|---|
|Metric|Tolerance|
|Latency p95|+10 % (must remain ≤ 300 ms reads / ≤ 600 ms writes)|
|Error Rate|+0.2 %|
|Throughput|−5 %|
|CPU Utilization|+10 %|
|Cost per 1 000 req|+5 %|

  

  

  

  

7 CI/CD Integration

  

  

Workflow: test-perf.yml executed on release/* branches.

  

1. Build service image (CI/CL-001).
2. Deploy to ephemeral stack (stg-perf-<sha>).
3. Run automated perf suite (k6).
4. Invoke perf-compare Lambda.
5. Post result badge to PR.
6. Fail deployment if any metric exceeds threshold.
7. On pass, generate signed certificate and upload to S3.

  

  

Certificate Schema

{

  "service": "ingest-api",

  "version": "v1.4.2",

  "commit": "abc1234",

  "date": "2025-11-06T18:00Z",

  "status": "PASS",

  "metrics": { "latency_p95": 432, "error_rate": 0.22, "throughput": 10600 },

  "cost_per_1000_req": 0.0049,

  "approvers": ["qa-lead","sre-lead"],

  "signature": "cosign-keyless"

}

Certificates stored in /perf/certificates/YYYYMMDD/ and attached to the release ticket.

  

  

  

  

8 Dashboards and Reports

  

  

Grafana “Release Perf Certification” board aggregates:

  

- Current vs baseline deltas
- Pass/fail counts per metric
- Cost efficiency trends
- Historical regression chart (rolling 5 releases)

  

  

Report PDF auto-generated and emailed to CAB members post-deploy.

  

  

  

  

9 Governance and Approvals

  

  

- QA Lead → signs functional validation
- SRE Lead → signs infrastructure readiness
- Security → reviews load-test boundaries (no PII exposure)
- CAB → approves promotion to prod if PERF-004 status = PASS

  

  

Failures block deployment and open Jira ticket PERF-REG-####.

  

  

  

  

10 Data Retention

  

|   |   |   |
|---|---|---|
|Artifact|Retention|Storage|
|Raw k6 results|1 year|S3 (KMS)|
|Comparison reports|2 years|S3 Glacier|
|Certificates|2 years|GitHub + S3|
|Grafana snapshots|1 year|/perf/dashboards/|

  

  

  

  

11 KPIs

  

|   |   |
|---|---|
|KPI|Target|
|Regression detection accuracy|≥ 95 %|
|Certification turnaround|< 45 min from tag|
|Release rollback latency|< 15 min post-fail|
|Coverage across services|100 % deployables|

  

  

  

  

12 Acceptance Criteria

  

  

- Automated regression suite integrated into CI/CD.
- All metrics baselined in perf_baseline.json.
- Certificates generated and archived per release.
- CAB approval contingent on PASS status.
- No unverified service promoted to production.

  

  

  

  

End of PERF-004 — Performance Regression Testing and Release Certification

  

  

  

Confirm this reproduction matches the uploaded file structure before I generate PERF-005 with the adjusted utilization KPI.