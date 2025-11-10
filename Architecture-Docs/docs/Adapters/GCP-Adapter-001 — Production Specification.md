  

GCP-Adapter-001 — Production Specification

  

  

  

1. Purpose

  

  

Implement SEG-001 ports for Google Cloud. The adapter enumerates assets, normalizes configs, evaluates controls via core, generates evidence, plans and applies remediations, and produces signed attestations. All GCP logic stays in the adapter. Core stays cloud-neutral.

  

  

2. Scope

  

  

Single and multi-project estates across Organization, Folders, and Projects. Read-only evaluation, dry-run planning, controlled apply with approvals. Includes identity, networking, data paths, observability, SLOs, CI/CD, security, rollout, DR, runbooks.

  

Out of scope: UI, billing, non-GCP providers.

  

  

3. References

  

  

- REF-001 Documentation Standard
- SEG-001 Security Engine
- SRG-001 Schema Registry
- SEC-002/003/004 (IAM map, network policy, KMS rotation)
- OBS-001..003 Observability
- CI-001..003 CI/CD
- ADR-0xx Ports/Adapters decision

  

  

  

4. Architecture

  

  

  

4.1 Components

  

  

- Identity Broker: Workload Identity Federation (WIF) to obtain short-lived Google identity; optional SA keyless auth.
- Inventory Worker: uses Cloud Asset Inventory (CAI) and per-service APIs.
- Evidence Writer: writes blobs to Cloud Storage with CMEK.
- Remediation Planner/Executor: produces and applies changes via org-policy, IAM, and service APIs.
- Attestation Signer: signs envelopes with Cloud KMS asymmetric keys.
- Adapter API: internal gRPC/HTTP for core↔adapter.
- Tool Host (optional): long-running flows on Cloud Run or Cloud Functions, invoked only by the adapter.

  

  

  

4.2 Data flow

  

  

1. Core calls adapter port.
2. Adapter authenticates via WIF → Service Account (SA).
3. Inventory queries CAI and service APIs → Asset, ConfigDoc.
4. Core evaluates controls. Adapter writes evidence and emits events.
5. Planner computes diffs. Executor applies changes with guardrails.
6. Attestation signed and published.

  

  

  

4.3 Deployment topologies

  

  

- Org-centralized (recommended): adapter runs in a Security project. Cross-project access via org-level roles and per-project bindings.
- Per-folder: one adapter per folder with delegated roles.

  

  

  

5. Identity and Access

  

  

  

5.1 Principals and roles

  

  

- Adapter Workload Identity Pool/Provider: trusts your CI/CD or runtime identity.
- Adapter Service Account (SA) in Security project:  
    

- Read path: roles/cloudasset.viewer, roles/compute.networkViewer, roles/iam.securityReviewer, roles/secretmanager.viewer, roles/storage.viewer, roles/cloudkms.viewer, roles/logging.viewer, roles/securitycenter.findingsViewer at org/folder/project scopes as needed.
- Apply path (custom role RemediationOperator): limited resourcemanager, iam, storage, compute, logging, orgpolicy.policyAdmin, securitycenter.adminViewer where required.
- KMS CryptoKey Signer/Verifier on attestation key.

-   
    
- Prefer IAM Conditions to scope resources and time windows.

  

  

  

5.2 Workload Identity Federation

  

  

- OIDC or AWS/Azure pool → provider → SA impersonation.
- No SA keys. Access tokens ≤ 1h.
- Session attributes must include tenant, run_id, scope.

  

  

  

5.3 Cross-org (optional)

  

  

- Use VPC-SC and project perimeters if data exfiltration constraints apply. Configure Private Google Access and tighten egress.

  

  

  

6. Networking

  

  

- No public ingress. Internal LB if API exposure is required.
- Private Google Access enabled in subnets.
- Serverless VPC Access for Cloud Run/Functions if used.
- VPC-SC perimeters optional for restricted services (Storage, KMS, CAI, SCC).
- Egress restricted via firewall + Cloud NAT to Google APIs only.

  

  

  

