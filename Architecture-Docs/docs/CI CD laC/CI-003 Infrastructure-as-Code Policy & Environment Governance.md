# **CI/CL-003 — Release Management, Change Control, and Operational Readiness**

  

**Status:** Draft for review

**Owners:** Release Engineering, SRE Lead, Security Lead, Product Owner

**Applies to:** Neurocipher and AuditHound repositories under the neurocipher organization

**Default region:** ca-central-1

  

## **1. Objective**

  

Standardize releases. Reduce risk. Ensure fast rollback. Preserve full audit evidence.

  

## **2. Scope**

- Targets: ECS Fargate services, Lambda functions, scheduled workers, Terraform stacks.
    
- Artifacts: container images, Lambda zips, Python wheels, Terraform plans.
    
- Excludes: desktop and mobile clients.
    

  

## **3. Roles and RACI**

- Release Manager: accountable. runs go or no-go.
    
- Service Owner: responsible. signs readiness and rollback.
    
- SRE Lead: responsible. validates capacity, alarms, runbooks.
    
- QA Lead: responsible. test evidence and coverage gates.
    
- Security Lead: consults. approves high risk and prod.
    
- Product Owner: approves user impact and comms.
    

  

RACI matrix keys per phase are captured in the change ticket template.

  

## **4. Definitions**

- Release types: standard, normal, emergency, hotfix.
    
- Environments: dev, stg, prod. Separate AWS accounts.
    
- Promotion: artifact by digest only. No mutable tags.
    
- Freeze: scheduled no-deploy windows. Exceptions need Security and SRE approval.
    

  

## **5. Governance and approvals**

- CAB for prod: Release Manager, Security Lead, Product Owner.
    
- Required approvals:
    
    - dev: none.
        
    - stg: Release Engineering.
        
    - prod: Security and Product.
        
    
- Auto-block if any CI/CL-001 gate fails, if SLO alarms are red in stg, or if migration checks fail.
    

  

## **6. Versioning and artifact policy**

- SemVer tags: vMAJOR.MINOR.PATCH.
    
- Container tags: sha-<7> and vX.Y.Z. Deploy by digest.
    
- Wheels and zips signed with Cosign keyless.
    
- SBOM: Syft SPDX JSON stored with digests.
    
- Provenance: SLSA attestations stored with artifacts.
    

  

## **7. Change calendar and freeze**

- Blackouts: Friday 17:00 ET to Monday 09:00 ET for prod, unless approved.
    
- Freeze for high-traffic events, security incidents, or billing cycles.
    
- Exceptions require CAB approval and a rollback owner on call.
    

  

## **8. Release lifecycle**

1. Plan: ticket opened with scope, risk, and rollout plan.
    
2. Readiness review: runbooks, alarms, SLOs, capacity, backups, and migrations checked.
    
3. Pre-prod: deploy to stg. Bake with synthetic and load checks.
    
4. Go or no-go: CAB approval with objective signals.
    
5. Prod rollout: blue-green or canary.
    
6. Verification: smoke, health, error rate, p95 latency.
    
7. Close: notes, evidence archive, and post-release check.
    

  

## **9. Rollout strategies**

- ECS: blue-green via CodeDeploy with automatic rollback on ALB health, 5xx, or p95 breach.
    
- Lambda: canary 10 percent then 100 percent after bake or linear 25 percent steps.
    
- Feature flags: AppConfig. Progressive delivery by percentage and cohort.
    
- Rings: internal first, then 10 percent, 25 percent, 50 percent, 100 percent, as flags allow.
    

  

## **10. Database migrations**

- Pre-traffic step inside the deployment.
    
- Forward-only for minor versions.
    
- Backward-compatible API window equals canary window.
    
- Destructive changes require data backup confirmation and an explicit rollback plan.
    
- Owner validates idempotency in stg.
    

  

## **11. Operational readiness checklist**

- Runbook: create, rollback, and emergency steps present.
    
- Dashboards: golden signals and SLO view exist.
    
- Alarms: 5xx, p95, saturation, DLQ depth, and error budget burn.
    
- Capacity: ECS service headroom > 30 percent. Lambda concurrency reserved where needed.
    
- Backups: RPO and RTO validated.
    
- Config: SSM parameters and Secrets Manager entries exist for env.
    
- Access: OIDC roles in place. No static cloud keys.
    

  

## **12. Test and bake gates**

- Smoke: health, readiness, one happy path.
    
- Contract: OpenAPI and event schema diffs green.
    
- Performance: p95 under SLO for 10 minutes under nominal load.
    
- Error rate: < 1 percent.
    
- Security: CodeQL and Trivy reported clean for release commit.
    
- Bake in stg: 30 minutes minimum unless CAB waives.
    

  

## **13. Communication**

- Channels: engineering Slack, status page if user visible, email for stakeholders.
    
