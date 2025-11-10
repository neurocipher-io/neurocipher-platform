  

SEC-004 Secrets and KMS Rotation Playbook

  

  

Neurocipher Data Pipeline • Scope: AWS KMS key hierarchy, secret management lifecycle, and automated rotation workflow.

  

  

  

  

1. Objective

  

  

Guarantee cryptographic integrity, confidentiality, and recoverability of all sensitive material in the data pipeline through controlled key rotation, isolation, and auditable automation.

  

  

  

  

2. Scope of protection

  

|   |   |   |
|---|---|---|
|Asset|Protection method|Storage|
|Application secrets (DB creds, API keys)|AWS Secrets Manager|Encrypted with app-tier CMK|
|Data encryption keys|AWS KMS CMKs (per data-tier)|KMS managed|
|S3 objects|SSE-KMS|Bucket-level CMK|
|Weaviate vector snapshots|KMS + envelope encryption|S3 snapshot bucket|
|Parameterized configs|SSM Parameter Store|Encrypted with KMS|
|Logs and audit data|S3 + CloudWatch Logs|KMS-Log CMK|

  

  

  

  

3. Key hierarchy

  

|   |   |   |   |   |
|---|---|---|---|---|
|Tier|CMK alias|Purpose|Key type|Rotation|
|Root Org|alias/org-root|org control plane|customer-managed|annual|
|App Tier|alias/pipeline-app|encrypt secrets, tokens|customer-managed|180 days|
|Data Tier|alias/pipeline-data|S3 objects, Weaviate vectors|customer-managed|365 days|
|Log Tier|alias/pipeline-log|log archive encryption|customer-managed|annual|
|Backup Tier|alias/pipeline-backup|Glacier, RDS snapshots|AWS-managed|annual|
|Dev/Test|alias/dev-shared|non-prod only|AWS-managed|90 days|

All CMKs reside in the neurocipher-security account with grants to workload accounts. Multi-Region replicas exist for DR.

  

  

  

  

4. Secrets Manager rotation configuration

  

  

Each secret defines a rotation Lambda function written in Python 3.12, triggered by an EventBridge rule.

|   |   |   |   |
|---|---|---|---|
|Secret name|Rotation period|Handler|Notes|
|weaviate-creds-prod|30 days|rotate_weaviate_secret.lambda_handler|writes new creds to ECS task env|
|db-access-token|45 days|rotate_db_secret.lambda_handler|triggers Glue job to validate|
|api-gateway-key|90 days|rotate_api_secret.lambda_handler|updates API GW usage plan|
|ci-github-oidc|180 days|static|OIDC credential rotation via repo secret API|

Example Lambda skeleton:

def lambda_handler(event, context):

    step = event['Step']

    if step == 'createSecret':

        new_value = generate_new_secret()

        secretsmanager.put_secret_value(

            SecretId=event['SecretId'],

            SecretString=json.dumps(new_value),

            VersionStages=['AWSPENDING']

        )

    elif step == 'setSecret':

        deploy_to_target(new_value)

    elif step == 'testSecret':

        validate_secret(new_value)

    elif step == 'finishSecret':

        secretsmanager.update_secret_version_stage(

            SecretId=event['SecretId'],

            VersionStage='AWSCURRENT'

        )

  

  

  

  

5. KMS rotation workflow

  

  

6. Detection: Config rule kms-key-rotation-enabled ensures each CMK has rotation = true.
7. Trigger: Scheduled EventBridge job runs quarterly:

  

aws kms rotate-key --key-id $(aws kms list-keys --query "Keys[].KeyId" --output text)

  

2.   
    
3. Propagation: New data keys re-issued automatically by envelope encryption on next write.
4. Revocation: Old data keys disabled after 30 days grace period.
5. Audit: CloudTrail logs RotateKey events → Security Hub finding.
6. Backup: Export previous CMK metadata to S3 for record.

  

  

  

  

  

7. Break-glass procedure

  

  

- Emergency access role: BreakGlassSecurityAdmin.
- MFA required; auto-expire after 1 hour via session policy.
- Action log stored in arn:aws:s3:::neurocipher-log-vault.
- Immediate rotation of all secrets touched during session.

  

  

  

  

  

7. Incident response (compromised secret or key)

  

  

8. Disable secret version or key.
9. Rotate dependent service credentials.
10. Trigger Lambda ir-disable-access.
11. Force STS session revocation.
12. Notify Security Hub and ticket system.
13. Run data re-encryption job if exposure > threshold.

  

  

  

  

  

14. Monitoring and audit

  

  

- CloudTrail logs all GetSecretValue, Decrypt, RotateKey.
- Config rule secretsmanager-rotation-enabled-check.
- GuardDuty monitors unusual KMS API patterns.
- Macie flags plaintext credentials in S3.
- Security Hub aggregates under “Secrets Manager 1” domain.

  

  

  

  

  

9. Automation summary

  

|   |   |
|---|---|
|Control|Mechanism|
|Secret rotation|Lambda per secret, EventBridge schedule|
|Key rotation|KMS auto-rotation + quarterly manual check|
|Access validation|Lambda unit tests and Glue job integration tests|
|Revocation|Session Manager automation runbook|
|Compliance|AWS Config + Security Hub dashboards|

  

  

  

  

10. Residual risk

  

  

- Minimal window between new secret creation and service propagation (< 60 s).
- Possible false positives in automated rotation tests—accepted as low impact.

  

  

  

  

  

11. Compliance mapping

  

|   |   |
|---|---|
|Framework|Controls|
|CIS AWS 1.5|2.3, 3.4, 4.1|
|NIST 800-53|SC-12, SC-13, SC-28|
|ISO 27001|A.8.28, A.8.31, A.8.32|

