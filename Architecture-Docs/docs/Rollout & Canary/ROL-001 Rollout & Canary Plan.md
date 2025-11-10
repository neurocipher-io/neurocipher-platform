
---

# **Document ID: ROL-001**

  

Title: Rollout and Canary Plan

Status: Final v1.4

Owner: Platform SRE / Release Engineering

Applies to: Neurocipher Core and AuditHound Module

Last Reviewed: 2025-11-09

References: REF-001, GOV-001, GOV-002, CI/CL-001–003, OBS-001–003, CAP-001, DQ-001, SRG-001, DCON-001, DM-001–005, PROC-001–003, LAK-001, LIN-001, SVC-001, SVC-002, REL-002

---

## **Purpose**

  

Establish a governed, auditable process for phased deployments across Neurocipher Core environments.

Ensures safety, observability, and rollback certainty for infrastructure, application, and data-pipeline changes under unified SLO and compliance control.

---

## **Scope**

  

**In scope**

- ECS Fargate, Lambda, API Gateway, Step Functions, and data pipeline deployments.
    
- Progressive rollout models (canary, blue/green, shadow, expand/contract).
    
- SLO validation and automated rollback per [OBS-003].
    
- Integration with CI/CD governance ([CI/CL-001–003]).
    

  

**Out of scope**

- Manual QA testing ([REL-002]).
    
- DR failover (covered by DR-001).
    

---

## **Rollout Framework**

  

Deployments follow a controlled three-phase promotion model.

|**Phase**|**Environment**|**Objective**|**Promotion Criteria**|
|---|---|---|---|
|1|dev|Functional verification|All CI tests pass|
|2|stg|Synthetic load + canary|≥ 95 % success and SLO baseline green|
|3|prod|Gradual traffic promotion|Error ≤ 0.5 %, P95 latency ≤ 250 ms, availability ≥ 99.9 %|

Promotion to production requires [CI/CL-003] CAB approval and validated SLO evidence from [OBS-003].

---

## **Rollout and Canary Strategy**

  

**Traffic sequence:** 10 % → 25 % → 50 % → 100 %, 15-minute dwell each step.

**Implementation:** Custom CodeDeploy config (nc-ecs-linear-10pct-15m) or Route 53 weighted routing fallback.

  

### **Cohorts**

1. Internal traffic (scope tagged or header-flagged).
    
2. Regional subset (single AZ or subnet).
    
3. Full user base post stabilization.
    

  

### **Shadow Traffic**

- Enabled for risk classes C3/C4. Mirrors ≈ 5 % production read requests.
    
- Responses discarded; diff metrics stored for regression analysis.
    

  

### **Data-Aware Rollouts (Expand/Contract)**

|**Stage**|**Action**|**Verification**|
|---|---|---|
|Expand|Add new schema objects|[SRG-001] digest registered|
|Dual-write|Write old + new|[LIN-001] lineage edges present|
|Cutover|Readers switch|DQ tests 0 violations ([DQ-001])|
|Contract|Remove legacy path|CAB sign-off + audit record|

---

## **IAM and Security Controls**

- Deploy role arn:aws:iam::<account-id>:role/nc-<env>-github-oidc-deploy.
    
- Runtime roles nc-<env>-svc-<service>-task / nc-<env>-svc-<service>-fn.
    
- ABAC tags (env,service,team).
    
- KMS CMKs for all buckets and logs.
    
- Secrets in AWS Secrets Manager (SSM retrieval).
    
- CloudTrail enabled for CodePipeline/Deploy/APIGW/Route 53.
    
- Compliant with [GOV-002] SOC 2 Type II change control.
    

---

## **Observability and SLO Gates**

|**Metric**|**Target**|**Gate Condition**|**Source**|
|---|---|---|---|
|Deployment success rate|≥ 99 %|< 97 % halts|CodeDeploy|
|P95 latency|≤ 250 ms|≥ 400 ms pauses|CloudWatch|
|Error rate|≤ 0.5 %|≥ 1 % aborts|ADOT Collector|
|Availability|≥ 99.9 %|< 99.7 % halts|Route 53|
|Rollback convergence|≤ 5 min|≥ 10 min alert|Step Functions|
|Canary failure rate|≤ 1 %|≥ 2 % aborts|Grafana panel ROL-001|

All metrics surface in Grafana dashboards; alerts route via PagerDuty ([OBS-002]).

---

## **CI/CD Integration**

  

**Continuous Integration ([CI/CL-001])**

- Validate rol_manifest.yaml.
    
- Check custom deployment config exists.
    
- Verify schema digests ([SRG-001], [DCON-001]).
    

  

**Continuous Delivery ([CI/CL-002])**

- Execute blue/green rollout with linear canary steps.
    
- Fallback to Route 53 controller on error.
    

  

**Change Control ([CI/CL-003])**

- CAB approval required for prod promotion.
    
- Attach evidence pack to ticket.
    

  

**Rollback**

Automatic trigger on threshold breach or manual abort.

ECS → previous task definition; Lambda → previous alias; API Gateway → previous stage.

---

## **Governance and Data Compliance**

