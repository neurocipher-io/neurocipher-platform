  

AWS-Adapter-001 — Production Specification

  

  

  

1. Purpose

  

  

Implement the SEG-001 Security Engine ports for AWS. The adapter discovers AWS assets, normalizes configs, evaluates controls via core, generates evidence, plans and applies remediations, and produces signed attestations. All AWS logic is contained here. Core remains cloud-neutral.

  

  

2. Scope

  

  

Multi-account, multi-region AWS organizations. Read-only evaluation, dry-run planning, and controlled apply with approvals. Includes identity, networking, data paths, observability, SLOs, CI/CD, security, rollout, DR, and runbooks.

  

Out of scope: UI, billing, pricing, non-AWS providers.

  

  

3. References

  

  

- REF-001 Documentation Standard
- SEG-001 Security Engine
- SRG-001 Schema Registry
- SEC-002 IAM Policy Map, SEC-003 Network Policy, SEC-004 KMS Rotation
- OBS-001..003 Observability
- CI-001..003 CI/CD
- ADR-0xx Ports/Adapters decision

  

  

  

4. Architecture

  

  

  

4.1 Components

  

  

- Assumer: STS role-assumption service for target accounts.
- Inventory Worker: lists assets and fetches point-in-time configs.
- Evidence Writer: writes evidence blobs to S3 with KMS.
- Remediation Planner/Executor: plans and applies change sets.
- Attestation Signer: signs with KMS asymmetric keys.
- Adapter API: internal gRPC/HTTP for core <-> adapter calls.
- Tool Host (optional): Bedrock AgentCore runtime for long-running tool flows inside AWS adapter only.

  

  

  

4.2 Data flow

  

  

1. Core invokes adapter port.
2. Adapter assumes target account role via STS.
3. Inventory pulls resources from AWS services, normalizes to Asset + ConfigDoc.
4. Core evaluates policies. Adapter enriches evidence and writes to S3.
5. For remediation, adapter computes plan, obtains approvals, applies via service APIs or SSM Change Manager.
6. Attestation signed and published.

  

  

  

4.3 Deployment topologies

  

  

- Org-centralized (recommended): adapter runs in a Management or Security account. Cross-account read/apply via AssumeRole.
- Per-business-unit: adapters per OU with identical config.

  

  

  

5. Identity and Access

  

  

  

5.1 Roles

  

  

- AdapterExecutionRole (home account): permissions for STS:AssumeRole, KMS sign/encrypt, S3 evidence bucket, EventBridge, CloudWatch, Bedrock AgentCore invoke (if used), DynamoDB token cache (optional).
- TargetReadRole (per target account): read-only inventory permissions.
- TargetApplyRole (optional, per target account): scoped write for remediation.

  

  

  

5.2 Trust relationships

  

  

- TargetReadRole and TargetApplyRole trust AdapterExecutionRole principal only. External IDs enforced. Session duration ≤ 1h. Session tags include tenant, run_id.

  

  

  

5.3 Credential hygiene

  

  

- No long-lived keys. STS only. Role ARNs stored in encrypted config. Session policies reduce scope per run.

  

  

  

6. Networking

  

  

- VPC-only egress. NAT to AWS services via VPC Endpoints (S3, STS, KMS, CloudWatch, EventBridge, Config, EC2, IAM, Resource Explorer, CloudTrail, Security Hub, SSM, Lambda, Bedrock if used).
- Security groups: egress-only to endpoints and private DNS. Ingress via private NLB + internal ALB if HTTP API used.
- No public subnets. PrivateLink for cross-account API if multi-adapter.

  

  

  

7. Storage and Data

  

  

- Evidence bucket: s3://neurocipher-seg-evidence-{env}-{region}.  
    

- KMS CMK per env. Bucket keys disabled. Object lock optional. S3 Access Points per tenant.

-   
    
- Iceberg tables (in core data plane) referenced by adapter for run metadata if needed; adapter writes only evidence blobs and small index entries when required.
- Attestation store: S3 prefix attestations/ + optional transparency log topic.

  

  

  

