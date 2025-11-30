# Production Environment

## Purpose

Production environment for the Neurocipher platform serving live customer workloads with strict SLAs, security, and compliance requirements.

## Configuration

- **Environment**: `prod`
- **AWS Account**: Production account
- **Region**: `us-east-1` (primary), `ca-central-1` (disaster recovery)
- **VPC CIDR**: `10.2.0.0/16`

## Characteristics

- **Availability**: 99.9% SLA, multi-AZ deployment with automatic failover
- **Data retention**: 90 days operational logs, 2 years audit logs
- **Encryption**: Customer-managed KMS keys (`alias/nc-dp-data-prod`) with automatic rotation
- **Backup**: Continuous backup with point-in-time recovery, 30-day retention
- **Performance**: Auto-scaling with reserved capacity for baseline load
- **Compliance**: SOC 2, ISO 27001, GDPR, HIPAA-ready

## Resource Naming

All resources use the `-prod` suffix:
- S3 buckets: `nc-dp-prod-raw`, `nc-dp-prod-norm`
- DynamoDB tables: `nc-dp-prod-documents`
- Lambda functions: `svc-{name}-prod`
- KMS keys: `alias/nc-dp-data-prod`

## Access Control

- **No direct human access** except break-glass scenarios
- All changes deployed via CI/CD pipeline with multi-approval workflow
- Read-only access for security auditors and SRE team
- Infrastructure changes require approval from:
  - Platform Engineering Lead
  - Security Engineering Lead
  - CTO (for high-risk changes)
- MFA required for all access
- Session duration: 1 hour maximum

## Security Posture

- **Defense in depth**: Multiple layers of security controls per SEC-002 and SEC-003
- **Zero trust**: All inter-service communication authenticated and encrypted
- **Least privilege**: IAM policies and permission boundaries strictly enforced
- **Encryption everywhere**: Data at rest and in transit encrypted with customer-managed keys
- **Immutable audit logs**: CloudTrail with S3 Object Lock, cannot be altered or deleted
- **24/7 monitoring**: GuardDuty, Security Hub, Config, CloudWatch alarms

## Module Usage

```hcl
terraform {
  backend "s3" {
    bucket         = "nc-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
    dynamodb_table = "terraform-state-lock-prod"
  }
}

locals {
  environment = "prod"
  region      = "us-east-1"
  
  common_tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-engineering"
    CostCenter  = "engineering"
    Compliance  = "soc2,iso27001"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment              = local.environment
  vpc_cidr                 = "10.2.0.0/16"
  enable_nat_gateway       = true
  single_nat_gateway       = false  # Multi-AZ for HA
  enable_vpc_endpoints     = true
  enable_flow_logs         = true
  flow_logs_retention_days = 90
  
  tags = local.common_tags
}

module "iam_baseline" {
  source = "../../modules/iam-baseline"
  
  environment         = local.environment
  account_id          = var.aws_account_id
  security_account_id = var.security_account_id
  logs_account_id     = var.logs_account_id
  
  enable_github_oidc = true
  github_org         = "neurocipher-io"
  github_repo        = "neurocipher-platform"
  
  tags = local.common_tags
}

module "kms" {
  source = "../../modules/kms"
  
  environment          = local.environment
  enable_key_rotation  = true
  deletion_window_days = 30
  
  lambda_role_arns  = [module.iam_baseline.lambda_etl_role_arn]
  fargate_role_arns = [module.iam_baseline.fargate_task_role_arn]
  
  security_account_id = var.security_account_id
  logs_account_id     = var.logs_account_id
  
  tags = local.common_tags
}

module "observability" {
  source = "../../modules/observability"
  
  environment        = local.environment
  kms_key_arn        = module.kms.logs_key_arn
  vpc_id             = module.vpc.vpc_id
  log_retention_days = 90
  
  logs_account_id  = var.logs_account_id
  logs_bucket_name = "nc-dp-logs-central"
  
  alert_email = "security@neurocipher.io"
  ops_email   = "ops@neurocipher.io"
  
  enable_guardduty                       = true
  guardduty_finding_publishing_frequency = "FIFTEEN_MINUTES"
  enable_config_rules                    = true
  
  tags = local.common_tags
}
```

## Deployment

Production deployments follow strict change management:

```bash
# 1. Changes must be validated in staging first
# 2. Create change request with:
#    - Risk assessment
#    - Rollback plan
#    - Validation criteria
#    - Approval from platform and security leads

# 3. Deploy during maintenance window
terraform init
terraform plan -out=tfplan

# 4. Review plan with team
# 5. Obtain approvals
# 6. Apply with monitoring
terraform apply tfplan

# 7. Validate deployment
# 8. Monitor for 1 hour post-deployment
```

## Disaster Recovery

- **RTO**: 4 hours
- **RPO**: 15 minutes
- **DR region**: ca-central-1
- **DR strategy**: Warm standby with automated failover
- **Backup schedule**: Continuous with point-in-time recovery
- **DR testing**: Quarterly full failover drills

## Monitoring & Alerting

### Critical Alarms (Page immediately)

- Lambda error rate > 5% for 5 minutes
- API Gateway 5xx rate > 1% for 5 minutes
- DynamoDB throttling events
- GuardDuty high/critical findings
- KMS key access denied events
- VPC Flow Logs showing rejected traffic spike

### Warning Alarms (Notify ops team)

- Lambda duration approaching timeout
- S3 bucket access denied events
- CloudWatch Logs ingestion lag
- Config rule compliance drift

### Dashboards

- Real-time platform health dashboard
- Security posture dashboard (GuardDuty, Security Hub, Config)
- Cost analysis dashboard
- Application performance monitoring

## Compliance

### Controls

- CIS AWS Foundations Benchmark v1.5
- NIST 800-53 (Rev. 5)
- ISO 27001:2022
- SOC 2 Type II
- GDPR (where applicable)

### Audit Requirements

- Quarterly permission boundary reviews
- Quarterly security assessment
- Annual penetration testing
- Continuous vulnerability scanning
- Monthly compliance reports

### Evidence Collection

- All CloudTrail logs retained for 7 years
- Config snapshots retained indefinitely
- Security Hub findings exported to compliance portal
- Access reviews documented and retained

## Incident Response

### Severity Levels

- **SEV-1**: Customer-impacting outage or data breach
- **SEV-2**: Degraded performance or security vulnerability
- **SEV-3**: Non-critical issue with workaround
- **SEV-4**: Minor issue, scheduled fix

### Response Procedures

1. Detection (GuardDuty, Security Hub, CloudWatch alarms)
2. Triage (On-call SRE assesses severity)
3. Escalation (Notify security and engineering leads for SEV-1/SEV-2)
4. Containment (Isolate affected resources)
5. Investigation (Root cause analysis)
6. Recovery (Restore service)
7. Post-mortem (Document lessons learned)

## References

- infra/modules/vpc/ - VPC module documentation
- infra/modules/iam-baseline/ - IAM baseline module
- infra/modules/kms/ - KMS module
- infra/modules/observability/ - Observability module
- REF-002: Platform Constants
- SEC-002: IAM Policy and Trust Relationship Map
- SEC-003: Network Policy and Segmentation
- ops/owners.yaml - Resource ownership and approval requirements
- docs/runbooks/ - Operational runbooks
