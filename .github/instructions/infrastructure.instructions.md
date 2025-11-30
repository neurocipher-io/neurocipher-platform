---
description: Infrastructure as Code standards for Neurocipher platform
applyTo: 'infra/**/*.{tf,json,yaml,yml}'
---

# Infrastructure as Code Standards

Infrastructure for the Neurocipher platform is defined using Terraform and AWS CloudFormation. All infrastructure must follow security best practices and naming conventions.

## General Principles

- **Infrastructure as Code**: All infrastructure must be defined in code, never created manually
- **Least Privilege**: Use minimal IAM permissions required for functionality
- **Encryption**: Encrypt all data at rest and in transit
- **Immutability**: Prefer immutable infrastructure patterns
- **Monitoring**: Enable logging and monitoring for all resources
- **Tagging**: Apply consistent tags to all resources

## Terraform Standards

### File Organization

```
infra/
├── modules/           # Reusable Terraform modules
│   ├── lambda/
│   ├── dynamodb/
│   └── s3/
└── aws/              # Environment-specific configurations
    ├── dev/
    ├── stg/
    └── prod/
```

### Module Structure

Each module should have:

```
module-name/
├── main.tf         # Main resource definitions
├── variables.tf    # Input variables
├── outputs.tf      # Output values
├── versions.tf     # Provider version constraints
└── README.md       # Module documentation
```

### Code Style

- Use 2-space indentation
- Group related resources together
- Add comments for complex logic
- Use consistent naming patterns

```hcl
# Lambda function for data ingestion
resource "aws_lambda_function" "ingest_api" {
  function_name = "svc-ingest-api-${var.environment}"
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = "INFO"
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "svc-ingest-api-${var.environment}"
      Service = "data-pipeline"
    }
  )
}
```

### Variables

Define clear variable descriptions and defaults:

```hcl
variable "environment" {
  description = "Environment name (dev, stg, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "Environment must be dev, stg, or prod."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout > 0 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}
```

### Outputs

Provide useful outputs for other modules:

```hcl
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ingest_api.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ingest_api.function_name
}
```

## AWS Resource Naming

### Naming Conventions

Follow consistent patterns across all resources:

- **Lambda functions**: `svc-{domain}-{function}-{env}`
- **S3 buckets**: `nc-dp-{env}-{purpose}` (e.g., `nc-dp-dev-raw`)
- **DynamoDB tables**: `nc-dp-{env}-{entity}` (e.g., `nc-dp-dev-documents`)
- **IAM roles**: `nc-{service}-{env}-{purpose}`
- **KMS keys**: `alias/nc-dp-data-{env}`
- **Step Functions**: `nc-{workflow}-{env}`

### Examples

```hcl
# Lambda function
resource "aws_lambda_function" "ingest" {
  function_name = "svc-ingest-api-${var.environment}"
  # ...
}

# S3 bucket
resource "aws_s3_bucket" "raw" {
  bucket = "nc-dp-${var.environment}-raw"
  # ...
}

# DynamoDB table
resource "aws_dynamodb_table" "documents" {
  name = "nc-dp-${var.environment}-documents"
  # ...
}

# IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "nc-lambda-${var.environment}-exec"
  # ...
}
```

## Security Best Practices

### IAM Policies

Always use least privilege:

```hcl
# Good - specific permissions
resource "aws_iam_role_policy" "lambda_s3" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.raw.arn}/*"
      }
    ]
  })
}

# Bad - overly permissive
resource "aws_iam_role_policy" "lambda_s3_bad" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"           # Too broad
      Resource = "*"              # Too broad
    }]
  })
}
```

### Encryption

Enable encryption for all data at rest:

```hcl
# S3 bucket with encryption
resource "aws_s3_bucket" "secure" {
  bucket = "nc-dp-${var.environment}-secure"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

# DynamoDB with encryption
resource "aws_dynamodb_table" "secure" {
  name     = "nc-dp-${var.environment}-secure"
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.data.arn
  }
}
```

### KMS Keys

Use customer-managed KMS keys:

```hcl
resource "aws_kms_key" "data" {
  description             = "Data encryption key for ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "nc-dp-data-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "data" {
  name          = "alias/nc-dp-data-${var.environment}"
  target_key_id = aws_kms_key.data.key_id
}
```

### Secrets Management

Never hardcode secrets. Use AWS Secrets Manager or SSM Parameter Store:

```hcl
# Store secret in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "nc-dp-${var.environment}-db-password"
  
  tags = {
    Environment = var.environment
  }
}

# Reference in Lambda
resource "aws_lambda_function" "app" {
  # ...
  
  environment {
    variables = {
      DB_PASSWORD_SECRET = aws_secretsmanager_secret.db_password.name
    }
  }
}

# Bad - hardcoded secret
resource "aws_lambda_function" "bad" {
  environment {
    variables = {
      DB_PASSWORD = "mysecretpassword"  # Never do this!
    }
  }
}
```