8. Port Implementations

  

  

  

8.1 InventoryPort

  

  

  

list_assets(scope, kinds, since) -> Asset[]

  

  

- Sources  
    

- AWS Resource Explorer v2 for fast enumeration.
- Fallbacks: AWS Config ListDiscoveredResources, service-specific paginators for gaps.

-   
    
- Coverage  
    

- vm → EC2 instances
- bucket → S3 buckets
- db → RDS, Aurora
- identity → IAM users, roles, policies
- key → KMS keys
- network → VPC, Subnets, SGs, NACLs
- lb → ELBv2
- ecr, lambda, eks, sqs, sns, cloudtrail, config, guardduty, securityhub, etc.

-   
    
- Normalization  
    

- Asset.ref.urn: urn:asset:aws:{type}:{account}:{region}:{id}
- Asset.kind: canonical kind
- properties: minimal identifiers (ARNs, names)

-   
    
- Pagination  
    

- Stable cursor: next_token with provider markers cached in DynamoDB if needed.

-   
    

  

  

  

get_config(ref, at) -> ConfigDoc

  

  

- Point-in-time  
    

- Prefer AWS Config GetResourceConfigHistory nearest to at.
- If Config disabled for type, use direct Describe* with captured_at=now.

-   
    
- Body  
    

- Provider-normalized JSON. Keep raw keys. Do not redact in body; do not log.

-   
    

  

  

  

search(query) -> Asset[]

  

  

- Query over Resource Explorer or cached index. Strict filters only.

  

  

Error handling

  

- Missing permissions → SEG_ADAPTER_UNAVAILABLE.
- Throttling → backoff with jitter. Max 8 retries per call.

  

  

  

8.2 EvaluationPort

  

  

  

evaluate(request) -> EvalResult

  

  

- Pull configs for targeted assets.
- Call core OPA evaluator with ControlSpec bundle IDs.
- Collect evidence stubs from decision metadata.

  

  

  

validate_control(control) -> ValidationReport

  

  

- Load bundle from SRG-001. Lint inputs schema. Run vector tests using canned fixtures.

  

  

Performance

  

- Batch configs per control. Parallel by asset kind. Target p95 eval ≤ 300 ms + I/O.

  

  

  

8.3 RemediationPort

  

  

  

plan(finding, mode) -> RemediationPlan

  

  

- Map control → service API changes.
- Compute blast radius and preconditions.
- If mode=plan, output steps with diffs and estimated risk.

  

  

  

apply(plan, change_window) -> ApplyResult

  

  

- Dry-run first where API supports it (e.g., IAM policy simulator, Route53 changesets).
- Execute via service API or SSM Change Manager for guardrails.
- Idempotency key = plan.id.
- Record provider change IDs and messages.

  

  

  

rollback(plan_id) -> RollbackResult

  

  

- Inverse steps if feasible. Otherwise doc manual rollback with evidence.

  

  

High-value remediations

  

- S3: PutPublicAccessBlock, Block public ACLs/policies.
- IAM: detach wildcard policies, enforce SCPs via Org if in scope.
- KMS: enable key rotation, adjust key policies.
- EC2: restrict SG ingress 0.0.0.0/0 for sensitive ports.
- CloudTrail: enable org trails, S3 encryption, log file validation.
- Config: enable recorders + delivery channel.
- GuardDuty/Security Hub: enable across org.

  

  

  

8.4 FindingIngestPort

  

  

  

commit(findings, evidence) -> AppendResult

  

  

- Write evidence bodies to S3 using content-addressed keys:  
    evidence/{sha256[0:2]}/{sha256}.bin
- Write evidence manifest: JSON pointer with media type, size, hash.
- Emit seg.findings.committed EventBridge event with stable key.

  

  

  

ack(run_id) -> Ack

  

  

- Confirm persistence and watermark metrics.

  

  

  

8.5 AttestationPort

  

  

  