7. Storage and Data

  

  

- Evidence: Cloud Storage bucket gs://neurocipher-seg-evidence-{env}  
    

- CMEK: Cloud KMS key per env.
- Uniform Bucket-Level Access. Public Access Prevention enforced.
- Versioning on. Object hold optional.
- Naming: evidence/{sha256[0:2]}/{sha256}.bin

-   
    
- Attestations: prefix attestations/ in same bucket.
- Index (optional): Firestore/Datastore or Spanner table for cursors.
- Canonical analytical tables live in core (Iceberg). Adapter writes only evidence and minimal indexes.

  

  

  

8. Port Implementations

  

  

  

8.1 InventoryPort

  

  

  

list_assets(scope, kinds, since) -> Asset[]

  

  

- Primary: Cloud Asset Inventory assets.searchAllResources and assets.list at org/folder/project.
- Coverage (canonical → GCP)  
    

- vm → compute.googleapis.com/Instance
- bucket → storage.googleapis.com/Bucket
- db → sqladmin.googleapis.com/Instance, spanner.googleapis.com/Instance, bigquery.googleapis.com/Dataset
- identity → iam.googleapis.com/ServiceAccount, iam.googleapis.com/Role, bindings via getIamPolicy
- key → cloudkms.googleapis.com/CryptoKey
- network → VPC, Subnet, Firewall, Router, External IP
- lb → compute.googleapis.com/ForwardingRule, Target*
- functions, run.service, pubsub.topic, storage.object, logging.logSink, orgpolicy.policy, securitycenter.finding (as signals)

-   
    
- Normalization  
    

- Asset.ref.urn: urn:asset:gcp:{type}:{project}:{location}:{resourceId}
- Asset.kind: canonical map.
- properties: resource name, project number, URIs.

-   
    
- Pagination: CAI page tokens. Stable cursors per scope.
- Since: CAI temporal search when available or filter by updateTime.

  

  

  

get_config(ref, at) -> ConfigDoc

  

  

- Point-in-time:  
    

- Prefer CAI time-select if enabled.
- Else call service GET and set captured_at=now.

-   
    
- Body: provider-normalized JSON, keep full resource fields. Do not log bodies.

  

  

  

search(query) -> Asset[]

  

  

- CAI search with strict field allowlist.

  

  

Errors

  

- Missing permission → GCP_PERMISSION_DENIED.
- CAI latency/timeouts → backoff + jitter.
- Perimeter block → GCP_VPCSC_DENY.

  

  

  

8.2 EvaluationPort

  

  

  

evaluate(request) -> EvalResult

  

  

- Batch fetch configs via per-service REST where faster than CAI.
- Invoke core OPA with ControlSpec bundle ids.
- Emit evidence stubs.

  

  

  

validate_control(control) -> ValidationReport

  

  

- Load bundle from SRG-001. Validate schema. Execute vector tests with canned fixtures.

  

  

Performance

  

- Batch by project and resource type. Target p95 eval ≤ 300 ms + I/O.

  

  

  

8.3 RemediationPort

  

  

  

plan(finding, mode) -> RemediationPlan

  

  

- Derive change set:  
    

- IAM bindings change plans (remove allUsers/allAuthenticatedUsers, restrict roles).
- Org Policy constraints (e.g., constraints/storage.publicAccessPrevention, constraints/compute.requireOsLogin).
- Service configs: Firewall rule tightening, Audit Logs enablement, SCC onboarding, KMS rotation, Log Sink hardening.

-   
    
- Compute blast radius. Validate preconditions (locks, org policy conflicts).

  

  

  

apply(plan, change_window) -> ApplyResult

  

  

- Paths:  
    

