  

id: SEC-001
title: Threat Model and Mitigation Matrix
owner: Security Engineering
status: Approved for implementation
last_reviewed: 2025-11-15

SEC-001 Threat Model and Mitigation Matrix

  

  

Neurocipher Data Pipeline • Scope: AWS-only pipeline for ingestion, transform, vectorization, retrieval API. Weaviate remains the vector DB, deployed in VPC on AWS. This document is system-of-record for threats, controls, and residual risk.

  

  

1. System overview

  

  

Core components

  

- Entry: Route53, CloudFront, AWS WAF, API Gateway HTTP API
- AuthN/Z: Amazon Cognito, IAM STS, service roles, SCPs
- Ingest: S3 (object ingest, Object Lock), SQS, Kinesis Data Streams (optional), EventBridge
- Compute: Lambda (ETL microsteps), ECS Fargate (batch and long-run workers), Glue jobs (optional)
- Vector: Weaviate on ECS Fargate or EKS in private subnets, with attached EBS and S3 snapshot backup
- Data: S3 buckets by tier (raw, staged, curated), DynamoDB for metadata, Aurora Serverless v2 for ops metadata (optional)
- Secrets and keys: KMS CMKs, AWS Secrets Manager, Parameter Store
- Observability: CloudWatch, CloudTrail, GuardDuty, Detective, Config, Macie, Inspector, Security Hub
- Egress controls: VPC endpoints for S3, STS, KMS, Secrets Manager, DynamoDB. NAT egress is blocked by default.
- CI/CD: CodePipeline, CodeBuild, ECR with image signing and scan on push

  

  

Trust boundaries

  

- TB1: Public Internet to CloudFront + WAF
- TB2: CloudFront to API Gateway
- TB3: API Gateway private integration to VPC services
- TB4: Workload-to-data stores in private subnets
- TB5: CI/CD to runtime environments
- TB6: Cross-account admin access via IAM roles

  

  

Data classes

  

- D1 Public metadata
- D2 Internal operational data
- D3 Sensitive business data
- D4 Secrets and keys

  

  

  

2. High-value assets

  

  

- A1 S3 curated data and embeddings
- A2 Weaviate indexes and vectors
- A3 Secrets and KMS CMKs
- A4 IAM roles and trust policies
- A5 CI/CD pipelines and signed images
- A6 Audit logs: CloudTrail, S3 access logs, WAF logs

  

  

  

3. Actors and entry points

  

  

- External client via HTTPS
- Internal batch agents via EventBridge
- Admins via SSO and IAM role assumption
- CI/CD service roles
- Inter-service calls using IAM SigV4

  

  

  

4. STRIDE threats by component and flow

  

  

  

4.1 API edge (Route53, CloudFront, WAF, API Gateway)

  

|   |   |   |   |
|---|---|---|---|
|STRIDE|Threat|Impact|Mitigations|
|Spoofing|Stolen tokens used at API|Unauthorized data access|Cognito with short-lived tokens, token audience checks, mTLS to private services, WAF bot control, IP reputation lists|
|Tampering|Payload manipulation in transit|Corrupt ETL inputs|TLS 1.2+, SigV4 on private integrations, JSON schema validation, checksum headers|
|Repudiation|Client denies actions|Audit gap|CloudFront logs, API GW access logs, CloudTrail data events, request IDs, immutable log archive with S3 Object Lock|
|Info Disclosure|Verbose errors, path traversal|Data leak|WAF managed rules, custom error maps, strict CORS, deny-list headers, content security policy on docs site|
|DoS|L7 floods, slowloris|Pipeline stall|WAF rate limits, AWS Shield Advanced, API GW throttling and quotas, SQS buffering downstream|
|Elevation of Privilege|Over-broad API roles|Bypass least privilege|IAM fine-grained authZ, ABAC tags, resource policies bound to VPC endpoints, SCP deny on wildcard actions|

  

4.2 Ingest and ETL (S3, SQS, Lambda, Fargate)

  

|   |   |   |   |
|---|---|---|---|
|STRIDE|Threat|Impact|Mitigations|
|Spoofing|Forged producer identity|Poisoned data|Bucket policies require TLS and SigV4, per-producer IAM roles, signed upload URLs with short TTL|
|Tampering|Object overwrite or version delete|Data integrity loss|S3 versioning + Object Lock Compliance mode, MFA delete, ETag verification, integrity hash in metadata|
|Repudiation|Producer denies upload|Loss of chain of custody|S3 server access logs, EventBridge receipts, immutable audit in Glacier|
|Info Disclosure|Wrong ACL or public bucket|Leak of raw data|Block Public Access at account and bucket, SCPs deny PutBucketPublic, Macie alerts|
|DoS|Hot partition keys, DLQ overflow|Backlog and cost spike|SQS DLQ with redrive, Lambda reserved concurrency and backoff, Kinesis shard autoscaling, budgets and anomaly alerts|
|Elevation of Privilege|Lambda role misuse|Lateral movement|IAM permission boundaries, per-function roles, VPC-only access via endpoints, no instance credentials on tasks|

  

