# **CI/CL-002 — Continuous Delivery and Environment Promotion Specification**

  

**Status:** Draft for review

**Owners:** Release Engineering, SRE Lead, Security Lead

**Applies to:** Neurocipher and AuditHound repositories under the neurocipher organization

**Default region:** ca-central-1

  

## **1. Objective**

  

Provide deterministic delivery, environment isolation, and controlled promotion from dev to prod with auditability and rapid rollback.

  

## **2. Scope**

- Targets: ECS Fargate services, Lambda functions, scheduled workers, Terraform IaC.
    
- Artifacts: container images, Python wheels, Lambda zips, Terraform plans.
    
- Out of scope: desktop and mobile clients.
    

  

## **3. Environments and AWS accounts**

- Separate AWS accounts: dev, stg, prod.
    
- Regions: primary ca-central-1. Optional DR us-east-1.
    
- Data rules:
    
    - dev: synthetic data only.
        
    - stg: sanitized seed data.
        
    - prod: live data with strict controls.
        
    

  

## **4. Identity and access with GitHub OIDC**

- Trust: token.actions.githubusercontent.com.
    
- One role per env and workload: gha-deploy-role.
    
- No long-lived AWS keys in CI/CD.
    

  

**Trust policy (template)**

```
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:neurocipher/*:*"
      }
    }
  }]
}
```

**Workflow usage**

```
permissions: { id-token: write, contents: read }
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role
    aws-region: ca-central-1
```

## **5. Release types and versioning**

- Version: SemVer tags vMAJOR.MINOR.PATCH.
    
- Release types:
    
    - build-only: branch builds, no deploy.
        
    - pre-release: deploy to dev and stg.
        
    - release: deploy to stg, then prod on approval.
        
    
- Changelog generated from Conventional Commits.
    

  

## **6. IaC delivery pipeline (Terraform)**

- State: S3 backend per account, DynamoDB lock.
    
- Plans produced on PRs. Applies gated by environment rules.
    

  

**PR plan**

```
jobs:
  tf-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform -chdir=iac/stacks/core init -backend-config=env/dev.hcl
      - run: terraform -chdir=iac/stacks/core validate
      - run: terraform -chdir=iac/stacks/core plan -out=tfplan.bin
      - uses: actions/upload-artifact@v4
        with: { name: tfplan-dev, path: iac/stacks/core/tfplan.bin }
```

**Apply on merge/tag**

```
jobs:
  tf-apply-dev:
    environment: dev
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role
          aws-region: ca-central-1
      - run: terraform -chdir=iac/stacks/core apply -auto-approve tfplan.bin
```

## **7. Application delivery patterns**

  

### **7.1 ECS Fargate services**

- Deployment: blue-green via CodeDeploy.
    
- Health criteria: ALB target 200 OK, p95 latency under SLO, error rate under threshold.
    
- Auto rollback on health failure.
    

  

**ECS deploy step**

```
- uses: aws-actions/amazon-ecs-deploy-task-definition@v2
  with:
    task-definition: ecs/ingest-worker.td.json
    service: ingest-worker
    cluster: nc-core
    wait-for-service-stability: true
```

### **7.2 Lambda functions**

- Strategy: CodeDeploy canary or linear.
    
- Aliases: live and previous.
    
- Auto rollback on CloudWatch alarm breach.
    

  

**Lambda deploy step**

```
- uses: aws-actions/aws-lambda-deploy@v1
  with:
    function-name: api-adapter
    zip-file: dist/api-adapter.zip
    publish: true
    alias: live
    update-alias: true
```

### **7.3 Async workers and schedulers**

- Queue drain before switch.
    
- SQS visibility and redrive tuned.
    
- DLQ monitored with alarm and ticket.
    

  

## **8. Database migrations**

- Migrations run in a pre-traffic step.
    
- Forward-only for minor versions.
    
- Backward-compatible API window equals canary window.
    
- Emergency script per service for hotfix rollback when data-safe.
    
- Owner approves any destructive change.
    

  

