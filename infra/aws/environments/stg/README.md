# Staging Environment

## Purpose

Pre-production staging environment for the Neurocipher platform. Used for final validation, performance testing, and release candidate verification before production deployment.

## Configuration

- **Environment**: `stg`
- **AWS Account**: Staging account
- **Region**: `us-east-1` (primary), `ca-central-1` (DR)
- **VPC CIDR**: `10.1.0.0/16`

## Characteristics

- **Data retention**: 30 days for logs, production-like data lifecycle
- **Encryption**: KMS key alias `alias/nc-dp-data-stg`
- **High availability**: Multi-AZ deployment
- **Backup**: Daily automated backups with 7-day retention
- **Performance**: Production-equivalent compute and storage

## Resource Naming

All resources use the `-stg` suffix:
- S3 buckets: `nc-dp-stg-raw`, `nc-dp-stg-norm`
- DynamoDB tables: `nc-dp-stg-documents`
- Lambda functions: `svc-{name}-stg`
- KMS keys: `alias/nc-dp-data-stg`

## Access Control

- Developers have deployment access via `DeveloperRole` (MFA required)
- QA team has read/write access for testing
- Security team has read-only access for pre-production audits
- Infrastructure changes require approval from platform engineering
- Session duration: 4 hours

## Production Parity

Staging maintains production parity for:
- Infrastructure configuration (multi-AZ, same instance types)
- Network topology (same security groups, NACLs, VPC layout)
- IAM policies and permission boundaries
- KMS encryption configuration
- Monitoring and alerting thresholds

Differences from production:
- Smaller dataset (sampled production data)
- Lower traffic volume
- Shorter log retention (30 days vs 90 days)
- No business continuity requirements

## Module Usage

```hcl
terraform {
  backend "s3" {
    bucket = "nc-terraform-state-stg"
    key    = "stg/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  environment = "stg"
  region      = "us-east-1"
  
  common_tags = {
    Environment = "stg"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-engineering"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment              = local.environment
  vpc_cidr                 = "10.1.0.0/16"
  enable_nat_gateway       = true
  single_nat_gateway       = false  # Multi-AZ
  enable_vpc_endpoints     = true
  enable_flow_logs         = true
  flow_logs_retention_days = 30
  
  tags = local.common_tags
}

module "iam_baseline" {
  source = "../../modules/iam-baseline"
  
  environment         = local.environment
  account_id          = var.aws_account_id
  security_account_id = var.security_account_id
  logs_account_id     = var.logs_account_id
  enable_github_oidc  = true
  
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
  log_retention_days = 30
  
  logs_account_id  = var.logs_account_id
  logs_bucket_name = "nc-dp-logs-central"
  
  alert_email = "stg-alerts@neurocipher.io"
  ops_email   = "ops@neurocipher.io"
  
  enable_guardduty    = true
  enable_config_rules = true
  
  tags = local.common_tags
}
```

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan changes with approval
terraform plan -out=tfplan

# Require review from platform engineering
# Apply changes
terraform apply tfplan
```

## Testing

- Release candidate validation
- Performance and load testing
- Security scanning and penetration testing
- Disaster recovery drills
- Integration with external systems
- End-to-end workflow validation

## Data Management

- Uses anonymized production data sample
- Data refreshed weekly from production
- PII masked or synthetic
- Same data volume characteristics as production

## Monitoring

- CloudWatch dashboards: Full observability suite
- Alarms: Production-equivalent thresholds
- Logs retention: 30 days
- GuardDuty and Security Hub enabled
- On-call rotation for critical alerts during testing windows

## Change Management

- All production changes must be validated in staging first
- Staging deployments occur 24-48 hours before production
- Change approval required from:
  - Platform Engineering (infrastructure changes)
  - Security Engineering (security-related changes)
  - Service Owner (application changes)

## References

- infra/modules/vpc/ - VPC module documentation
- infra/modules/iam-baseline/ - IAM baseline module
- infra/modules/kms/ - KMS module
- infra/modules/observability/ - Observability module
- REF-002: Platform Constants
- SEC-002: IAM Policy and Trust Relationship Map
- SEC-003: Network Policy and Segmentation