1. IAM: setIamPolicy with ETags and conditional bindings.
2. Org Policy: projects|folders|organizations.policies.patch with dry-run (spec.dryRunSpec) where supported.
3. Service: REST calls to compute.firewalls.patch, storage.buckets.patch (UBLA, PAP), logging.sinks.update, cloudkms.cryptoKeyVersions.patch, securitycenter settings.
4. Infra as Code (optional for bulk): Terraform runner in tool host; outputs attached as evidence.

-   
    
- Guardrails:  
    

1. Idempotency via plan.id labels on changes.
2. Pre-flight checks and minimal-scope mutations.
3. Approval via change window and IAM Condition request.time in custom role if required.

-   
    
- Rollback:  
    

1. Reapply saved prior bindings/configs captured in evidence snapshot.
2. Reverse org policy to prior spec if safe.

-   
    

  

  

High-value remediations (examples)

  

- Storage: enable Public Access Prevention, enforce UBLA, remove public IAM bindings, enforce CMEK.
- Compute: remove 0.0.0.0/0 ingress on common ports; require Shielded VM; block external IPs on sensitive projects.
- IAM: remove primitive role grants at project level; enforce least privilege; deny SA key creation by policy.
- Logging: enable Data Access audit logs for key services; sink to dedicated project with CMEK.
- SCC: enable SCC and detectors at org; onboard projects.
- KMS: enable rotation; restrict key IAM; enforce CMEK on services via policy.

  

  

  

8.4 FindingIngestPort

  

  

  

commit(findings, evidence) -> AppendResult

  

  

- Write evidence blobs to GCS with content-addressed names.
- Write manifest JSON (mediaType, size, sha256).
- Emit seg.findings.committed via Pub/Sub or Eventarc with idempotency key.

  

  

  

ack(run_id) -> Ack

  

  

- Confirm persistence and watermark.

  

  

  

8.5 AttestationPort

  

  

  

sign(run, scope) -> Attestation

  

  

- DSSE envelope over RunSummary.
- Sign with Cloud KMS asymmetric key (RSA-4096 or EC P-256).
- Store envelope and signature in GCS.

  

  

  

verify(attestation) -> VerifyReport

  

  

- Verify KMS signature and payload hash.

  

  

  

publish(attestation, targets) -> PublishReport

  

  

- GCS write. Optional Pub/Sub publish.

  

  

  

9. Evidence Model

  

  