## **9. Configuration and secrets**

- Config store: SSM Parameter Store.
    
- Secrets: AWS Secrets Manager.
    
- KMS: per-environment CMK.
    
- Naming:
    
    - /nc/<env>/<service>/config/<key>
        
    - /nc/<env>/<service>/secret/<key>
        
    

  

## **10. Feature flags**

- Provider: AWS AppConfig.
    
- Flags scoped by env and percentage.
    
- Required for risky changes and DB shape changes.
    

  

## **11. Promotion flow**

- push to main: deploy to dev after CI gates.
    
- tag v*: build and push artifacts, deploy to stg, run bake tests.
    
- Manual approval promotes to prod.
    

  

**Flow summary**

1. CI green and signed artifacts present.
    
2. Deploy dev with smoke tests.
    
3. Deploy stg, run synthetic, contract, and perf checks.
    
4. Approve and deploy prod.
    
5. Post-deploy verification and release notes.
    

  

## **12. Environment protections and approvals**

- GitHub Environments:
    
    - dev: no manual approvals.
        
    - stg: 1 approver from Release Eng.
        
    - prod: 2 approvers: Security and Product.
        
    
- Required checks before prod:
    
    - CI gates from CI/CL-001.
        
    - CodeQL, Trivy, IaC scan, contract diff.
        
    - Change ticket ID in approval comment.
        
    

  

## **13. Observability and bake verification**

- Bake period in stg with alarms:
    
    - HTTP 5xx rate < 1 percent.
        
    - p95 latency within SLO.
        
    - Error budget not breached.
        
    
- Synthetic tests:
    
    - Health endpoint.
        
    - Readiness endpoint.
        
    - One happy-path transaction.
        
    
- Post-deploy in prod:
    
    - 10-minute watch.
        
    - Auto rollback if alarms breach.
        
    

  

## **14. Rollback and break-glass**

- ECS: revert to previous task definition.
    
- Lambda: shift alias to previous version.
    
- IaC: terraform apply of last good state or targeted destroy for failed resources.
    
- Break-glass IAM role is time-bound and logged.
    
- All rollbacks create an incident and root-cause ticket.
    

  

## **15. Artifact promotion and provenance**

- Images: ECR repo per service and env.
    
- Tags:
    
    - sha-<7> for immutable.
        
    - vX.Y.Z for releases.
        
    
- Attestations: Cosign keyless and SLSA provenance.
    
- SBOM: Syft SPDX JSON stored with image digest.
    
- Promotion pulls by digest, not tag.
    

  

## **16. Change management**

- Change types: standard, normal, emergency.
    
- Standard: documented, low risk, auto-approved windows.
    
- Normal: CAB approval before prod.
    
- Emergency: on-call approval with post-incident review.
    

  

## **17. Resource naming and tags**

- Naming: nc-<svc>-<env>-<component>
    
- Required tags:
    
    - App=Neurocipher or App=AuditHound
        
    - Service=<svc>
        
    - Env=<env>
        
    - Owner=<team>
        
    - CostCenter=<code>
        
    - Compliance=Yes/No
        
    

  

## **18. Example delivery workflows**

  

**Service delivery**


```
name: Deliver Service
on:
  push: { branches: [ main ] }
  release: { types: [published] }
jobs:
  build_push:
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STG }}:role/gha-deploy-role
          aws-region: ca-central-1
      - uses: aws-actions/amazon-ecr-login@v2
      - run: |
          IMAGE="${{ secrets.ECR_URI_STG }}/ingest-worker"
          docker buildx build --platform linux/amd64 -t "$IMAGE:${{ github.sha }}" .
          docker push "$IMAGE:${{ github.sha }}"
  deploy_dev:
    if: github.event_name == 'push'
    environment: dev
    runs-on: ubuntu-latest
    needs: []
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role
          aws-region: ca-central-1
      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ecs/ingest-worker.td.json
          service: ingest-worker
          cluster: nc-core
          wait-for-service-stability: true
  deploy_stg:
    if: github.event_name == 'release'
    environment: stg
    runs-on: ubuntu-latest
    needs: build_push
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STG }}:role/gha-deploy-role
          aws-region: ca-central-1
      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ecs/ingest-worker.td.json
          service: ingest-worker
          cluster: nc-core
          wait-for-service-stability: true
  deploy_prod:
    if: github.event_name == 'release'
    environment: prod
    runs-on: ubuntu-latest
    needs: deploy_stg
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_PROD }}:role/gha-deploy-role
          aws-region: ca-central-1
      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ecs/ingest-worker.td.json
          service: ingest-worker
          cluster: nc-core
          wait-for-service-stability: true
```