sign(run, scope) -> Attestation

  

  

- Build DSSE envelope over RunSummary.
- Sign with KMS asymmetric key (ECC_SECG_P256K1 or RSA_4096 as policy).
- Store signature and publish to S3.

  

  

  

verify(attestation) -> VerifyReport

  

  

- Verify KMS signature and payload hash.

  

  

  

publish(attestation, targets) -> PublishReport

  

  

- S3 write and optional SNS topic publish.

  

  

  

9. Evidence Model

  

  

- Media types: application/json, text/plain, application/yaml, application/octet-stream.
- Chunking: > 8 MiB chunk; store chunks/*.part + manifest.json.
- PII policy: redaction filter before commit; store redaction log.

  

  

  

10. Observability

  

  

- Tracing: OpenTelemetry spans around each AWS API call. Attributes: tenant, run_id, account_id, region, service, operation, asset_kind, control_id.
- Metrics  
    

- aws_adapter_api_throttle_total{service,operation}
- aws_adapter_inv_latency_ms{port,operation} histogram
- aws_adapter_findings_total{severity,control_id}
- aws_adapter_apply_success_ratio
- aws_adapter_error_total{error_code}

-   
    
- Logs: JSON only. No secrets. Evidence hashes only.

  

  

  

11. Security Controls

  

  

- KMS  
    

- Keys: alias/seg-evidence, alias/seg-attestation.
- Rotation: annual. Key policy restricts to AdapterExecutionRole.

-   
    
- S3  
    

- Bucket policy denies unencrypted uploads and public access.
- Object ownership enforced. Block public ACLs.

-   
    
- IAM  
    

- Least-privilege policies per operation.
- Session policies reduce scope to account/region/asset kinds.

-   
    
- Network  
    

- No internet egress. VPC endpoints only.

-   
    
- Supply chain  
    

- Signed OCI images. SBOM published. SLSA-3 provenance.

-   
    

  

  

  

12. Performance Targets (Adapter slice)

  

  

- Inventory p95:  
    

- 10k assets across 20 accounts, 6 regions ≤ 10 min full sweep.

-   
    
- Config fetch p95: ≤ 400 ms per asset when AWS Config has history, ≤ 1200 ms direct.
- Remediation apply p95: step ≤ 2 s for control-plane operations.

  

  

  

13. Error Model

  

  

Standard:

{

  "error_code": "AWS_RATE_LIMIT",

  "message": "Throttled by AWS API",

  "retryable": true,

  "details": {"service":"ec2","operation":"DescribeInstances"}

}

Common:

  

- AWS_ACCESS_DENIED
- AWS_RATE_LIMIT
- AWS_SERVICE_UNAVAILABLE
- AWS_CONFIG_DISABLED
- AWS_CHANGE_PRECONDITION_FAILED
- AWS_SSM_CHANGE_REJECTED
- AWS_KMS_SIGN_FAILED

  

  

Retry policy: exponential backoff 200–3200 ms, jitter, max 8 attempts. Circuit-breaker per service.

  

  

14. CI/CD

  

  

- Build: containerize adapter. Run unit + integration tests against LocalStack where possible and real AWS in sandbox for gap coverage.
- Security gates: Trivy scan, license check, SBOM diff, IaC drift check, OPA policy test vectors.
- Deploy: GitOps (ArgoCD) or CDK/Terraform. Blue/green rollout with health probes.
- Config: versioned adapter.yaml stored in SRG-001-managed registry with ARNs, OUs, regions, features.

  

  

  

15. Rollout

  

  

- Phase 0: read-only in one sandbox account.
- Phase 1: org-wide read-only via TargetReadRole.
- Phase 2: remediation plan only in staging accounts.
- Phase 3: controlled apply with SSM Change Manager approvals.

  

  

  

16. DR and Resilience

  

  

- Stateless services: redeployable from container registry.
- Evidence replicas: S3 CRR to secondary region.
- KMS keys: multi-Region or per-region with documented failover.
- Run resumption: idempotent checkpoints. Re-assess pending plans on restart.

  

  

  

17. Compliance Hooks

  

  

- Attestations: DSSE + KMS signature, stored immutably.
- Change records: link to SSM Change Manager and CloudTrail events.
- Audit export: CSV/Parquet export of findings and plans per tenant.

  

  

  

18. Testing Strategy

  

  

- Unit: 90% coverage for mappers and paginators.
- Adapter conformance: run SEG-001 conformance suite.
- Integration: sandbox AWS with seeded fixtures (1000 assets).
- Soak: 24-hour run across 5 regions, throttle/timeout injection.
- Security: IAM authz matrix, KMS sign/verify, S3 policy deny simulations.
- Chaos: kill pods, break endpoints, simulate STS failures.

  

  

  

19. Acceptance Criteria

  

  

- Inventory covers baseline kinds across EC2, S3, IAM, VPC, RDS, EKS, Lambda, CloudTrail, Config, KMS, Security Hub, GuardDuty.
- Evidence written to S3 with correct hashes and KMS encryption.
- At least 20 remediations plan correctly and 10 apply successfully in staging with rollback verified.
- Attestations sign/verify/publish end-to-end.
- OpenTelemetry traces and dashboards live.
- SLOs green for two weeks in staging.
- Org-wide read-only completed across ≥ 10 accounts.

  

  

  

20. IAM Policy Sketches

  

  

  

20.1 AdapterExecutionRole (home)

  

  

Minimum excerpt. Expand per service as needed.

{

  "Version":"2012-10-17",

  "Statement":[

    {"Effect":"Allow","Action":["sts:AssumeRole"],"Resource":"arn:aws:iam::*:role/Neurocipher/SEG/*"},

    {"Effect":"Allow","Action":["kms:Sign","kms:GetPublicKey","kms:DescribeKey"],"Resource":"arn:aws:kms:REGION:HOME:key/ATT_KEY_ID"},

    {"Effect":"Allow","Action":["s3:PutObject","s3:PutObjectTagging","s3:GetObject","s3:ListBucket"],"Resource":["arn:aws:s3:::neurocipher-seg-evidence-*","arn:aws:s3:::neurocipher-seg-evidence-*/*"]},

    {"Effect":"Allow","Action":["bedrock:InvokeAgent","bedrock:InvokeModel"],"Resource":"*","Condition":{"Bool":{"aws:ViaAWSService":"true"}}}

  ]

}

  