4.3 Vector store (Weaviate in VPC)

  

|   |   |   |   |
|---|---|---|---|
|STRIDE|Threat|Impact|Mitigations|
|Spoofing|Fake service calling Weaviate|Index poisoning|mTLS between clients and Weaviate, NLB with TLS, IAM-auth sidecar or OIDC, security groups with tight source ranges|
|Tampering|Unauthorized schema or vectors|Corrupted retrievals|Role-separated admin and writer identities, schema migration approvals, backup and point-in-time restore from S3 snapshots|
|Repudiation|No action trace on changes|Forensic gaps|Structured audit logs from app and sidecar, CloudWatch log retention 400 days, hash-chain optional log signer|
|Info Disclosure|Embedding exfiltration|Privacy breach|Private subnets only, no public ELB, SG deny-all by default, traffic via VPC endpoints, field-level encryption if app-layer supports|
|DoS|Large batch upserts, vector scans|Latency spike|HPA for Fargate tasks, query rate limits, circuit breaker, bulk ingest windows, autoscaling EBS IOPS|
|Elevation of Privilege|Admin API exposed|Total compromise|Separate admin plane SG, bastion SSM Session Manager only, no public admin, break-glass role with MFA and just-in-time approval|

  

4.4 Identity and keys (IAM, KMS, Secrets Manager)

  

|   |   |   |   |
|---|---|---|---|
|STRIDE|Threat|Impact|Mitigations|
|Spoofing|Stolen credentials|Full access|SSO + MFA, short STS sessions, device posture checks, access keys blocked by SCPs|
|Tampering|Policy edits or key rotation disabled|Control loss|Change Manager approvals, CloudTrail with alarms, KMS rotation 365d, config rules for rotation compliance|
|Repudiation|Admin denies changes|Dispute|CloudTrail organization trails, CloudWatch metric filters on sensitive APIs, immutable log vault|
|Info Disclosure|Secret value reads|Lateral movement|Secrets Manager with per-secret KMS key, deny GetSecretValue outside expected roles, rotation lambda|
|DoS|KMS throttle or quota|Service outage|KMS multi-Region keys, per-service key separation, warm-up tests, request rate smoothing|
|Elevation of Privilege|PassRole misuse|Privilege gain|iam:PassRole scoped to ARNs, permissions boundaries, session policies, SCP deny on iam:*Admin|

  

4.5 CI/CD and supply chain (ECR, CodeBuild, CodePipeline)

  

|   |   |   |   |
|---|---|---|---|
|STRIDE|Threat|Impact|Mitigations|
|Spoofing|Untrusted image source|Malware|ECR allowlist, image signing with Sigstore, provenance attestations (SLSA L3), pull-through cache disabled|
|Tampering|Build script injection|Backdoor|CodeBuild immutable build images, pinned SHAs, no write access from runtime to repos, branch protection|
|Repudiation|No build traceability|Unclear provenance|Pipeline metadata to DynamoDB, artifact hashes, SBOM export and retention|
|Info Disclosure|Secrets in build logs|Leak|OIDC to cloud providers, no static secrets, masked env vars, least-privilege artifact access|
|DoS|Pipeline loop or flood|Deploy freeze|Manual approval gates, concurrency limits, automatic rollback, budget alarms|
|Elevation of Privilege|Pipeline role assumes admin|Org compromise|Scoped pipeline roles, permission boundaries, SCP guardrails, change freeze windows|

  

5. Abuse cases unique to LLM pipelines

  

|   |   |   |
|---|---|---|
|Abuse case|Risk|Controls|
|Prompt injection in source content|Wrong retrieval, data exfil at inference|ETL sanitization, allowlist HTML tags, strip directives, model-side safety filters, unit tests with red-team payloads|
|Data poisoning of embeddings|Biased or harmful retrieval|Multi-source consensus, sample audits, canary datasets, signed content manifests|
|Over-embedding sensitive fields|Privacy breach|Field-level policies, PII detection with Macie, exclude rules in ETL, hashing or tokenization for IDs|
|Retrieval over-broad scope|Context leakage|Query-time ABAC filters, tenant and project tags on vectors, per-namespace API keys|
|Dependency confusion in ETL|Supply chain attack|Private package repos, lockfiles, integrity verification, build-time SBOM and scan|

  

6. Mitigation matrix summary

  