- Media types: application/json, text/plain, application/yaml, application/octet-stream.
- Chunk > 8 MiB into chunks/*.part + manifest.json.
- Redaction filter runs pre-commit; store redaction log.

  

  

  

10. Observability

  

  

- Tracing: OpenTelemetry. Export via OTLP to Cloud Trace or third-party.  
    

- Span attrs: tenant, run_id, project, location, service, operation, asset_kind, control_id.

-   
    
- Metrics (Cloud Monitoring):  
    

- gcp_adapter_api_throttle_total{service,operation}
- gcp_adapter_inv_latency_ms{port,operation} histogram
- gcp_adapter_findings_total{severity,control_id}
- gcp_adapter_apply_success_ratio
- gcp_adapter_error_total{error_code}

-   
    
- Logs: JSON. No secrets. Evidence hashes only.

  

  

  

11. Security Controls

  

  

- Cloud KMS:  
    

- Keys: seg-evidence-cmek, seg-attestation.
- Rotation annually. IAM restricted to Adapter SA.

-   
    
- Cloud Storage:  
    

- PAP enforced. UBLA. Versioning. Retention policy optional.
- Bucket Policy Only; deny public access.

-   
    
- IAM:  
    

- Least privilege. IAM Conditions to scope to folders/projects and time windows.

-   
    
- Network:  
    

- Private Google Access. VPC-SC optional.

-   
    
- Supply chain:  
    

- Signed OCI, SBOM, provenance (SLSA-3 target).

-   
    

  

  

  

12. Performance Targets (Adapter slice)

  

  

- Inventory p95: 10k assets across 20 projects and 6 regions ≤ 12 min full sweep.
- Config fetch p95: ≤ 500 ms via CAI; ≤ 1200 ms direct service GET.
- Remediation apply p95: step ≤ 3 s for control-plane operations.

  

  

  

13. Error Model

  

  

Standard:

{

  "error_code": "GCP_RATE_LIMIT",

  "message": "Throttled by Google API",

  "retryable": true,

  "details": {"service":"compute","operation":"firewalls.patch"}

}

Common:

  

- GCP_PERMISSION_DENIED
- GCP_RATE_LIMIT
- GCP_SERVICE_UNAVAILABLE
- GCP_VPCSC_DENY
- GCP_CAI_TIMEOUT
- GCP_KMS_SIGN_FAILED
- GCP_ORGPOLICY_CONFLICT

  

  

Retry: exponential backoff 200–3200 ms with jitter. Per-service circuit breakers.

  

  

14. CI/CD

  

  

- Build: containerize adapter. Unit + integration tests with gcloud beta emulators where possible; live sandbox for gaps.
- Security gates: Trivy, license check, SBOM diff, IaC drift, OPA vector tests.
- Deploy: Cloud Build + Terraform or GitHub Actions. Blue/green on Cloud Run or GKE.
- Config: versioned adapter.yaml in registry with org/folder/projects, regions, features.

  

  

  

15. Rollout

  

  

- Phase 0: read-only in one project.
- Phase 1: read-only across target folder/org.
- Phase 2: remediation plan in staging projects.
- Phase 3: controlled apply with approval and change windows.

  

  

  

16. DR and Resilience

  

  

- Stateless services. Redeployable from container registry.
- Evidence bucket with dual-region or turbo replication.
- KMS key import to dual-region or backup key with key version policy.
- Idempotent checkpoints to resume runs.

  

  

  

17. Compliance Hooks

  

  

- Attestations: DSSE + KMS signature, immutable retention policy.
- Change records: link to Audit Logs, Org Policy changes, IAM policy delta, and operation IDs.
- Audit export: CSV/Parquet export per tenant/folder/project.

  

  

  

18. Testing Strategy

  

  

- Unit: ≥90% on mappers and paginators.
- Adapter conformance: SEG-001 suite.
- Integration: seeded sandbox with 1000+ resources.
- Soak: 24-hour run across 5 regions with throttle/timeout injection.
- Security: IAM condition tests, KMS sign/verify, Storage PAP enforcement.
- Chaos: kill pods, break Serverless VPC Access, simulate VPC-SC denies.

  

  

  

19. Acceptance Criteria

  

  

- Inventory covers baseline kinds across Compute, Storage, Network, SQL/Spanner/BigQuery, Cloud Run/Functions, IAM, Org Policy, SCC.
- Evidence stored in GCS with CMEK and correct hashes.
- ≥20 controls evaluate with findings and evidence.
- ≥10 remediations plan and ≥5 apply in staging with rollback verified.
- Attestations sign/verify/publish end-to-end.
- OpenTelemetry dashboards live; SLOs green two weeks.
- Runbooks executed in staging.
- CI/CD gates pass; images signed; SBOM stored.

  

  

  

20. Role Definitions (sketches)

  

  

  

20.1 RemediationOperator (custom)

  

  

Minimum excerpt. Expand per use case.

title: RemediationOperator

includedPermissions:

  - resourcemanager.projects.get

  - resourcemanager.projects.getIamPolicy

  - resourcemanager.projects.setIamPolicy

  - iam.serviceAccounts.get

  - iam.serviceAccounts.list

  - iam.roles.get

  - storage.buckets.get

  - storage.buckets.update

  - storage.buckets.setIamPolicy

  - compute.firewalls.get

  - compute.firewalls.update

  - orgpolicy.policies.get

  - orgpolicy.policies.update

  - logging.sinks.get

  - logging.sinks.update

  - securitycenter.settings.update

  - cloudkms.cryptoKeyVersions.get

  - cloudkms.cryptoKeys.get

  - cloudkms.cryptoKeys.update

stage: GA

  

20.2 ReaderPlusSecurityMeta (custom)

  

title: ReaderPlusSecurityMeta

includedPermissions:

  - cloudasset.assets.searchAllResources

  - cloudasset.assets.searchAllIamPolicies

  - securitycenter.findings.list

  - logging.sinks.get

  - orgpolicy.policies.get

  - cloudkms.cryptoKeys.get

  - storage.buckets.get

stage: GA

  

21. Configuration

  

  

adapter.yaml:

org_id: "123456789012"

folder_scopes:

  - "folders/456789012345"

project_scopes:

  - "projects/neurocipher-sec-prod"

regions: ["northamerica-northeast1","us-central1","europe-west1"]

features:

  remediation_apply: false

  use_tool_host: true

evidence_bucket: "neurocipher-seg-evidence-prod"

kms:

  attestation_key: "projects/.../locations/.../keyRings/seg/cryptoKeys/attest/cryptoKeyVersions/1"

  evidence_cmek: "projects/.../locations/.../keyRings/seg/cryptoKeys/evidence"

limits:

  max_parallel_projects: 5

  max_parallel_regions: 4

vpcsc:

  enabled: false

  

22. Adapter API (internal)

  

  

gRPC outline:

service GcpAdapter {

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

  

23. Tool Host Usage (optional)

  

  

- When: long-running evidence gathering, bulk policy diff, or Terraform-based remediations.
- How: Cloud Run service with minimal permissions. Adapter invokes with signed identity tokens.
- Isolation: tool host is internal to adapter. Core is unaware.

  

  

  

24. Runbooks

  

  

  

24.1 Onboard a project

  

  

1. Bind ReaderPlusSecurityMeta at project or folder.
2. Bind KMS CryptoKey Signer/Verifier for attestation key to Adapter SA.
3. If apply is needed, bind RemediationOperator with IAM Conditions for time window.
4. Enable APIs: Cloud Asset, Cloud KMS, Cloud Resource Manager, Org Policy, Logging, SCC, Compute, Storage.
5. Smoke test: CAI returns ≥10 resources.
6. Validate PAP and UBLA on evidence bucket.

  

  

  

24.2 Key rotation

  

  

1. Add new KMS key version.
2. Update adapter.yaml for new version if strict pinning.
3. New evidence uses new key. Old objects readable until key is disabled.

  

  

  

24.3 VPC-SC deny

  

  

- Check project perimeters and service perimeters.
- Add access level for adapter’s subnet or use perimeter-bridging project.
- Re-run test.

  

  

  

24.4 High throttling

  

  

- Reduce concurrency per API.
- Respect Retry-After.
- Split evaluation across projects/time windows.

  

  

  

25. DR Drill

  

  

- Simulate bucket outage: verify dual-region read.
- Disable primary KMS key version: sign with backup version.
- Resume pending plans using idempotency keys.

  

  

  

26. Cost Profile

  

  

- CAI queries: low.
- Storage: evidence dominates; expect 1–5 KiB per finding; larger for diffs.
- KMS: sign + encrypt per run and batch.
- Cloud Run/Functions: pay-per-use for tool host.

  

  

  

27. Acceptance Checklist

  

  

- Inventory across selected org/folder/projects and regions.
- Evidence in GCS with CMEK and content-addressed names.
- ≥20 controls evaluate with findings and evidence.
- ≥10 remediations plan and ≥5 apply in staging with rollback.
- Attestations sign/verify/publish end-to-end.
- OpenTelemetry dashboards live; SLOs green two weeks.
- Runbooks executed in staging.
- CI/CD gates pass; images signed; SBOM stored.