- Templates for user-facing notes included in Appendix.
    
- Incident comms if rollback triggered.
    

  

## **14. Rollback and recovery**

- Triggers: SLO breach, error budget burn > 5 percent in 10 minutes, fatal migration, or CAB decision.
    
- ECS: revert to previous task definition and target group.
    
- Lambda: switch alias to previous version.
    
- Migrations: apply down script only if marked data-safe. Else forward fix.
    
- Infra: apply last good Terraform plan or targeted destroy of failed resource.
    
- Logs: capture last 15 minutes and attach to ticket.
    
- Post-rollback: root cause ticket and action items.
    

  

## **15. Evidence and audit**

  

Archive the following to the release ticket and S3:

- PR links, checks, and approvals.
    
- Test reports and coverage.
    
- SBOM and provenance.
    
- tfplan and apply logs.
    
- Deployment logs and CodeDeploy reports.
    
- Go or no-go minutes.
    
- Post-release verification screenshots.
    
    Retention: 365 days in GitHub, 2 years in S3 Glacier using KMS CMK.
    

  

## **16. Tooling and automation**

- GitHub Releases generate notes from Conventional Commits.
    
- GitHub Environments enforce approvers and secrets per env.
    
- CodeDeploy strategies codified per service.
    
- Change bot posts gates summary to the ticket.
    
- State for Terraform: S3 + DynamoDB locking per account.
    
- Alarms feed into deployment decisions through GitHub checks.
    

  

## **17. KPIs**

- Lead time from tag to prod: under 30 minutes median.
    
- Change failure rate: under 5 percent.
    
- MTTR after failed release: under 15 minutes.
    
- Rollback frequency: under 2 percent per quarter.
    
- Evidence completeness: 100 percent of releases.
    

  

## **18. Acceptance criteria**

- At least one service completes a full standard release using this flow.
    
- CAB approvals enforced in GitHub Environments.
    
- Blue-green and canary verified in stg with auto rollback.
    
- Evidence pack stored in S3 with KMS and linked in the ticket.
    
- Freeze calendar and exception workflow active.
    

  

## **19. Compliance mapping**

- ADR-008 Testing and quality gates: Sections 12 and 15.
    
- ADR-009 Cost control: cache, ring rollouts, short bake windows.
    
- ADR-010 DR and backups: Sections 11 and 14.
    
- SEC-001 to SEC-004: identity, network, secrets, and rotations respected.
    
- REL-001 High availability: blue-green and canary patterns.
    

  

## **20. Templates**

  

### **20.1 Change request frontmatter**

yaml

```
change_id: CHG-YYYYMMDD-### 
service: ingest-worker
version: v1.4.2
environments: [dev, stg, prod]
type: standard
risk: medium
owner: alice@example.com
approvers:
  release: bob@example.com
  security: seclead@example.com
  product: po@example.com
rollout:
  strategy: blue-green
  flags:
    - name: new_parser
      initial: 0
      target: 50
      duration_min: 30
readiness:
  runbook: link
  dashboards: link
  alarms: [5xx, p95, dlq_depth]
  capacity_headroom: ">=30%"
tests:
  smoke: link
  synthetic: link
  perf: link
migrations:
  plan: link
  is_destructive: false
rollback:
  ecs: "revert to previous task definition"
  db: "no down migration required"
comms:
  slack_channels: ["#eng-releases", "#sre"]
  status_page: false
evidence_bucket: s3://nc-ops-artifacts/releases/CHG-YYYYMMDD-###
```

### **20.2 Go or no-go checklist**

```
[ ] CI/CL-001 gates green for commit <sha>
[ ] Staging bake complete, SLOs green
[ ] Alarms armed and dashboards live
[ ] Backups verified and RPO/RTO within targets
[ ] Migration pre-checks passed
[ ] Rollback plan tested or dry-run
[ ] Approvals present in GitHub Environment
Decision: GO / NO-GO
Signed by: Release Manager, Security Lead, Product Owner
```

### **20.3 Release notes**

```
## v1.4.2 - 2025-10-28
### Features
- Add streaming parser to ingest-worker
### Fixes
- Reduce queue retry storms on network errors
### Ops
- Upgrade base image to distroless:debug@sha256:...
### Migrations
- None
### Rollout
- Blue-green, flags to 50 percent after 30 minutes if green
```

### **20.4 Rollback playbook**

```
1) Announce rollback in #eng-releases
2) ECS: redeploy previous task definition; verify ALB health
3) Lambda: shift alias to previous version; confirm synthetic pass
4) Disable new flags; drain queues; confirm DLQ stable
5) If data issue, run safe forward fix; avoid destructive down unless pre-approved
6) Capture logs and metrics; attach to ticket
7) Open incident and schedule postmortem
```

---