20.2 TargetReadRole (target)

  

{

  "Version":"2012-10-17",

  "Statement":[

    {"Sid":"Inventory","Effect":"Allow","Action":[

      "resource-explorer-2:List*", "resource-explorer-2:Search",

      "config:ListDiscoveredResources","config:GetResourceConfigHistory",

      "ec2:Describe*","s3:ListAllMyBuckets","s3:GetBucketPolicy","s3:GetBucketPublicAccessBlock",

      "iam:List*","iam:Get*","rds:Describe*","eks:ListClusters","eks:DescribeCluster",

      "cloudtrail:DescribeTrails","cloudtrail:GetEventSelectors","kms:DescribeKey","kms:GetKeyPolicy",

      "elasticloadbalancing:Describe*","ssm:Get*","securityhub:Describe*","guardduty:List*","guardduty:Get*"

    ],"Resource":"*"}

  ]

}

  

20.3 TargetApplyRole (target)

  

  

Scoped to explicit actions used in approved remediations. Example:

{

  "Version":"2012-10-17",

  "Statement":[

    {"Effect":"Allow","Action":[

      "s3:PutPublicAccessBlock","s3:DeleteBucketPolicy","s3:PutBucketPolicy",

      "ec2:RevokeSecurityGroupIngress","ec2:AuthorizeSecurityGroupIngress",

      "iam:DetachRolePolicy","iam:PutRolePolicy","config:PutConfigurationRecorder","config:PutDeliveryChannel",

      "cloudtrail:UpdateTrail","cloudtrail:PutEventSelectors","kms:EnableKeyRotation","kms:PutKeyPolicy"

    ],"Resource":"*"},

    {"Effect":"Allow","Action":["ssm:StartChangeRequestExecution","ssm:ListChangeRequests"],"Resource":"*"}

  ]

}

  