|**Asset**|**Standard**|**Lifecycle**|
|---|---|---|
|Rollout Manifest|[GOV-001]|Versioned 7 years|
|Deployment Logs|[OBS-001]|90 days|
|Metrics and Traces|[OBS-002]|90 days|
|Audit Records|[GOV-002]|7 years|
|Evidence Packs|[GOV-002]|7 years|

Artifacts reside in s3://nc-<env>-rol-artifacts/ with KMS encryption and access logs.

---

## **Acceptance Criteria**

1. Rollout executes ≤ 60 min under SLO compliance.
    
2. Rollback restores prior state ≤ 5 min.
    
3. No schema drift vs [DCON-001]; all digests match [SRG-001].
    
4. Evidence pack (logs, metrics, manifest hash, DQ report) attached to CAB ticket.
    
5. All gates green per [OBS-003].
    

---

## **Change Log**

|**Version**|**Date**|**Description**|**Author**|
|---|---|---|---|
|v1.4|2025-11-09|REF-001 compliant + restored operational sections|Platform SRE / Release Eng|
|v1.3|2025-11-09|Compliance structure alignment|Platform SRE / Release Eng|
|v1.2|2025-11-09|Expanded ops content|Platform SRE / Release Eng|
|v1.1|2025-11-09|Canary sequence and IAM fix|Platform SRE / Release Eng|
|v1.0|2025-11-09|Initial release|Platform SRE / Release Eng|

---

## **Appendix A – Example Rollout Manifest (YAML)**

```
rollout_id: nc-<env>-svc-weaviate-v2
strategy: canary
steps:
  - traffic: 10
    dwell_minutes: 15
  - traffic: 25
    dwell_minutes: 15
  - traffic: 50
    dwell_minutes: 15
  - traffic: 100
    dwell_minutes: 15
slo_gates:
  p95_latency_ms: 250
  error_rate_pct: 0.5
  availability_pct: 99.9
rollback_policy:
  trigger_error_rate_pct: 1.0
  trigger_latency_ms: 400
  trigger_availability_pct: 99.5
artifacts_bucket: s3://nc-<env>-rol-artifacts/svc-weaviate/
manifest_sha256: "<computed-in-ci>"
```

---

## **Appendix B – CI/CD Deployment Snippet**

```
name: Rollout and Canary Deployment
on: { workflow_dispatch: {} }
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions: { id-token: write, contents: read }
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/nc-prod-github-oidc-deploy
          aws-region: ca-central-1
      - name: Validate Manifest
        run: spectral lint rol/rol_manifest.yaml
      - name: Ensure Custom Deployment Config
        run: |
          aws deploy get-deployment-config --deployment-config-name nc-ecs-linear-10pct-15m \
          || aws deploy create-deployment-config \
             --deployment-config-name nc-ecs-linear-10pct-15m \
             --compute-platform ECS \
             --traffic-routing-config type=TimeBasedLinear,linearInterval=15,linearPercentage=10
      - name: Create Deployment
        run: |
          aws deploy create-deployment \
            --application-name nc-core \
            --deployment-group-name svc-weaviate \
            --deployment-config-name nc-ecs-linear-10pct-15m \
            --s3-location bucket=nc-prod-rol-artifacts,key=svc-weaviate-v2.zip,bundleType=zip
      - name: Fallback Controller
        if: failure()
        run: |
          aws stepfunctions start-execution \
            --state-machine-arn arn:aws:states:ca-central-1:${{ secrets.AWS_ACCOUNT_ID }}:stateMachine:rol-canary-controller \
            --input file://rol/route53_weights_10_25_50_100.json
```

---

## **Appendix C – Risk Matrix**

|**Risk**|**Likelihood**|**Impact**|**Mitigation**|
|---|---|---|---|
|Hidden performance regression|M|H|Shadow traffic + synthetic tests|
|Schema contract drift|L|H|Digest pinning ([SRG-001])|
|Data corruption in backfill|L|H|Idempotent jobs + DQ gate|
|Hot shard imbalance|M|M|Shard pre-split + CAP-001 caps|
|Cost spike from autoscale|M|M|Budget alarms + CAP limits|

---

## **Appendix D – Communications Plan**

- **T-24 h:** Notify stakeholders and on-call.
    
- **T-0:** Bridge open, announce each canary step.
    
- **Rollback:** Incident bridge opened; stakeholder notice issued.
    
- **Post-stabilization:** Summary sent within 24 h; postmortem within 48 h.
    

---

## **Appendix E – Evidence Pack Checklist**

1. Commit SHAs and image digests.
    
2. OpenAPI/Schema digests ([SRG-001]).
    
3. rol_manifest.yaml SHA-256.
    
4. Grafana snapshots of SLO metrics.
    
5. DQ-001 validation report.
    
6. LIN-001 lineage diff.
    
7. Capacity and cost summary ([CAP-001]).
    
8. Audit record references ([GOV-002]).
    

---

## **Appendix F – Rollback Runbook**

1. Abort deployment (CodeDeploy stop command or API call).
    
2. Shift traffic 100 % to stable version (Route 53 weights update).
    
3. Stop dual-write jobs; mark migration failed.
    
4. Revert API Gateway stage to previous deployment.
    
5. Smoke-test critical endpoints.
    
6. Verify metrics recovery ≤ 10 min.
    
7. Log rollback event and attach to CAB record.
    

---

