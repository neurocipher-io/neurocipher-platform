# IAM Baseline Module

## Purpose

Establishes foundational IAM roles, policies, permission boundaries, and trust relationships for the Neurocipher platform as defined in SEC-002.

## Responsibilities

- Create service execution roles (Lambda, ECS Fargate, Glue, CodePipeline)
- Define and attach permission boundaries (pb-etl, pb-fargate, pb-admin)
- Configure cross-account trust relationships for security and logs accounts
- Set up OIDC provider for GitHub Actions CI/CD
- Create AWS Identity Center (SSO) integration roles
- Establish IAM policies for least-privilege access
- Enable IAM Access Analyzer for continuous monitoring

## Constraints

- **No long-lived credentials**: All human and automation access via federated or temporary credentials only
- **PassRole restrictions**: SCP-GuardrailPassRole enforces role ARN patterns for iam:PassRole actions
- **Permission boundaries**: All service roles must have appropriate permission boundary attached
- **Tag-based access control**: Policies enforce ABAC using `app` and `env` resource tags
- **Session duration**: Human sessions limited to 1 hour, service sessions to 12 hours
- **MFA enforcement**: Required for all privileged operations via IAM Identity Center

## Key Roles

### Service Execution Roles

- `LambdaETLRole`: Execute ETL Lambda functions with S3/KMS/CloudWatch access
- `FargateTaskRole`: ECS tasks accessing S3, Weaviate, KMS, Secrets Manager
- `GlueJobRole`: Glue ETL jobs with S3/catalog access
- `PipelineExecutionRole`: CodePipeline deploying CloudFormation stacks

### Cross-Account Roles

- `SecurityAuditorRole`: Read-only access from security account
- `LogArchiverRole`: Write-only access to central logging S3 bucket

### Human Roles

- `DeveloperRole`: Deploy and test in staging environments
- `WeaviateAdminRole`: Manage Weaviate schema and configuration (MFA required)

## Permission Boundaries

### pb-etl

- Allow: S3 read/write to designated prefixes, KMS encrypt/decrypt, CloudWatch logs
- Condition: Resources must have tag `app=neurocipher-pipeline`

### pb-fargate

- Allow: S3, KMS, SecretsManager:GetSecretValue, DynamoDB:Query
- Condition: Resources must have tag `app=neurocipher-pipeline`

### pb-admin

- Allow: Infrastructure management operations
- Deny: Direct data access to S3 raw/normalized buckets

## Usage

```hcl
module "iam_baseline" {
  source = "../../modules/iam-baseline"
  
  environment     = "prod"
  account_id      = "123456789012"
  security_account_id = "098765432109"
  logs_account_id     = "111111111111"
  
  enable_github_oidc  = true
  github_org          = "neurocipher-io"
  github_repo         = "neurocipher-platform"
  
  tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
  }
}
```

## Outputs

- `lambda_etl_role_arn`: ARN of Lambda execution role
- `fargate_task_role_arn`: ARN of Fargate task role
- `pipeline_execution_role_arn`: ARN of CodePipeline role
- `github_oidc_provider_arn`: ARN of GitHub OIDC provider
- `permission_boundary_arns`: Map of permission boundary ARNs by name

## Security Considerations

- All policies enforce least privilege with explicit resource ARNs
- Cross-account access uses STS AssumeRole with ExternalId
- GitHub OIDC conditions restrict subject claim regex and audience
- IAM Access Analyzer detects and alerts on external access grants
- CloudTrail logs all IAM and STS events to central logs account
- GuardDuty monitors for anomalous AssumeRole patterns

## Monitoring

- IAM Access Analyzer runs continuously
- AWS Config rules validate IAM configuration:
  - `iam-user-no-access-key`
  - `iam-password-policy`
  - `iam-root-access-key-check`
- Security Hub aggregates IAM findings
- Permission boundary compliance checked quarterly

## References

- SEC-002: IAM Policy and Trust Relationship Map
- ops/owners.yaml: IAM resource ownership and approval requirements
- infra/modules/observability/ for CloudTrail and monitoring integration
