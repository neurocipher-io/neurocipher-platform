id: COST-001
title: FinOps Governance and Cloud Cost Optimization Policy
owner: FinOps / Platform SRE / Finance Operations
status: Final v1.0
last_reviewed: 2025-11-06

COST-001 — FinOps Governance and Cloud Cost Optimization Policy

  

Document ID: COST-001

Title: FinOps Governance and Cloud Cost Optimization Policy

Status: Final v1.0

Owner: FinOps / Platform SRE / Finance Operations

Applies to: Neurocipher Core pipeline (see docs/integrations/)

Last Reviewed: 2025-11-06

References: PERF-001–005, OPS-001, CI/CL-003, ADR-009, ADR-011, REL-002

  

  

  

  

1 Purpose

  

  

Define governance, accountability, and automation standards for cloud cost visibility, control, and continuous optimization across all AWS environments. Establish a unified FinOps framework linking engineering actions to financial impact and ensuring efficient resource utilization.

  

  

  

  

2 Scope

  

  

Applies to all production, staging, and development AWS accounts (neurocipher-*, audithound-*).

Includes compute (Lambda, ECS/Fargate, EC2), storage (S3, DynamoDB, Weaviate, OpenSearch), network, observability, and data transfer.

Excludes local test rigs, employee devices, or external SaaS not under Neurocipher billing.

  

  

  

  

3 FinOps Operating Model

  

|   |   |   |
|---|---|---|
|Function|Role|Description|
|Visibility|FinOps Analyst|Collects and visualizes spend data|
|Optimization|Platform SRE|Implements tuning and scaling actions|
|Governance|Finance Ops|Enforces budgets, tags, and approvals|
|Accountability|Service Owner|Ensures service-level cost compliance|

Cycle: Collect → Analyze → Optimize → Report → Reinforce (monthly).

  

  

  

  

4 Governance Principles

  

  

1. Ownership: Every resource must have a clear owner tag.
2. Visibility: All spend must be traceable by App, Service, and Env.
3. Accountability: Each team is responsible for its AWS account budget.
4. Automation: Cost controls enforced via IaC, not manual action.
5. Efficiency: Idle or underutilized resources decommissioned within 48 hours.
6. Review Cadence: Weekly anomaly detection, monthly optimization reports.

  

  

  

  

  

5 Tagging and Attribution Policy

  

|   |   |   |
|---|---|---|
|Tag Key|Example|Purpose|
|App|Neurocipher or compliance module|Portfolio attribution|
|Service|ingest-api, embed-worker|Component attribution|
|Env|dev, stg, prod|Environment isolation|
|Owner|alice@example.com|Accountability|
|CostCenter|FINOPS-001|Financial reporting|
|Compliance|Yes / No|Audit linkage|
|Tenant|tenant-<id>|Cost attribution and isolation|

Tag enforcement via AWS Tag Policies and SCPs at the organization level.

  

  

  

  

6 Budget and Alert Policy

  

|   |   |   |
|---|---|---|
|Budget Type|Thresholds|Action|
|Account Budget|80 % warn / 100 % page|SNS alert to FinOps Slack|
|Service Budget|+10 % variance MoM|Jira ticket creation|
|Project Budget|Hard limit pre-approved by Finance Ops|CAB escalation if exceeded|

Daily check via AWS Budgets API and Cost Anomaly Detection.

  

  

  

  

7 Cost Data Architecture

  

  

Flow:

AWS CUR → S3 (parquet) → Glue Catalog → Athena / QuickSight → Grafana FinOps

Data Sources:

  

- AWS Cost and Usage Report (CUR) hourly granularity
- AWS Cost Explorer API for daily deltas
- Trusted Advisor and Compute Optimizer for rightsizing
- Perf capacity data from PERF-005

  

  

Data stored under s3://nc-finops/cur/YYYY/MM/DD/ and partitioned by account, service, and env.

  

  

  

  

8 Optimization Framework

  

|   |   |   |
|---|---|---|
|Category|Practice|Automation|
|Compute|Graviton adoption, SPOT 40 %, rightsizing weekly|Lambda auto-rightsizer|
|Storage|S3 lifecycle to IA/Glacier, DynamoDB auto-scaling|Terraform lifecycle policies|
|Network|CloudFront caching, VPC endpoint usage|IaC network module|
|Observability|Metric cardinality limits, log sampling|AMP + Firehose filter policies|
|Licensing|Open-source first, SaaS review quarterly|Procurement checklist|

FinOps dashboard displays monthly savings and service-specific efficiency ratios.

  

  

  

  

9 Reporting and KPIs

  

|   |   |   |
|---|---|---|
|KPI|Target|Source|
|Forecast accuracy|± 3 %|FinOps report|
|Cost per 1 000 requests|≤ $0.005|PERF-002|
|Monthly variance|≤ 3 %|AWS CUR|
|Rightsizing actions executed|≥ 90 %|Automation logs|
|Idle resources removed within|≤ 48 h|Config audit|

Reports

  

- Weekly: Summary posted to FinOps Slack.
- Monthly: PDF and JSON report archived to /finops/reports/YYYYMMDD/.
- Quarterly: Executive summary including cumulative savings and unit cost trends.

  

  

  

  

  

10 Anomaly Detection and Escalation

  

  

- Lambda cost-anomaly-detector scans CUR deltas for > 15 % deviation day-over-day.
- EventBridge Rule: triggers Slack + Jira ticket with cost impact and service context.
- Severity Mapping:  
    

- Minor (< 10 %) → log only
- Moderate (10–20 %) → FinOps ticket
- Critical (> 20 %) → CAB escalation + temporary freeze on new deploys

-   
    

  

  

  

  

  

11 Audit and Compliance

  

  

- FinOps audits quarterly using AWS Config and CUR verification scripts.
- Evidence retained 3 years in S3 Glacier (KMS encrypted).
- Compliance links:  
    

- REL-002 (alert and response retention)
- PERF-001 (cost-perf linkage)
- ADR-011 (board-level performance & cost review)

-   
    

  

  

Any missing tags, budget alerts, or untracked resources automatically fail governance check in CI pipeline.

  

  

  

  

12 KPIs and Review

  

|   |   |   |
|---|---|---|
|Review Frequency|Deliverable|Owner|
|Weekly|Cost anomaly summary|FinOps Analyst|
|Monthly|Optimization report + variance summary|Platform SRE|
|Quarterly|Budget re-baseline + governance audit|Finance Ops|
|Annual|Cost efficiency certification|CAB|

  

  

  

  

13 Acceptance Criteria

  

  

- All AWS accounts have active budgets and enforced tag policies.
- FinOps dashboard operational and accessible to SRE, Finance, and CAB.
- Automated anomaly detection active and producing alerts.
- Quarterly cost optimization review completed with archived evidence.
- Cost variance within ± 3 % forecast for the last quarter.

  

  

  

  

End of COST-001 — FinOps Governance and Cloud Cost Optimization Policy

  

  

  

Confirm if this matches your formatting exactly before I finalize the last file (ADR-011) with the latency and headroom corrections.