|   |   |   |
|---|---|---|
|Area|Primary controls|Secondary controls|
|Edge and API|WAF managed rules, Shield Adv, throttling, strict CORS|Canary tokens, deception endpoints|
|Storage integrity|S3 versioning, Object Lock, MFA delete|E2E hashes, Glacier vault lock|
|Identity|SSO + MFA, least privilege, ABAC and boundaries|Access analyzer, automatic key re-issue on anomaly|
|Network|Private subnets, SG default deny, VPC endpoints|NACL parity checks, egress deny with VPC Lattice when used|
|Vector DB|mTLS, private admin plane, rate limits|Query-time governance layer|
|Secrets and keys|KMS per data tier, Secrets Manager rotation|Break-glass workflows with timeboxed roles|
|Observability|Org CloudTrail, CW metrics and alarms, Security Hub|Detective investigations, routine hunt queries|
|Supply chain|Signed images, SLSA L3 pipeline, SBOM|Periodic rebuild from source, provenance audits|

  

7. Residual risks and acceptance

  

  

- Short spikes may still cause query latency in Weaviate under extreme scans. Accepted with autoscale and SLOs.
- Third-party library zero-days can bypass scans. Residual exposure reduced via weekly rebuilds and pinned SHAs.
- Insider risk cannot be fully eliminated. Reduced with SoD, JIT access, and session recording.

  

  

  

8. Control mapping

  

  

- CIS AWS Foundations 1.5: 1.1, 1.2, 3.1, 3.4, 3.10, 4.1, 4.3, 5.1, 5.2, 5.3
- NIST 800-53 Rev5: AC-2, AC-3, AU-2, AU-9, CM-5, IA-2, MP-6, PE-19, SC-7, SC-12, SC-13, SC-28, SI-4
- ISO 27001: A.5.15, A.8.16, A.8.23, A.8.28, A.8.32, A.8.33, A.8.34

  

  

  

9. Diagrams

  

flowchart LR

  Client((Client)) -->|HTTPS| CF[CloudFront + WAF]

  CF --> APIGW[API Gateway]

  APIGW -->|VPC Link| ENI[Private ENIs]

  ENI --> LBD[Lambda ETL]

  LBD --> SQS[SQS Queue]

  SQS --> FARG[ECS Fargate Workers]

  FARG <--> WEAV[Weaviate (private)]

  LBD --> S3RAW[S3 raw]

  FARG --> S3CUR[S3 curated]

  WEAV --> S3BK[S3 snapshots]

  subgraph VPC Private

    ENI

    LBD

    SQS

    FARG

    WEAV

  end

flowchart TB

  subgraph Identity

    COG[Cognito]

    IAM[IAM Roles + STS]

    KMS[KMS CMKs]

    SECR[Secrets Manager]

  end

  COG --> APIGW

  IAM --> LBD

  IAM --> FARG

  KMS --> S3RAW

  KMS --> S3CUR

  SECR --> LBD

  SECR --> FARG

  

10. Logging and forensics

  

  

- Organization CloudTrail with data events for S3, Lambda, DynamoDB, KMS.
- S3 access logs and WAF logs centralized to a dedicated log account.
- Retention: 400 days hot, 7 years cold with Glacier Vault Lock.
- Forensic pack: playbooks for snapshot, log capture, IAM access freeze, tag-and-segregate in Security Hub.

  

  

  

11. Validation and testing

  

  

- Pre-prod chaos tests: API rate limits, DLQ redrive, Weaviate scan storm.
- Red team cases: prompt injection, schema tamper, PassRole abuse, KMS deny, secret exfil via mis-tagged role.
- Controls as code: AWS Config rules, cfn-nag, tfsec, prowler in CI.
- Quarterly tabletop exercise: key compromise, public bucket drift, runaway cost attack.

  

## Acceptance Criteria

- STRIDE threats and mitigations are documented for API edge, ingest/ETL, vector store, identity and keys, and CI/CD flows, and reviewed with Security and Platform.
- Primary mitigations from this document (WAF rules, Shield, S3 Object Lock, KMS policies, IAM boundaries, supply-chain controls) are implemented via IaC in the workload and security accounts.
- Organization-wide CloudTrail, WAF/S3 access logs, GuardDuty, Config, Detective, and Security Hub are enabled with the retention and centralization model described in sections 6 and 10.
- LLM-specific abuse cases (prompt injection, data poisoning, over-embedding, dependency confusion) have corresponding tests or guardrails wired into ingest/normalize/embed stages.
- Residual risks in section 7 are explicitly accepted in the risk register and revisited at least annually.
- Chaos experiments and tabletop exercises described in section 11 run at least once per year with issues tracked to closure.

  

12. Assumptions

  

  

- All workloads run in private subnets.
- No public admin plane for Weaviate.
- Cross-account architecture in place: prod, staging, security, log archive.

  

  

  

13. Open items and owners

  

  

- Decide EKS vs ECS for Weaviate. Default ECS Fargate unless custom operators are required.
- Enable Shield Advanced on production CloudFront distributions.
- Approve ABAC tag schema: env, app, data_tier, tenant.

  

  

  

  

Status: Approved for implementation.

Next documents: SEC-002 IAM Policy and Trust Relationship Map, SEC-003 Network Policy and Segmentation, SEC-004 Secrets and KMS Rotation Playbook.