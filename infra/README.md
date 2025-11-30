# Infrastructure

Infrastructure as Code for the Neurocipher platform. All infrastructure is defined using Terraform modules with environment-specific configurations.

## Structure

```
infra/
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC networking and segmentation
│   ├── iam-baseline/          # IAM roles, policies, and permission boundaries
│   ├── kms/                   # KMS keys for encryption at rest
│   └── observability/         # CloudWatch, CloudTrail, GuardDuty, Security Hub
├── aws/
│   └── environments/
│       ├── dev/               # Development environment
│       ├── stg/               # Staging environment
│       └── prod/              # Production environment
├── gcp/                       # GCP-specific (placeholder for future)
└── azure/                     # Azure-specific (placeholder for future)
```

## Modules

### VPC Module (`modules/vpc/`)

Provisions AWS VPC infrastructure with public, private-app, and private-data subnet tiers implementing SEC-003 network segmentation requirements.

**Key features:**
- Multi-AZ subnet layout (10.0.0.0/16 CIDR)
- VPC endpoints for S3, DynamoDB, KMS, Secrets Manager, STS, CloudWatch
- Security groups and NACLs with default-deny posture
- VPC Flow Logs for network observability
- NAT gateways with egress restrictions

**References:** [modules/vpc/README.md](modules/vpc/README.md), SEC-003

### IAM Baseline Module (`modules/iam-baseline/`)

Establishes foundational IAM roles, policies, permission boundaries, and trust relationships per SEC-002.

**Key features:**
- Service execution roles (Lambda, ECS Fargate, Glue, CodePipeline)
- Permission boundaries (pb-etl, pb-fargate, pb-admin)
- Cross-account trust relationships
- GitHub Actions OIDC provider
- AWS Identity Center integration
- IAM Access Analyzer

**References:** [modules/iam-baseline/README.md](modules/iam-baseline/README.md), SEC-002

### KMS Module (`modules/kms/`)

Provisions AWS KMS customer-managed keys for encryption at rest with automatic key rotation.

**Key features:**
- Environment-specific data encryption keys
- Separate keys for logs encryption
- Key policies with principal-based access control
- Automatic 365-day key rotation
- Cross-account key sharing for security and logs accounts
- Key aliases: `alias/nc-dp-data-{env}`, `alias/nc-dp-logs-{env}`

**References:** [modules/kms/README.md](modules/kms/README.md), REF-002

### Observability Module (`modules/observability/`)

Establishes comprehensive logging, monitoring, and alerting infrastructure.

**Key features:**
- CloudWatch log groups with retention and KMS encryption
- AWS CloudTrail organization trails
- VPC Flow Logs
- GuardDuty threat detection
- AWS Config compliance monitoring
- Security Hub for centralized security findings
- CloudWatch dashboards and alarms

**References:** [modules/observability/README.md](modules/observability/README.md)

## AWS Environments

### Development (`aws/environments/dev/`)

Active development environment with relaxed controls for rapid iteration.

**Characteristics:**
- Single AZ deployment acceptable
- 7-day log retention
- No automated backups
- Full developer access
- Aggressive cost optimization

**References:** [aws/environments/dev/README.md](aws/environments/dev/README.md)

### Staging (`aws/environments/stg/`)

Pre-production environment maintaining production parity for validation.

**Characteristics:**
- Multi-AZ deployment
- 30-day log retention
- Daily automated backups
- Production-equivalent configuration
- MFA required for changes

**References:** [aws/environments/stg/README.md](aws/environments/stg/README.md)

### Production (`aws/environments/prod/`)

Live production environment with strict security, compliance, and SLA requirements.

**Characteristics:**
- 99.9% availability SLA
- Multi-AZ with automatic failover
- 90-day operational logs, 2-year audit logs
- Continuous backup with point-in-time recovery
- Multi-approval workflow for all changes
- 24/7 monitoring and on-call

**References:** [aws/environments/prod/README.md](aws/environments/prod/README.md)

