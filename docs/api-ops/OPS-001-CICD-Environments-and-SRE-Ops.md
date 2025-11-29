id: OPS-001
title: CI/CD, Environments, and SRE Ops
owner: Platform
status: Final v1.0
last_reviewed: 2025-11-15

# OPS-001 CI/CD, Environments, and SRE Ops

Owner: Platform  
Scope: Neurocipher Pipeline on AWS. Cross-product consumers are cataloged under `docs/integrations/`.  
Status: Final v1.0  
Related: API-001, API-002, ADR-006, ADR-009, ADR-010, REL-001, OBS-003, DM-005, ADR-007, ADR-011

---

## 1. Objectives

Ship fast with low risk. Keep SLOs green. Control spend. Prove provenance for each deploy. Enable rapid rollback.

Key outcomes

- Isolated accounts per env.
    
- Repeatable infra with IaC.
    
- One pipeline per service.
    
- Signed, attested artifacts.
    
- Blue green or canary on every runtime.
    
- Runbooks and alerting locked to SLOs.
    

---

## 2. Environment strategy

Accounts

- `neurocipher-dev` `neurocipher-test` `neurocipher-stg` `neurocipher-prod`
    
- Same for `audithound-*`
    

Guardrails

- SCPs to block public S3, open security groups, non TLS endpoints
    
- IAM Access Analyzer enabled
    
- CloudTrail org trail to central audit account
    

Data isolation

- Unique DBs per env
    
- Tenant data never crosses envs
    
- Test and staging use synthetic data only
    

Network

- One VPC per env with three AZs
    
- Private subnets for services
    
- No direct egress from tasks. NAT only
    
- VPC endpoints for AWS services
    

---

## 3. Branching and release model

Git

- `main` is protected.
    
- Feature branches from `main`.
    
- Release branches `release/vX.Y`.
    
- Git tags `vX.Y.Z`.
    

Build versions

- Semver plus build metadata `v1.4.2+gitSHA`.
    

Changelog

- Keepers per API-002 format.
    

---

## 4. Infrastructure as Code

Choice

- Terraform for shared infra.
    
- AWS CDK for service stacks where desired.
    
- One repo per service. Shared modules in `infra-modules`.
    

Standards

- State in Terraform Cloud or S3 with DynamoDB lock.
    
- Tags required: `env` `service` `tenant` `owner` `cost_center`.
    

Validation

- `tflint` `checkov` `cfn-nag` on generated templates.
    
- Policy as code with OPA Conftest.
    

---

## 5. Build pipeline

Stages

1. Checkout and supply chain prep
    
    - Pin actions by SHA
        
    - Verify checksums of tools
        
2. Language toolchain and deps
    
    - Lockfiles enforced
        
    - License allow list scan
        
3. Unit tests with coverage
    
    - Thresholds set per service
        
4. Static analysis
    
    - SAST (CodeQL or Semgrep)
        
    - Secrets scan (gitleaks)
        
    - IaC scan (Checkov)
        
5. Build artifact
    
    - Container images minimal base
        
    - Multi arch as required
        
6. SBOM and signing
    
    - Syft to generate SBOM
        
    - Cosign to sign image and attest SBOM
        
    - SLSA provenance attestation
        
7. Push to registry
    
    - ECR with immutable tags `service:gitSHA` and `service:vX.Y.Z`
        
8. Store artifacts
    
    - Build logs, SBOM, provenance in artifact bucket
        

Example GitHub Actions snippet

```yaml
name: build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@5c3b...
      - uses: actions/setup-python@3a87...
        with: { python-version: "3.11" }
      - run: pip install -r requirements.txt
      - run: pytest --maxfail=1 --disable-warnings --cov=src --cov-fail-under=80
      - run: docker build -t $IMAGE .
      - run: syft packages dir:. -o cyclonedx-json > sbom.json
      - run: cosign sign --yes $IMAGE
      - run: cosign attest --yes --predicate sbom.json --type cyclonedx $IMAGE
      - run: docker push $IMAGE
```

---

## 6. Deploy pipeline

Promotion gates

- Dev auto after build.
    
- Test requires passing integration suite.
    
- Staging requires product owner approval.
    
- Prod requires change record, security signoff, and green SLOs.
    