**Lambda delivery**

```
name: Deliver Lambda
on:
  release: { types: [published] }
jobs:
  deploy_lambda:
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4
      - run: make lambda-zip  # produces dist/api-adapter.zip
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_PROD }}:role/gha-deploy-role
          aws-region: ca-central-1
      - uses: aws-actions/aws-lambda-deploy@v1
        with:
          function-name: api-adapter
          zip-file: dist/api-adapter.zip
          publish: true
          alias: live
          update-alias: true
```

## **19. KPIs**

- Median lead time from tag to prod under 30 minutes.
    
- Change failure rate under 5 percent.
    
- Mean time to restore under 15 minutes.
    
- Rollback rate under 2 percent per quarter.
    

  

## **20. Acceptance criteria**

- OIDC roles created and scoped for each env.
    
- GitHub Environments set with required approvers.
    
- Blue-green for ECS and canary for Lambda verified in stg.
    
- Bake checks green before first prod deploy.
    
- Rollback steps validated for ECS, Lambda, and Terraform.
    

  

Confirm to proceed with CI/CL-003.CI/CL-002 — Continuous Delivery and Environment Promotion Specification

  

  

Status: Draft for review

Owners: Release Engineering, SRE Lead, Security Lead

Applies to: Neurocipher and AuditHound repositories under the neurocipher organization

Default region: ca-central-1

  

  

1. Objective

  

  

Provide deterministic delivery, environment isolation, and controlled promotion from dev to prod with auditability and rapid rollback.

  

  

2. Scope

  

  

- Targets: ECS Fargate services, Lambda functions, scheduled workers, Terraform IaC.
- Artifacts: container images, Python wheels, Lambda zips, Terraform plans.
- Out of scope: desktop and mobile clients.

  

  

  

3. Environments and AWS accounts

  

  

- Separate AWS accounts: dev, stg, prod.
- Regions: primary ca-central-1. Optional DR us-east-1.
- Data rules:  
    

- dev: synthetic data only.
- stg: sanitized seed data.
- prod: live data with strict controls.

-   
    

  

  

  

4. Identity and access with GitHub OIDC

  

  

- Trust: token.actions.githubusercontent.com.
- One role per env and workload: gha-deploy-role.
- No long-lived AWS keys in CI/CD.

  

  

Trust policy (template)

{

  "Version": "2012-10-17",

  "Statement": [{

    "Effect": "Allow",

    "Principal": {

      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"

    },

    "Action": "sts:AssumeRoleWithWebIdentity",

    "Condition": {

      "StringEquals": {

        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"

      },

      "StringLike": {

        "token.actions.githubusercontent.com:sub": "repo:neurocipher/*:*"

      }

    }

  }]

}

Workflow usage

permissions: { id-token: write, contents: read }

- uses: aws-actions/configure-aws-credentials@v4

  with:

    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role

    aws-region: ca-central-1

  

5. Release types and versioning

  

  

- Version: SemVer tags vMAJOR.MINOR.PATCH.
- Release types:  
    

- build-only: branch builds, no deploy.
- pre-release: deploy to dev and stg.
- release: deploy to stg, then prod on approval.

-   
    
- Changelog generated from Conventional Commits.

  

  

  

6. IaC delivery pipeline (Terraform)

  

  

- State: S3 backend per account, DynamoDB lock.
- Plans produced on PRs. Applies gated by environment rules.

  

  

