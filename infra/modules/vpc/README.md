# VPC Module

## Purpose

Provisions AWS VPC infrastructure with public, private-app, and private-data subnet tiers to support network segmentation and zero-trust architecture as defined in SEC-003.

## Responsibilities

- Create VPC with configurable CIDR block (default: 10.0.0.0/16)
- Provision multi-AZ subnets for public, private-app, and private-data tiers
- Configure route tables and NAT gateways
- Set up VPC endpoints for S3, DynamoDB, KMS, Secrets Manager, STS, and CloudWatch
- Apply security groups and network ACLs with default-deny posture
- Enable VPC Flow Logs for observability
- Configure DNS resolution and private hosted zones

## Constraints

- **Region restriction**: Deployments limited to us-east-1, ca-central-1 per SCP-RestrictRegions
- **CIDR allocation**: Must not overlap with existing VPCs or on-premises networks
- **NAT egress**: Restricted to approved package repositories only
- **Endpoint policies**: All VPC endpoints must enforce principal-based access control
- **Tagging**: All resources must include `tier` (public|app|data) and `env` (dev|stg|prod) tags

## Network Layout

```
10.0.0.0/16 VPC
├── AZ-A
│   ├── 10.0.0.0/19   public subnet
│   ├── 10.0.32.0/19  private-app subnet
│   └── 10.0.64.0/19  private-data subnet
└── AZ-B
    ├── 10.0.96.0/19  public subnet
    ├── 10.0.128.0/19 private-app subnet
    └── 10.0.160.0/19 private-data subnet
```

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  environment = "prod"
  vpc_cidr    = "10.0.0.0/16"
  
  enable_nat_gateway     = true
  enable_vpc_endpoints   = true
  enable_flow_logs       = true
  
  tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
  }
}
```

## Outputs

- `vpc_id`: VPC identifier
- `public_subnet_ids`: List of public subnet IDs
- `private_app_subnet_ids`: List of private-app subnet IDs
- `private_data_subnet_ids`: List of private-data subnet IDs
- `nat_gateway_ids`: List of NAT Gateway IDs
- `vpc_endpoint_ids`: Map of VPC endpoint IDs by service name

## Security Considerations

- Public subnets only for CloudFront, WAF, API Gateway, and ALB ingress
- Private-app subnets have NAT gateway for OS updates with allowlist enforcement
- Private-data subnets have no internet access; VPC endpoints only
- All inter-subnet traffic must be explicitly allowed via security groups
- VPC Flow Logs monitored by GuardDuty for anomalous traffic patterns

## References

- SEC-003: Network Policy and Segmentation
- REF-002: Platform Constants (section on network addressing)
- infra/modules/observability/ for Flow Logs and monitoring integration