Runtimes

- Lambda functions use CodeDeploy canary 10 percent then 100 percent after 15 minutes.
    
- ECS Fargate services use blue green via CodeDeploy with ALB two target groups.
    
- Step Functions and EventBridge rules updated last.
    

Database changes

- Expand migrate contract pattern
    
    1. Add new columns nullable or with defaults
        
    2. Dual write in app behind feature flag
        
    3. Backfill job with throttling
        
    4. Flip reads to new schema
        
    5. Remove old columns in separate deploy
        
- Flyway or Alembic migration folder per service
    

Config and secrets

- Config in SSM Parameter Store
    
- Secrets in AWS Secrets Manager
    
- No secrets in images or env files
    
- Rotations tested quarterly
    

Feature flags

- AWS AppConfig for flags and brownouts
    
- Targeted rollout by tenant or percent
    

Rollback

- Lambda quick rollback to previous alias
    
- ECS traffic shift back to blue in under 5 minutes
    
- DB roll forward preferred. Rollback only if contract safe
    

Example CodeDeploy canary

```json
{
  "type": "Canary10Percent5Minutes",
  "alarms": ["service-5xx", "latency-p95"]
}
```

---

## 7. Testing strategy

Test pyramid

- Unit tests p0 coverage
    
- Component tests in container
    
- Contract tests against OpenAPI and Pacts
    
- Integration tests on ephemeral stacks
    
- Load tests with k6 for critical paths
    
- Chaos tests for dependency failures
    

Ephemeral stacks

- One per PR using short lived env names
    
- Auto destroy on merge or after TTL
    

Data seeds

- Synthetic fixtures only
    
- No production data in lower envs
    

---

## 8. Observability

Logs

- JSON lines
    
- Required fields: `ts` `correlation_id` `tenant_id` `route` `method` `status` `latency_ms` `err_code`
    
- PII redaction on keys `email` `name` `ssn` and custom map
    

Metrics

- RED for APIs
    
- USE for infra
    
- Custom: queue depth, webhook success rate, idempotency hit rate
    

Tracing

- OpenTelemetry SDKs
    
- Export to X Ray
    
- Propagate W3C `traceparent`
    

Dashboards

- API overview
    
- Tenant health
    
- Deploy health
    
- Cost overview
    

Error tracking

- CloudWatch alarms for 5xx and latency
    
- Optional Sentry for client side SDKs
    

---

## 9. SLOs and alert policy

SLOs

- The canonical Retention & SLO matrix in OBS-001 §5 defines these targets and the associated SLIs (ingest availability 99.9%, ingest latency p95 ≤ 300 ms, vector latency p95 ≤ 200 ms, pipeline freshness ≥ 99 % within 5 minutes, security action latency p95 ≤ 90 s); the capacity/cost envelope that supplies these numbers lives in `docs/observability/CAP-001-Capacity-and-Scalability-Model.md`. Use those values as the source of truth when gating merges or evaluating alert thresholds.
    

Alert rules

- Burn rate 2 percent of error budget in 2 hours pages
    
- 5xx over 1 percent for 5 minutes pages
    
- Latency p95 breach 10 minutes pages
    
- 429 spikes per tenant create ticket not page
    
- DLQ depth over 100 pages
    

On call

- Primary and secondary rotation weekly
    
- Escalation to platform lead after 15 minutes unacked
    
- Pager hours 24 by 7 for prod only
    

---

## 10. Incident management

Severity

- Sev 1 customer visible outage or security breach
    
- Sev 2 partial outage or major regression
    
- Sev 3 degraded or isolated feature failure
    

Process

- Declare in Slack channel
    
- Assign incident commander and scribe
    
- Open timeline doc and issue
    
- Status updates every 30 minutes for Sev 1
    
- End with blameless postmortem within 5 business days
    

Postmortem template

- What happened
    
- Impact
    
- Root cause
    
- Detection
    
- Response timeline
    
- What went well
    
- What went wrong
    
- Action items with owners and due dates
    

---

## 11. DR and HA

Targets

- RPO 15 minutes
    
- RTO 60 minutes for public API
    

Backups

- RDS automated daily and PITR 7 to 30 days
    
- DynamoDB PITR 35 days
    
