# Observability Module

## Purpose

Establishes comprehensive logging, monitoring, and alerting infrastructure for the Neurocipher platform, integrating CloudWatch, CloudTrail, GuardDuty, Security Hub, and Config.

## Responsibilities

- Configure CloudWatch log groups with retention and KMS encryption
- Enable AWS CloudTrail organization trails for all API activity
- Set up VPC Flow Logs for network traffic analysis
- Deploy GuardDuty for threat detection
- Configure AWS Config rules for compliance monitoring
- Integrate Security Hub for centralized security findings
- Create CloudWatch dashboards for operational metrics
- Define CloudWatch alarms for critical thresholds
- Configure SNS topics for alert notifications
- Set up AWS Network Insights Path for connectivity validation

## Constraints

- **Log retention**: Minimum 90 days for operational logs, 2 years for audit logs
- **Encryption**: All logs must be encrypted with KMS customer-managed keys
- **Centralization**: All logs forwarded to central logs account
- **Immutability**: Audit logs protected with S3 Object Lock
- **Real-time**: Critical security alerts delivered within 5 minutes
- **Cost optimization**: Use CloudWatch Logs Insights for queries, archive to S3 Glacier after retention period

## Components

### CloudWatch Logs

- Lambda function logs: `/aws/lambda/{function-name}`
- VPC Flow Logs: `/aws/vpc/flow-logs/{vpc-id}`
- API Gateway logs: `/aws/apigateway/{api-name}`
- Application logs: `/aws/app/{service-name}`

Retention: 90 days (operational), 730 days (audit)

### CloudTrail

- Organization trail capturing all accounts
- Management and data events logged
- Log file validation enabled
- Delivery to central S3 bucket with Object Lock
- CloudWatch Logs integration for real-time analysis

### GuardDuty

- Enabled across all accounts and regions
- Findings aggregated to Security Hub
- High/critical findings trigger SNS alerts
- Integrates VPC Flow Logs, DNS logs, and CloudTrail

### AWS Config

Rules monitored:
- `iam-user-no-access-key`
- `iam-password-policy`
- `s3-bucket-public-read-prohibited`
- `s3-bucket-server-side-encryption-enabled`
- `vpc-flow-logs-enabled`
- `cloudtrail-enabled`

### Security Hub

- CIS AWS Foundations Benchmark
- AWS Foundational Security Best Practices
- NIST 800-53 controls
- Custom findings from application security scans

## Usage

```hcl
module "observability" {
  source = "../../modules/observability"
  
  environment = "prod"
  
  # KMS key for log encryption
  kms_key_arn = module.kms.logs_key_arn
  
  # Central logs account
  logs_account_id = "111111111111"
  logs_bucket_name = "nc-dp-logs-central"
  
  # Alert notifications
  alert_email = "security@neurocipher.io"
  ops_email   = "ops@neurocipher.io"
  
  # VPC for flow logs
  vpc_id = module.vpc.vpc_id
  
  # Config rules
  enable_config_rules = true
  
  # GuardDuty
  enable_guardduty = true
  guardduty_finding_publishing_frequency = "FIFTEEN_MINUTES"
  
  tags = {
    Environment = "prod"
    Project     = "neurocipher-platform"
    ManagedBy   = "terraform"
  }
}
```

## Outputs

- `cloudwatch_log_group_arns`: Map of log group ARNs by service
- `cloudtrail_arn`: Organization trail ARN
- `sns_alert_topic_arn`: SNS topic ARN for security alerts
- `sns_ops_topic_arn`: SNS topic ARN for operational alerts
- `guardduty_detector_id`: GuardDuty detector ID
- `config_recorder_name`: Config recorder name
- `security_hub_arn`: Security Hub ARN

## Alarms

### Lambda Errors

- Metric: `Errors`
- Threshold: > 5 in 5 minutes
- Action: Notify ops team

### API Gateway 5xx

- Metric: `5XXError`
- Threshold: > 10 in 5 minutes
- Action: Notify ops team

### GuardDuty High/Critical Findings

- Metric: Custom metric from GuardDuty
- Threshold: > 0
- Action: Notify security team immediately

### VPC Flow Logs Rejected Traffic

- Metric: Custom metric from Flow Logs
- Threshold: > 100 in 5 minutes
- Action: Notify security team

### KMS API Throttling

- Metric: `UserErrorCount`
- Threshold: > 10 in 5 minutes
- Action: Notify ops team

## Dashboards

### Platform Health Dashboard

- Lambda execution metrics (duration, errors, invocations)
- API Gateway metrics (request count, latency, errors)
- DynamoDB metrics (throttles, read/write capacity)
- S3 metrics (request counts, errors)

### Security Dashboard

- GuardDuty findings by severity
- Config compliance status
- CloudTrail API call volume by service
- Failed authentication attempts
- VPC Flow Logs rejected connections

### Cost Dashboard

- Service costs by account
- Data transfer metrics
- KMS API call volume
- CloudWatch Logs ingestion volume

## Integration Points

### Application Logging

All services must use structured JSON logging:

```python
import logging
import json

logger = logging.getLogger(__name__)

logger.info(json.dumps({
    "event": "processing_started",
    "trace_id": trace_id,
    "service": "svc-ingest-api",
    "environment": "prod",
    "timestamp": datetime.utcnow().isoformat()
}))
```

### Metrics

Custom application metrics published to CloudWatch:

```python
cloudwatch.put_metric_data(
    Namespace="Neurocipher/DataPipeline",
    MetricData=[{
        "MetricName": "DocumentsProcessed",
        "Value": count,
        "Unit": "Count",
        "Dimensions": [
            {"Name": "Environment", "Value": "prod"},
            {"Name": "Service", "Value": "svc-ingest-api"}
        ]
    }]
)
```

## Security Considerations

- All log data encrypted at rest with KMS
- Log bucket access restricted to security and auditor roles
- CloudTrail log file validation prevents tampering
- S3 Object Lock on audit logs prevents deletion
- GuardDuty findings auto-trigger security workflows
- Network Insights Path runs quarterly for validation
- Log groups have resource policies limiting access

## References

- SEC-002: IAM Policy and Trust Relationship Map (section 9 on monitoring)
- SEC-003: Network Policy and Segmentation (section 10 on observability)
- infra/modules/kms/ for log encryption keys
- infra/modules/iam-baseline/ for CloudTrail and Config roles
- ops/dashboards/ for dashboard definitions