21. Configuration

  

  

adapter.yaml (per env):

org_id: "o-xxxxxxxxxx"

home_account: "111111111111"

assume_role_name_read: "Neurocipher/SEG/ReadRole"

assume_role_name_apply: "Neurocipher/SEG/ApplyRole"

regions: ["us-east-1","us-west-2","ca-central-1"]

features:

  remediation_apply: false

  use_agentcore_tools: true

evidence_bucket: "neurocipher-seg-evidence-prod-ca-central-1"

kms_keys:

  evidence: "arn:aws:kms:ca-central-1:111111111111:key/..."

  attestation: "arn:aws:kms:ca-central-1:111111111111:key/..."

limits:

  max_parallel_accounts: 5

  max_parallel_regions: 4

  

22. Adapter API (internal)

  

  

gRPC outline:

service AwsAdapter {

  rpc ListAssets(ListAssetsRequest) returns (ListAssetsResponse);

  rpc GetConfig(GetConfigRequest) returns (ConfigDoc);

  rpc Evaluate(EvalRequest) returns (EvalResult);

  rpc Plan(PlanRequest) returns (RemediationPlan);

  rpc Apply(ApplyRequest) returns (ApplyResult);

  rpc Commit(CommitRequest) returns (AppendResult);

  rpc Sign(SignRequest) returns (Attestation);

  rpc Verify(VerifyRequest) returns (VerifyReport);

  rpc Publish(PublishRequest) returns (PublishReport);

}

  

23. Bedrock AgentCore Usage (optional)

  

  

- When: long-running, tool-rich remediations or evidence gathering (e.g., fleet SSM audits, complex IAM graph analysis).
- How: host agent tools inside AgentCore; adapter invokes them.
- Isolation: no Bedrock references in core. Only in AWS-Adapter-001.

  

  

  

24. Runbooks

  

  

  

24.1 Onboard an account

  

  

1. Create TargetReadRole and optional TargetApplyRole.
2. Add trust to home AdapterExecutionRole with ExternalId.
3. Tag account with seg:onboarded=true.
4. Run discovery smoke test: list 10 assets per region.
5. Enable Config recorder if disabled (plan only).

  

  

  

24.2 Rotate KMS keys

  

  

1. Create new CMK.
2. Update adapter.yaml.
3. Re-encrypt new evidence only. Old objects readable by old key until retirement.

  

  

  

24.3 Respond to 

AWS_ACCESS_DENIED

  

  

- Validate trust policy and session policy size.
- Re-assess SCPs blocking reads.
- Re-run smoke test.

  

  

  

24.4 High throttling

  

  

- Increase jitter and reduce parallelism for affected service.
- Request quota increase if sustained.

  

  

  

25. DR Drill

  

  

- Simulate region loss for evidence bucket.
- Verify CRR failover read in secondary.
- Re-run attestation signing in secondary KMS.

  

  

  

26. Cost Profile (guidance)

  

  

- Inventory: pennies per 10k API calls.
- S3 evidence: dominant cost. Expect 1–5 KiB per finding; larger for policy diffs.
- KMS: sign + encrypt per run and evidence batch.
- AgentCore: per-invoke for optional tools.

  

  

  

27. Acceptance Checklist

  

  

- Org-wide read-only inventory across selected regions.
- Evidence in S3 with KMS, content-addressed.
- 20+ controls evaluate with findings and evidence.
- 10 remediations plan and 5 apply in staging with rollback.
- Attestations signed and verified.
- OpenTelemetry dashboards green against SLOs.
- Runbooks executed in staging.
- CI/CD gates passed, SBOM stored, images signed.

  

  

Status: Ready for production implementation.