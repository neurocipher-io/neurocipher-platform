  

SEC-002 IAM Policy and Trust Relationship Map

  

  

Neurocipher Data Pipeline • Scope: AWS-native identity, access, and trust boundaries for all pipeline services.

  

  

  

  

1. Objective

  

  

Define least-privilege identity structure, policy scope, and trust relationships across accounts and services to enforce segregation of duties, minimize lateral movement, and support automated rotation.

  

  

  

  

2. Identity hierarchy

  

|   |   |   |
|---|---|---|
|Layer|Purpose|Key entities|
|Organization root|Control plane|Organizations, SCPs, delegated admin for SecurityHub, GuardDuty|
|Management account|Governance|IAM Identity Center (SSO), account provisioning via Control Tower|
|Workload accounts|Pipeline runtime|neurocipher-prod, neurocipher-staging, neurocipher-security, neurocipher-logs|
|Service identities|Execution|Lambda, ECS tasks, Glue, API Gateway, CodePipeline roles|
|Human identities|Admin & developer|Federated via SSO, no long-lived keys|
|External identities|CI/CD OIDC, GitHub Actions, third-party scanners|Limited to pre-approved roles with session policies|

  

  

  

  

3. Account and role taxonomy

  

|   |   |   |   |   |
|---|---|---|---|---|
|Account|Role name|Function|Trust policy|Notes|
|management|OrgAdmin|baseline control|IAM Identity Center|Full control under SCP guardrails|
|security|SecurityAuditor|read-only across org|sts:AssumeRole from SSO group SecurityTeam|Read-only, cannot mutate resources|
|logs|LogArchiver|manage central S3 + CloudTrail|sts:AssumeRole from Security account|Enforced encryption + Object Lock|
|prod|PipelineExecutionRole|deploy infrastructure|CodePipeline|Scoped to CloudFormation stacks|
|prod|LambdaETLRole|execute ETL lambdas|AWS Lambda|Managed by permission boundary pb-etl|
|prod|FargateTaskRole|read/write to S3, Weaviate, KMS|ECS tasks|Scoped via condition tags app=datapipe|
|prod|WeaviateAdminRole|manage schema, config|Security account|Manual assume, MFA required|
|staging|DeveloperRole|deploy and test|SSO group DevTeam|Restricted via service control boundaries|

  

  

  

  

4. Permission boundaries and policies

  

  

  

4.1 Permission boundaries

  

  

- pb-etl: allow only S3 read/write to designated prefixes, KMS encrypt/decrypt with data-tier key, CloudWatch logs.
- pb-fargate: allow S3, KMS, SecretsManager:GetSecretValue, DynamoDB:Query limited to tagged resources.
- pb-admin: infrastructure management only; no data access.
- Enforced with condition: "StringEquals": {"aws:RequestTag/app": "neurocipher-pipeline"}.

  

  

  

4.2 SCPs (Service Control Policies)

  