PR plan

jobs:

  tf-plan:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - run: terraform -chdir=iac/stacks/core init -backend-config=env/dev.hcl

      - run: terraform -chdir=iac/stacks/core validate

      - run: terraform -chdir=iac/stacks/core plan -out=tfplan.bin

      - uses: actions/upload-artifact@v4

        with: { name: tfplan-dev, path: iac/stacks/core/tfplan.bin }

Apply on merge/tag

jobs:

  tf-apply-dev:

    environment: dev

    steps:

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role

          aws-region: ca-central-1

      - run: terraform -chdir=iac/stacks/core apply -auto-approve tfplan.bin

  

7. Application delivery patterns

  

  

  

7.1 ECS Fargate services

  

  

- Deployment: blue-green via CodeDeploy.
- Health criteria: ALB target 200 OK, p95 latency under SLO, error rate under threshold.
- Auto rollback on health failure.

  

  

ECS deploy step

- uses: aws-actions/amazon-ecs-deploy-task-definition@v2

  with:

    task-definition: ecs/ingest-worker.td.json

    service: ingest-worker

    cluster: nc-core

    wait-for-service-stability: true

  

7.2 Lambda functions

  

  

- Strategy: CodeDeploy canary or linear.
- Aliases: live and previous.
- Auto rollback on CloudWatch alarm breach.

  

  

Lambda deploy step

- uses: aws-actions/aws-lambda-deploy@v1

  with:

    function-name: api-adapter

    zip-file: dist/api-adapter.zip

    publish: true

    alias: live

    update-alias: true

  

7.3 Async workers and schedulers

  

  

- Queue drain before switch.
- SQS visibility and redrive tuned.
- DLQ monitored with alarm and ticket.

  

  

  

8. Database migrations

  

  

- Migrations run in a pre-traffic step.
- Forward-only for minor versions.
- Backward-compatible API window equals canary window.
- Emergency script per service for hotfix rollback when data-safe.
- Owner approves any destructive change.

  

  

  

9. Configuration and secrets

  

  

- Config store: SSM Parameter Store.
- Secrets: AWS Secrets Manager.
- KMS: per-environment CMK.
- Naming:  
    

- /nc/<env>/<service>/config/<key>
- /nc/<env>/<service>/secret/<key>

-   
    

  

  

  

10. Feature flags

  

  

- Provider: AWS AppConfig.
- Flags scoped by env and percentage.
- Required for risky changes and DB shape changes.

  

  

  

11. Promotion flow

  

  

- push to main: deploy to dev after CI gates.
- tag v*: build and push artifacts, deploy to stg, run bake tests.
- Manual approval promotes to prod.

  

  

Flow summary

  

1. CI green and signed artifacts present.
2. Deploy dev with smoke tests.
3. Deploy stg, run synthetic, contract, and perf checks.
4. Approve and deploy prod.
5. Post-deploy verification and release notes.

  

  

  

6. Environment protections and approvals

  

  

- GitHub Environments:  
    

- dev: no manual approvals.
- stg: 1 approver from Release Eng.
- prod: 2 approvers: Security and Product.

-   
    
- Required checks before prod:  
    

- CI gates from CI/CL-001.
- CodeQL, Trivy, IaC scan, contract diff.
- Change ticket ID in approval comment.

-   
    

  

  

  

13. Observability and bake verification

  

  

- Bake period in stg with alarms:  
    

- HTTP 5xx rate < 1 percent.
- p95 latency within SLO.
- Error budget not breached.

-   
    
- Synthetic tests:  
    

- Health endpoint.
- Readiness endpoint.
- One happy-path transaction.

-   
    
- Post-deploy in prod:  
    

- 10-minute watch.
- Auto rollback if alarms breach.

-   
    

  

  

  

14. Rollback and break-glass

  

  

- ECS: revert to previous task definition.
- Lambda: shift alias to previous version.
- IaC: terraform apply of last good state or targeted destroy for failed resources.
- Break-glass IAM role is time-bound and logged.
- All rollbacks create an incident and root-cause ticket.

  

  

  