## Multi-Cloud Strategy

### Google Cloud Platform (`gcp/`)

**Status:** Placeholder for future implementation

The GCP directory is reserved for future multi-cloud expansion. When implemented, it will contain Terraform modules and environment configurations mirroring the AWS structure while leveraging GCP-native services.

**References:** [gcp/README.md](gcp/README.md)

### Microsoft Azure (`azure/`)

**Status:** Placeholder for future implementation

The Azure directory is reserved for future multi-cloud expansion. When implemented, it will contain Terraform modules and environment configurations adapted for Azure services and governance models.

**References:** [azure/README.md](azure/README.md)

## Standards & Conventions

### Environment Naming

- **Environments:** `dev`, `stg`, `prod` (per REF-002)
- **Never use:** "development", "staging", "production"

### Resource Naming

- **S3 buckets:** `nc-dp-{env}-{purpose}` (e.g., `nc-dp-prod-raw`)
- **DynamoDB tables:** `nc-dp-{env}-{entity}` (e.g., `nc-dp-prod-documents`)
- **Lambda functions:** `svc-{domain}-{function}-{env}` (e.g., `svc-ingest-api-prod`)
- **KMS keys:** `alias/nc-dp-data-{env}`, `alias/nc-dp-logs-{env}`
- **IAM roles:** `nc-{service}-{env}-{purpose}`

### Tagging Requirements

All resources must include:
- `Environment`: Environment name (dev, stg, prod)
- `Project`: "neurocipher-platform"
- `ManagedBy`: "terraform"
- `Owner`: Team or service owner
- `CostCenter`: Cost allocation tag

### Module Usage

When using infrastructure modules, always:
1. Pin module versions in production
2. Pass environment-specific variables
3. Apply consistent tags
4. Enable encryption with KMS customer-managed keys
5. Configure appropriate logging and monitoring
6. Follow least-privilege IAM principles

### Example Configuration

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  environment          = "prod"
  vpc_cidr             = "10.2.0.0/16"
  enable_nat_gateway   = true
  enable_vpc_endpoints = true
  enable_flow_logs     = true
  
  tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-engineering"
  }
}
```

## Security & Compliance

All infrastructure must comply with:

- **SEC-002:** IAM Policy and Trust Relationship Map
- **SEC-003:** Network Policy and Segmentation
- **REF-001:** Standards catalog (tagging, naming)
- **REF-002:** Platform constants (resource naming, encryption keys)

### Security Controls

- Encryption at rest with customer-managed KMS keys
- Encryption in transit with TLS 1.2+
- Least-privilege IAM policies with permission boundaries
- Network segmentation with default-deny security groups
- VPC endpoints for AWS service access (no internet)
- CloudTrail logging for all API activity
- GuardDuty for threat detection
- Security Hub for security posture management
- AWS Config for compliance monitoring

### Compliance Frameworks

- CIS AWS Foundations Benchmark v1.5
- NIST 800-53 (Rev. 5)
- ISO 27001:2022
- SOC 2 Type II

## Deployment

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- Access to Terraform state backend (S3 + DynamoDB)

### Workflow

```bash
# Navigate to environment directory
cd aws/environments/prod/

# Initialize Terraform
terraform init

# Plan changes
terraform plan -out=tfplan

# Review plan with team
# Obtain approvals (for stg/prod)

# Apply changes
terraform apply tfplan

# Validate deployment
# Monitor for issues
```

### Change Management

- **Development:** Deploy freely with version control
- **Staging:** Require platform engineering review
- **Production:** Multi-approval workflow (platform lead, security lead, CTO for high-risk)

## References

- Infrastructure standards: `.github/instructions/infrastructure.instructions.md`
- Security documentation: `docs/security-controls/`
- Platform constants: `docs/governance/REF-002-Platform-Constants.md`
- Resource ownership: `ops/owners.yaml`
- Architecture documentation: `docs/architecture/`
