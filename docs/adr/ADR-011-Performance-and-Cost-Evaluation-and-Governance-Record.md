id: ADR-011
title: Performance and Cost Evaluation and Governance Record
owner: Architecture Review Board (ARB) / Platform SRE / FinOps
status: Final v1.0
last_reviewed: 2025-11-06

ADR-011 — Performance and Cost Evaluation and Governance Record

  

Status: Final v1.0

Owner: Architecture Review Board (ARB) / Platform SRE / FinOps

Applies to: Neurocipher Core pipeline (see docs/integrations/)

Last Reviewed: 2025-11-06

References: PERF-001–005, COST-001, OPS-001, CI/CL-003, ADR-009, REL-002

  

  

  

  

1 Purpose

  

  

Record the unified architectural decision to evaluate every release of the Neurocipher platform against both technical performance and financial efficiency criteria before production promotion. Establish compliance linkage between Performance (PERF) and Cost (COST) domains for automated governance.

  

  

  

  

2 Context

  

  

Earlier ADRs (ADR-005, ADR-009, PERF-001) treated performance and cost validation separately. High-load scenarios sometimes met latency SLOs but violated FinOps budgets. This ADR binds both controls into a single release gate under CI/CD governance.

  

  

  

  

3 Decision

  

  

Adopt a Performance–Cost Evaluation Framework binding SLO verification and FinOps thresholds as mandatory deployment gates.

  

- Integrate COST-001 KPIs into PERF-004 release certification.
- Require FinOps variance checks and PERF certification as CAB inputs.
- Fail promotion if either latency or budget criteria exceed tolerance.
- Automate collection of cost metrics (CUR/Athena) within CI.
- Maintain immutable evidence packages per release.

  

  

  

  

  

4 Rationale

  

  

Coupling technical and financial controls prevents “fast but expensive” regressions and enables quantitative audits of every production release.

  

  

  

  

5 Implementation

  

  

CI/CD Integration Flow

  

1. perf-baseline-compare runs after build.
2. finops-gate queries AWS Cost Explorer for forecast delta.
3. Results merged into perf_cost_report.json.
4. Fail if any metric breaches:  
    

- Latency p95 > 300 ms (reads) or > 600 ms (writes)
- Error rate > 0.5 %
- Cost per 1 000 req > $0.005
- Monthly variance > ± 3 %

6.   
    
7. Report attached to release ticket.

  

  

Job fragment

jobs:

  perf_cost_gate:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - run: python tools/perf_cost_gate.py --thresholds thresholds.yml

      - uses: actions/upload-artifact@v4

        with:

          name: perf_cost_report

          path: perf_cost_report.json

  

  

  

  

6 Evaluation Model

  

|   |   |   |   |
|---|---|---|---|
|Metric|Source|Threshold|Owner|
|API latency p95|CloudWatch / AMP|≤ 300 ms (reads) / ≤ 600 ms (writes)|QA Perf Eng|
|Error rate|CloudWatch|≤ 0.5 %|SRE|
|Cost / 1 000 req|Athena CUR query|≤ $0.005|FinOps|
|Monthly variance|CUR forecast|± 3 %|Finance Ops|
|CPU / Memory headroom|CloudWatch|≥ 30 %|Platform SRE|

  

  

  

  

7 Related Standards

  

|   |   |
|---|---|
|Document|Purpose|
|PERF-001|Baseline performance & cost policy|
|PERF-002|Benchmark evidence|
|PERF-003|Continuous monitoring|
|PERF-004|Regression testing & release cert|
|PERF-005|Capacity planning|
|COST-001|FinOps governance & optimization|
|OPS-001|Environment and SRE operations|
|CI/CL-003|Release management & change control|

  

  

  

  

8 Consequences

  

  

- Deployments blocked if FinOps or Perf gates fail.
- CAB approval requires PERF-004 PASS + ≤ 3 % variance.
- Budget breach triggers rollback or freeze.
- Performance–cost data version-aligned per release.
- SRE maintains quarterly correlation report.

  

  

  

  

  

9 Evidence and Audit Pack

  

|   |   |   |
|---|---|---|
|Artifact|Source|Retention|
|PERF-004 certificate|CI pipeline|2 yrs|
|PERF-002 logs|S3 nc-perf-results/|2 yrs|
|CUR/Athena cost report|nc-finops/reports/|3 yrs Glacier|
|perf_cost_report.json|CI artifact|2 yrs|
|CAB approval record|Jira / GitHub|Permanent|

  

  

  

  

10 Compliance Mapping

  

|   |   |
|---|---|
|Framework|Mapping|
|CI/CL-003|Adds finops-gate and perf-baseline-compare.|
|OPS-001|Bake verification includes cost delta.|
|OBS-003|Budget alerts routed to SLO channels.|
|COST-001|Tag and budget policy feed the gate.|
|PERF-003/004|Provide runtime and release validation data.|

  

  

  

  

11 KPIs

  

|   |   |   |
|---|---|---|
|KPI|Target|Review|
|Releases passing Perf–Cost gate|100 %|Monthly|
|Forecast accuracy|± 3 %|Monthly|
|Unit-cost stability|≤ 5 % variance QoQ|Quarterly|
|Evidence completeness|100 %|Quarterly|

  

  

  

  

12 Acceptance Criteria

  

  

- All PERF and COST docs Final v1.0.
- finops-gate enforced in CI/CD.
- Evidence pack per production deployment.
- CAB approval dependent on PASS.
- Quarterly audit confirms compliance to this ADR.

  

  

  

  

End of ADR-011 — Performance and Cost Evaluation and Governance Record