15. Artifact promotion and provenance

  

  

- Images: ECR repo per service and env.
- Tags:  
    

- sha-<7> for immutable.
- vX.Y.Z for releases.

-   
    
- Attestations: Cosign keyless and SLSA provenance.
- SBOM: Syft SPDX JSON stored with image digest.
- Promotion pulls by digest, not tag.

  

  

  

16. Change management

  

  

- Change types: standard, normal, emergency.
- Standard: documented, low risk, auto-approved windows.
- Normal: CAB approval before prod.
- Emergency: on-call approval with post-incident review.

  

  

  

17. Resource naming and tags

  

  

- Naming: nc-<svc>-<env>-<component>
- Required tags:  
    

- App=Neurocipher or App=AuditHound
- Service=<svc>
- Env=<env>
- Owner=<team>
- CostCenter=<code>
- Compliance=Yes/No

-   
    

  

  

  

18. Example delivery workflows

  

  

Service delivery

name: Deliver Service

on:

  push: { branches: [ main ] }

  release: { types: [published] }

jobs:

  build_push:

    if: github.event_name == 'release'

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STG }}:role/gha-deploy-role

          aws-region: ca-central-1

      - uses: aws-actions/amazon-ecr-login@v2

      - run: |

          IMAGE="${{ secrets.ECR_URI_STG }}/ingest-worker"

          docker buildx build --platform linux/amd64 -t "$IMAGE:${{ github.sha }}" .

          docker push "$IMAGE:${{ github.sha }}"

  deploy_dev:

    if: github.event_name == 'push'

    environment: dev

    runs-on: ubuntu-latest

    needs: []

    steps:

      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_DEV }}:role/gha-deploy-role

          aws-region: ca-central-1

      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2

        with:

          task-definition: ecs/ingest-worker.td.json

          service: ingest-worker

          cluster: nc-core

          wait-for-service-stability: true

  deploy_stg:

    if: github.event_name == 'release'

    environment: stg

    runs-on: ubuntu-latest

    needs: build_push

    steps:

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_STG }}:role/gha-deploy-role

          aws-region: ca-central-1

      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2

        with:

          task-definition: ecs/ingest-worker.td.json

          service: ingest-worker

          cluster: nc-core

          wait-for-service-stability: true

  deploy_prod:

    if: github.event_name == 'release'

    environment: prod

    runs-on: ubuntu-latest

    needs: deploy_stg

    steps:

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_PROD }}:role/gha-deploy-role

          aws-region: ca-central-1

      - uses: aws-actions/amazon-ecs-deploy-task-definition@v2

        with:

          task-definition: ecs/ingest-worker.td.json

          service: ingest-worker

          cluster: nc-core

          wait-for-service-stability: true

Lambda delivery

name: Deliver Lambda

on:

  release: { types: [published] }

jobs:

  deploy_lambda:

    runs-on: ubuntu-latest

    environment: prod

    steps:

      - uses: actions/checkout@v4

      - run: make lambda-zip  # produces dist/api-adapter.zip

      - uses: aws-actions/configure-aws-credentials@v4

        with:

          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID_PROD }}:role/gha-deploy-role

          aws-region: ca-central-1

      - uses: aws-actions/aws-lambda-deploy@v1

        with:

          function-name: api-adapter

          zip-file: dist/api-adapter.zip

          publish: true

          alias: live

          update-alias: true

  

19. KPIs

  

  

- Median lead time from tag to prod under 30 minutes.
- Change failure rate under 5 percent.
- Mean time to restore under 15 minutes.
- Rollback rate under 2 percent per quarter.

  

  

  

20. Acceptance criteria

  

  

- OIDC roles created and scoped for each env.
- GitHub Environments set with required approvers.
- Blue-green for ECS and canary for Lambda verified in stg.
- Bake checks green before first prod deploy.
- Rollback steps validated for ECS, Lambda, and Terraform.

  

  

Confirm to proceed with CI/CL-003.