- S3 versioning and object lock for audit buckets
    

Cross region

- Read replicas or multi region strategy per state store
    
- Replicate SSM, Secrets, and ECR where needed
    

Failover

- Route 53 health checks and weighted routing
    
- Runbook to promote standby and update endpoints
    
- Test failover quarterly
    

---

## 12. Cost controls

Budgets

- AWS Budgets at 80 and 100 percent per account
    
- Cost Anomaly Detection with daily alerts
    

Tag policy

- Enforced at account level
    
- Required on all resources
    
- Reports grouped by `service` and `tenant`
    

Runtime tuning

- Fargate right sizing weekly
    
- Lambda memory tuned for lowest cost per 100 ms
    
- Scale to zero workers on idle queues
    
- CloudFront cache for GET endpoints
    

Data lifecycle

- Logs hot 30 days then IA or Glacier
    
- WAF logs to S3 with lifecycle 365 days
    

---

## 13. Security controls in CI/CD

Hardening

- Containers run as non root
    
- Drop capabilities
    
- Read only root FS when possible
    

Signing and provenance

- Cosign sign and verify in deploy
    
- Reject unsigned images
    
- Verify SLSA provenance type and predicate
    

Policies

- OPA gate to block images without SBOM
    
- Block high CVEs unless approved exception
    

Secrets

- OIDC trust from CI to AWS role
    
- No long lived cloud keys in repo
    

---

## 14. Compliance and audit

Logs

- Access and admin actions to immutable S3 with object lock
    
- Retention per ADR-007
    

Reviews

- Quarterly access reviews
    
- Annual disaster recovery test attestation
    
- Evidence collection stored in audit account
    

Change records

- All prod changes carry ticket ID and artifact digest
    
- Link deploy to git commit and SBOM hash
    

---

## 15. Runbooks

Operational

- Brownout enable and disable
    
- Token revocation and key rotation
    
- Webhook replay from DLQ
    
- Idempotency store purge and rebuild
    
- Hotfix cut, verify, and roll forward
    
- Regional failover and return
    

Testing

- Load test execution and evaluation
    
- Chaos test scenarios for dependency outage
    
- DR restore from backup
    

Security

- Secret rotation drill
    
- Compromised key response
    
- Vulnerability patch flow
    

---

## 16. Acceptance criteria

- Build produces signed image and SBOM.
    
- Deploy uses canary or blue green.
    
- Rollback verified in staging weekly.
    
- SLO dashboards populated and alerts firing in tests.
    
- DR restore verified quarterly within targets.
    
- Cost reports show tag coverage above 98 percent.
    
- Security gates block images with critical CVEs unless exception exists.
    

---

## 17. Deliverables

- Terraform or CDK stacks for VPC, ECS, ALB, Lambda, RDS, SQS, EventBridge, WAF, CloudFront, Route 53.
    
- CI pipeline YAML with SAST, SCA, IaC, SBOM, signing, and build steps.
    
- CD pipeline config for CodeDeploy and traffic shifting.
    
- Runbooks in `runbooks/` folder.
    
- Dashboards JSON and alarm definitions.
    
- DR plan and test reports.
    
- Cost allocation report queries and budgets.
    

---

## 18. Example ECS blue green snippet

```json
{
  "deploymentController": { "type": "CODE_DEPLOY" },
  "loadBalancers": [
    { "targetGroupArn": "blue-tg", "containerName": "api", "containerPort": 8080 }
  ],
  "desiredCount": 3,
  "networkMode": "awsvpc",
  "compatibilities": ["FARGATE"]
}
```

---

## 19. Example k6 smoke

```js
import http from 'k6/http';
import { sleep, check } from 'k6';
export let options = { vus: 20, duration: '5m' };
export default function () {
  const res = http.get(`${__ENV.BASE}/v1/health`);
  check(res, { 'status 200': r => r.status === 200, 'latency < 500': r => r.timings.duration < 500 });
  sleep(1);
}
```

---

## 20. RACI

- Platform owns CI/CD, infra, and SRE.
    
- Service teams own app tests, migrations, and runbooks.
    
- Security signs off prod changes and reviews exceptions.
    
- Product owns go or no go for staged releases.
    

---
