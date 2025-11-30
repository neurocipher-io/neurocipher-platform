# KMS Module

## Purpose

Provisions AWS KMS customer-managed keys for encryption at rest across all data tiers, with key policies enforcing least-privilege access and automatic key rotation.

## Responsibilities

- Create environment-specific KMS keys for data encryption
- Configure key policies with principal-based access control
- Enable automatic key rotation (365-day cycle)
- Create key aliases following naming convention: `alias/nc-dp-data-{env}`
- Grant access to service roles (Lambda, Fargate, Glue) via key policies
- Set up cross-account key sharing for security and logs accounts
- Enable CloudTrail logging for all KMS operations

## Constraints

- **Deletion protection**: All keys have 30-day deletion window
- **Key rotation**: Automatic rotation enabled for all customer-managed keys
- **Regional**: Keys must be created in same region as encrypted resources
- **Access control**: Key policies must align with permission boundaries from iam-baseline
- **Encryption context**: All encrypt/decrypt operations must include encryption context
- **No default key usage**: Default AWS-managed keys are not permitted for production data

## Key Types

### Data-tier Key

Primary encryption key for:
- S3 buckets (raw, normalized, vector)
- DynamoDB tables
- EBS volumes
- Secrets Manager secrets
- CloudWatch log groups

Alias: `alias/nc-dp-data-{env}`

### Logs Key

Dedicated key for centralized logging:
- CloudTrail logs
- VPC Flow Logs
- Application logs in S3

Alias: `alias/nc-dp-logs-{env}`

## Usage

```hcl
module "kms" {
  source = "../../modules/kms"
  
  environment = "prod"
  
  enable_key_rotation = true
  deletion_window_days = 30
  
  # Service roles that need encrypt/decrypt access
  lambda_role_arns = [module.iam_baseline.lambda_etl_role_arn]
  fargate_role_arns = [module.iam_baseline.fargate_task_role_arn]
  
  # Cross-account access
  security_account_id = "098765432109"
  logs_account_id     = "111111111111"
  
  tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
  }
}
```

## Outputs

- `data_key_id`: KMS key ID for data encryption
- `data_key_arn`: KMS key ARN for data encryption
- `data_key_alias`: KMS key alias for data encryption
- `logs_key_id`: KMS key ID for logs encryption
- `logs_key_arn`: KMS key ARN for logs encryption
- `logs_key_alias`: KMS key alias for logs encryption

## Key Policy Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow service use of the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "LAMBDA_ROLE_ARN",
          "FARGATE_ROLE_ARN"
        ]
      },
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:EncryptionContext:app": "neurocipher-pipeline"
        }
      }
    },
    {
      "Sid": "Allow CloudWatch Logs",
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    }
  ]
}
```

## Security Considerations

- All KMS operations logged to CloudTrail
- Key policies enforce encryption context for service operations
- Cross-account access uses explicit grants with conditions
- Key administrators cannot use keys for encrypt/decrypt operations
- GuardDuty monitors for suspicious KMS API usage patterns
- Keys cannot be deleted immediately (30-day window for recovery)

## Encryption Context

All encrypt/decrypt operations must include:
- `app`: "neurocipher-pipeline"
- `env`: Environment name (dev, stg, prod)
- `service`: Service name (e.g., "svc-ingest-api")

Example:

```python
kms_client.encrypt(
    KeyId="alias/nc-dp-data-prod",
    Plaintext=data,
    EncryptionContext={
        "app": "neurocipher-pipeline",
        "env": "prod",
        "service": "svc-ingest-api"
    }
)
```

## References

- SEC-002: IAM Policy and Trust Relationship Map (section 4 on permission boundaries)
- REF-002: Platform Constants (section on KMS key aliases)
- infra/modules/iam-baseline/ for role definitions
- SCP-DenyUnencryptedS3 in SEC-002 section 4.2