## Lambda Configuration

### Best Practices

```hcl
resource "aws_lambda_function" "example" {
  function_name = "svc-example-${var.environment}"
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  
  # Use appropriate timeout
  timeout     = 30  # Default, adjust as needed
  memory_size = 512 # Start here, increase if needed
  
  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }
  
  # Configure VPC if needed
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  # Environment variables
  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = var.log_level
      # Reference secrets by name, not value
      DB_SECRET_NAME = aws_secretsmanager_secret.db.name
    }
  }
  
  # Enable dead letter queue
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
  
  tags = local.common_tags
}
```

### Lambda Layers

```hcl
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "dependencies.zip"
  layer_name          = "nc-dependencies-${var.environment}"
  compatible_runtimes = ["python3.12"]
  
  description = "Common dependencies for Neurocipher services"
}

resource "aws_lambda_function" "with_layer" {
  # ...
  layers = [aws_lambda_layer_version.dependencies.arn]
}
```

## S3 Configuration

### Bucket Security

```hcl
resource "aws_s3_bucket" "secure" {
  bucket = "nc-dp-${var.environment}-secure"
}

# Block public access
resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.secure.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable logging
resource "aws_s3_bucket_logging" "secure" {
  bucket = aws_s3_bucket.secure.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id

  rule {
    id     = "archive-old-objects"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}
```

## DynamoDB Configuration

### Table Design

```hcl
resource "aws_dynamodb_table" "documents" {
  name           = "nc-dp-${var.environment}-documents"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "created_at"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # Global secondary index
  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.data.arn
  }

  tags = local.common_tags
}
```

## Step Functions

### State Machine Configuration

```hcl
resource "aws_sfn_state_machine" "pipeline" {
  name     = "nc-data-pipeline-${var.environment}"
  role_arn = aws_iam_role.sfn_exec.arn

  definition = jsonencode({
    Comment = "Data pipeline orchestration"
    StartAt = "IngestData"
    States = {
      IngestData = {
        Type     = "Task"
        Resource = aws_lambda_function.ingest.arn
        Next     = "NormalizeData"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "HandleError"
        }]
      }
      NormalizeData = {
        Type     = "Task"
        Resource = aws_lambda_function.normalize.arn
        Next     = "EmbedData"
      }
      EmbedData = {
        Type     = "Task"
        Resource = aws_lambda_function.embed.arn
        End      = true
      }
      HandleError = {
        Type = "Fail"
        Cause = "Pipeline execution failed"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

  tags = local.common_tags
}
```

## Monitoring & Logging

### CloudWatch Log Groups

```hcl
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.example.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn

  tags = local.common_tags
}
```

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function error rate is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.example.function_name
  }
}
```

## Tagging Strategy

Apply consistent tags to all resources:

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

resource "aws_lambda_function" "example" {
  # ...
  tags = local.common_tags
}
```

## VPC Configuration

### Network Security

```hcl
resource "aws_security_group" "lambda" {
  name        = "nc-lambda-${var.environment}"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  # Egress to DynamoDB via VPC endpoint
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "nc-lambda-${var.environment}"
    }
  )
}
```

## Testing & Validation

### Terraform Validation

Always validate before applying:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

### Pre-commit Hooks

Use pre-commit hooks for validation:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.77.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
```

## Documentation

### Module README

Each module must have a README.md:

```markdown
# Lambda Module

Creates Lambda functions with standard configuration.

## Usage

```hcl
module "lambda" {
  source = "../../modules/lambda"
  
  function_name = "svc-example"
  environment   = "dev"
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  
  environment_variables = {
    LOG_LEVEL = "INFO"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Lambda function name | string | - | yes |
| runtime | Lambda runtime | string | python3.12 | no |

## Outputs

| Name | Description |
|------|-------------|
| function_arn | ARN of Lambda function |
| function_name | Name of Lambda function |
```

## Anti-Patterns to Avoid

1. **Hardcoded values**: Use variables and parameters
2. **Overly permissive IAM**: Use least privilege
3. **Unencrypted resources**: Always enable encryption
4. **Missing monitoring**: Enable CloudWatch logs and alarms
5. **Inconsistent naming**: Follow naming conventions
6. **Manual changes**: Always use IaC
7. **Secrets in code**: Use Secrets Manager or Parameter Store

## Review Checklist

Before submitting IaC changes:

- [ ] All resources have appropriate tags
- [ ] IAM policies use least privilege
- [ ] Encryption is enabled for data at rest
- [ ] CloudWatch logging is configured
- [ ] Naming follows conventions
- [ ] No hardcoded secrets
- [ ] Variables have descriptions and validation
- [ ] Outputs are documented
- [ ] `terraform validate` passes
- [ ] `terraform plan` reviewed
- [ ] Module README is updated

## References

- Review `ops/owners.yaml` for IAM-related approvals
- See REF-002 for platform constants
- Check AGENTS.md for automation rules
