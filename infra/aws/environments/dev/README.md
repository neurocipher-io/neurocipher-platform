# Development Environment

## Purpose

Development environment for the Neurocipher platform. Used for active development, feature testing, and integration validation.

## Configuration

- **Environment**: `dev`
- **AWS Account**: Development account
- **Region**: `us-east-1` (primary)
- **VPC CIDR**: `10.0.0.0/16`

## Characteristics

- **Data retention**: 7 days for logs, ephemeral data
- **Encryption**: KMS key alias `alias/nc-dp-data-dev`
- **High availability**: Single AZ deployment acceptable
- **Backup**: No automated backups required
- **Cost optimization**: Use spot instances and auto-scaling with aggressive scale-down

## Resource Naming

All resources use the `-dev` suffix:
- S3 buckets: `nc-dp-dev-raw`, `nc-dp-dev-norm`
- DynamoDB tables: `nc-dp-dev-documents`
- Lambda functions: `svc-{name}-dev`
- KMS keys: `alias/nc-dp-data-dev`

## Access Control

- Developers have full deployment and testing access via `DeveloperRole`
- Read/write access to all development resources
- Can create and destroy infrastructure within environment boundaries
- MFA not required for development operations
- Session duration: 8 hours

## Differences from Production

| Aspect | Development | Production |
|--------|------------|------------|
| HA | Single AZ | Multi-AZ |
| Backups | None | Daily automated |
| Monitoring | Basic metrics | Full observability |
| Encryption | AWS-managed keys acceptable | Customer-managed keys required |
| Data retention | 7 days | 90+ days |
| Cost controls | Aggressive scale-down | Performance-optimized |

## Module Usage

```hcl
terraform {
  backend "s3" {
    bucket = "nc-terraform-state-dev"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  environment = "dev"
  region      = "us-east-1"
  
  common_tags = {
    Environment = "dev"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-engineering"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment              = local.environment
  vpc_cidr                 = "10.0.0.0/16"
  enable_nat_gateway       = true
  single_nat_gateway       = true  # Cost optimization
  enable_vpc_endpoints     = true
  enable_flow_logs         = true
  flow_logs_retention_days = 7
  
  tags = local.common_tags
}

module "iam_baseline" {
  source = "../../modules/iam-baseline"
  
  environment         = local.environment
  account_id          = var.aws_account_id
  security_account_id = var.security_account_id
  enable_github_oidc  = true
  
  tags = local.common_tags
}

module "kms" {
  source = "../../modules/kms"
  
  environment          = local.environment
  enable_key_rotation  = true
  deletion_window_days = 7  # Shorter for dev
  
  lambda_role_arns  = [module.iam_baseline.lambda_etl_role_arn]
  fargate_role_arns = [module.iam_baseline.fargate_task_role_arn]
  
  tags = local.common_tags
}

module "observability" {
  source = "../../modules/observability"
  
  environment        = local.environment
  kms_key_arn        = module.kms.logs_key_arn
  vpc_id             = module.vpc.vpc_id
  log_retention_days = 7
  
  alert_email = "dev-alerts@neurocipher.io"
  
  enable_guardduty    = true
  enable_config_rules = false  # Optional for dev
  
  tags = local.common_tags
}
```

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy environment (when needed)
terraform destroy
```

## Testing

- Feature branch deployments use this environment
- Integration tests run against dev resources
- Data seeding scripts available in `scripts/seed-dev-data.sh`
- Can be torn down and recreated as needed

## Monitoring

- CloudWatch dashboards: Basic metrics only
- Alarms: Critical failures only
- Logs retention: 7 days
- No on-call rotation for dev alerts

## References

- infra/modules/vpc/ - VPC module documentation
- infra/modules/iam-baseline/ - IAM baseline module
- infra/modules/kms/ - KMS module
- infra/modules/observability/ - Observability module
- REF-002: Platform Constants