|   |   |
|---|---|
|Policy|Deny conditions|
|SCP-GlobalDenyPublic|Deny PutBucketAcl with PublicRead*, PutBucketPolicy with "Principal":"*"|
|SCP-RestrictRegions|Allow only us-east-1, ca-central-1|
|SCP-DenyRootAccess|Deny all actions when aws:PrincipalAccount = root|
|SCP-GuardrailPassRole|Deny iam:PassRole unless role ARN matches `/^arn:aws:iam::[0-9]+:role/(LambdaETLRole|
|SCP-DenyUnencryptedS3|Deny s3:PutObject unless s3:x-amz-server-side-encryption = aws:kms|

  

  

  

  

5. Trust relationships (service-to-service)

  

|   |   |   |   |
|---|---|---|---|
|Source|Target|Trust mechanism|Notes|
|Lambda (ETL)|S3, KMS, Secrets Manager|IAM role with boundary pb-etl|Inline policy + condition on resource tags|
|ECS Fargate|S3, Weaviate, KMS|IAM role with boundary pb-fargate|Uses task role credentials only|
|CodePipeline|CloudFormation, ECR, CodeBuild|AssumeRole with condition "aws:SourceAccount" = management|Prevents cross-account privilege escalation|
|Security account|All other accounts|STS AssumeRole|Read-only cross-account auditor|
|GitHub Actions|OIDCProvider/github|OIDC with condition sub and aud|No long-lived secrets|
|API Gateway|Lambda|Invocation role trust|Resource policy restricts to internal account only|

  

  

  

  

6. IAM policy samples

  

  

  

6.1 Lambda ETL Role inline

  

{

  "Version": "2012-10-17",

  "Statement": [

    {

      "Sid": "S3Access",

      "Effect": "Allow",

      "Action": ["s3:GetObject", "s3:PutObject"],

      "Resource": ["arn:aws:s3:::neurocipher-raw/*", "arn:aws:s3:::neurocipher-curated/*"]

    },

    {

      "Sid": "EncryptData",

      "Effect": "Allow",

      "Action": ["kms:Encrypt", "kms:Decrypt"],

      "Resource": "arn:aws:kms:region:acct:key/key-id"

    },

    {

      "Sid": "WriteLogs",

      "Effect": "Allow",

      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],

      "Resource": "*"

    }

  ]

}

  

6.2 Fargate Task Role inline

  

{

  "Version": "2012-10-17",

  "Statement": [

    {

      "Sid": "VectorStoreAccess",

      "Effect": "Allow",

      "Action": ["s3:GetObject", "s3:PutObject"],

      "Resource": ["arn:aws:s3:::neurocipher-vector/*"]

    },

    {

      "Sid": "WeaviateSecrets",

      "Effect": "Allow",

      "Action": ["secretsmanager:GetSecretValue"],

      "Resource": "arn:aws:secretsmanager:region:acct:secret:weaviate-creds-*"

    },

    {

      "Sid": "EncryptOps",

      "Effect": "Allow",

      "Action": ["kms:Encrypt", "kms:Decrypt"],

      "Resource": "arn:aws:kms:region:acct:key/key-id"

    }

  ]

}

  

  

  

  

7. Federation and SSO

  

|   |   |   |   |
|---|---|---|---|
|Identity source|Destination|Protocol|Notes|
|AWS Identity Center|IAM roles|SAML 2.0|MFA enforced|
|GitHub OIDC|AWS IAM role|OpenID Connect|Used for CI/CD deploys|
|CLI developer|IAM via SSO login|SSO token|1-hour session max|
|Audit tools (Prowler, GuardDuty)|Read-only IAM role|STS assume|Monitored via CloudTrail|

  

  

  

  

8. Rotation and key handoff

  

  

- IAM access keys disabled globally; automation roles only.
- Session duration:  
    

- Human: 1 hour
- Service: 12 hours

-   
    
- Permission boundary rotation and validation every quarter.
- IAM analyzer runs daily; anomalies generate Security Hub finding.

  

  

  

  

  

9. Monitoring and detection

  

  

- CloudTrail org trails for all IAM and STS events.
- GuardDuty monitors anomalous API usage (e.g., AssumeRole from foreign IP).
- AWS Config rules:  
    

- iam-user-no-access-key
- iam-password-policy
- iam-root-access-key-check

-   
    
- Security Hub aggregates IAM-related findings into IAM:1 control domain.

  

  

  

  

  

10. Residual risk

  

  

- Temporary exposure possible through mis-tagged resources (ABAC misalignment). Mitigation: quarterly tag audit.
- OIDC misconfiguration may allow unauthorized workflow role assumption. Mitigation: restrict subject claim regex and audience match.

  

  

  

  

  

11. Compliance mapping

  |   |   |
|---|---|
|Framework|Control references|
|CIS AWS 1.5|1.3, 1.4, 1.5, 1.6, 1.7|
|NIST 800-53|AC-2, AC-3, AC-5, IA-2, IA-4|
|ISO 27001|A.5.18, A.8.2, A.8.3, A.8.6|
