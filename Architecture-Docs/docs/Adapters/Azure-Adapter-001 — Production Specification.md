  

Azure-Adapter-001 — Production Specification

  

  

  

1. Purpose

  

  

Implement SEG-001 ports for Microsoft Azure. The adapter discovers assets, normalizes configs, evaluates controls via core, generates evidence, plans and applies remediations, and produces signed attestations. All Azure logic stays here. Core remains cloud-neutral.

  

  

2. Scope

  

  

Single- and multi-tenant Azure estates across Management Groups, Subscriptions, and Resource Groups. Read-only evaluation, dry-run planning, controlled apply with approvals. Includes identity, networking, data paths, observability, SLOs, CI/CD, security, rollout, DR, and runbooks.

  

Out of scope: UI, billing, non-Azure providers.

  

  

3. References

  

  

- REF-001 Documentation Standard
- SEG-001 Security Engine
- SRG-001 Schema Registry
- SEC-002 IAM Policy Maps, SEC-003 Network Policy, SEC-004 KMS Rotation
- OBS-001..003 Observability
- CI-001..003 CI/CD
- ADR-0xx Ports/Adapters decision

  

  

  

4. Architecture

  

  

  

4.1 Components

  

  

- Identity Broker: acquires tokens for adapter via Managed Identity; elevates via PIM when required.
- Inventory Worker: enumerates assets with Azure Resource Graph (ARG) and service SDKs.
- Evidence Writer: writes evidence to Azure Blob Storage with customer-managed keys.
- Remediation Planner/Executor: builds ARM/Bicep change sets and Policy remediation tasks.
- Attestation Signer: signs with Azure Key Vault keys.
- Adapter API: internal gRPC/HTTP for core <-> adapter calls.
- Tool Host (optional): long-running tool flows hosted as Container Apps/Functions, invoked only by the adapter.

  

  

  

4.2 Data flow

  

  

1. Core invokes adapter port.
2. Adapter authenticates via Managed Identity and role assignments.
3. Inventory queries ARG and service endpoints, normalizes to Asset + ConfigDoc.
4. Core evaluates policies. Adapter enriches evidence and writes blobs.
5. Planner computes diff. Executor applies via ARM/Policy/CLI ops with approvals.
6. Attestation is signed and published.

  

  

  

4.3 Deployment topologies

  

  

- Org-centralized (recommended): adapter runs in a Security subscription. Cross-subscription access via role assignments at Management Group or Subscription scope.
- Per-business-unit: one adapter per management group.

  

  

  

5. Identity and Access

  

  

  

5.1 Principals and roles

  

  

- AdapterManagedIdentity (user-assigned MI on the adapter host):  
    

- Reader at target scopes for inventory.
- Custom minimal roles for specific read APIs not covered by Reader (e.g., Key Vault get key properties).
- Optional Contributor subset or custom RemediationOperator role for apply actions.
- Key Vault Crypto User on attestation vault keys.

-   
    
- Elevated path (optional): Privileged Identity Management (PIM) activates RemediationOperator for apply windows.

  

  

  

5.2 Cross-tenant

  

  

- Use Azure Lighthouse for service provider access when tenants differ. Define Delegated Resource Management offers granting Reader/Custom roles to the MI’s home tenant.

  

  

  

5.3 Credential hygiene

  

  

- No client secrets. Managed Identity only. Token cache in memory. PIM activations time-boxed. Activity logged in Entra ID.

  

  

  

6. Networking

  

  

- Private execution. No public ingress.
- Private Endpoints to: Storage (Blob), Key Vault, Monitor/Logs Ingestion, Container Registry.
- Egress restricted by NSGs + UDR to Azure service tags for: AzureResourceGraph, AzureMonitor, AzureActiveDirectory, service endpoints per API.
- Internal access via Private Link Service or internal load balancer if API exposure is required.

  

  

  

7. Storage and Data

  

  

- Evidence storage: Azure Storage Blob with CMK in Key Vault or Managed HSM.  
    

- Container: evidence/. Versioning on. Soft delete on. Immutability policy optional.
- Naming: evidence/{sha256[0:2]}/{sha256}.bin.

-   
    
- Attestations: Blob prefix attestations/.
- Index (optional): small metadata rows in Azure Table or Cosmos DB if cursor caching is needed.
- Canonical analytical tables live in the core data plane (Iceberg). Adapter writes only evidence and minimal indexes.

  

  

  

8. Port Implementations

  

  

  

8.1 InventoryPort

  

  

  

list_assets(scope, kinds, since) -> Asset[]

  

  

- Primary: Azure Resource Graph (ARG) Resources query with Kusto filters for kinds and time.
- Coverage  
    

- vm → Microsoft.Compute/virtualMachines
- bucket → Microsoft.Storage/storageAccounts (blob containers surfaced via ARM)
- db → Microsoft.DBforPostgreSQL, Microsoft.DBforMySQL, Microsoft.Sql/servers/databases, Cosmos DB
- identity → Microsoft.Authorization/roleAssignments, Microsoft.ManagedIdentity/userAssignedIdentities, Entra objects via MS Graph (if delegated)
- key → Microsoft.KeyVault/vaults/keys
- network → Microsoft.Network/virtualNetworks, subnets, networkSecurityGroups, publicIPAddresses, loadBalancers, applicationGateways
- aks, functions, appservice, webapps, eventhub, servicebus, policy, security (Defender), monitor

-   
    
- Normalization  
    

- Asset.ref.urn: urn:asset:azure:{type}:{subscriptionId}:{location}:{resourceId}
- Asset.kind: canonical kind mapping table.
- properties: key identifiers (resourceId, names).

-   
    
- Pagination  
    

- Use ARG server-side paging. Keep continuation tokens per subscription.

-   
    
- Fallbacks  
    

- ARM GET for resources not in ARG.

-   
    
- Since  
    

- Filter on properties.changeTime or ARM api-version with If-None-Match etags when possible.

-   
    

  

  

  

get_config(ref, at) -> ConfigDoc

  

  

- Point-in-time  
    

- Prefer Change History sources when available (Activity Log, Resource Graph Change History).
- Else call ARM GET for the resource at capture time.

-   
    
- Body  
    

- Provider-normalized JSON. Preserve ARM shapes and policy states.

-   
    

  

  

  

search(query) -> Asset[]

  

  

- Kusto templated query over ARG restricted to whitelisted fields.

  

  

Errors

  

- Missing role → AZURE_ACCESS_DENIED.
- ARG throttling → backoff with jitter.
- Private endpoint misconfig → AZURE_ENDPOINT_UNREACHABLE.

  

  

  

8.2 EvaluationPort

  

  

  

evaluate(request) -> EvalResult

  

  

- Fetch configs in batches with ARM.
- Call core OPA with ControlSpec bundles.
- Produce evidence stubs from decision metadata.

  

  

  

validate_control(control) -> ValidationReport

  

  

- Load bundle from SRG-001. Lint inputs schema. Run vector tests with canned fixtures.

  

  

Performance

  

- Batch by resource type and subscription. Target p95 evaluation ≤ 300 ms + I/O.

  

  

  

8.3 RemediationPort

  

  

  

plan(finding, mode) -> RemediationPlan

  

  

- Compute ARM/Bicep change set or Azure Policy remediation task where applicable.
- Calculate blast radius (resource count, dependencies).
- Check locks and DINE (deny assignments from Policy) preconditions.

  

  

  

apply(plan, change_window) -> ApplyResult

  

  

- Paths:  
    

1. ARM/Bicep deployment at RG/Subscription/MG scope using Deployment Stacks where supported.
2. Policy remediation: create remediation task against non-compliant resources for the relevant initiative/definition.
3. Service-specific: e.g., rotate Key Vault keys, set Storage public access to disabled, tighten NSG rules, enable Defender plans.

-   
    
- Guardrails  
    

1. Approval gate via change window and PIM activation.
2. Idempotency key = plan.id.
3. Pre-flight validation: what-if for ARM deployments.

-   
    
- Rollback  
    

1. Reverse ARM template if possible or apply saved previous state from evidence snapshot.

-   
    

  

  

High-value remediations

  

- Storage: allowBlobPublicAccess=false, enable soft delete, immutability, CMK.
- NSG: remove 0.0.0.0/0 ingress on critical ports.
- Defender for Cloud: enable plans at subscription/MG scope.
- Policy: assign built-in CIS/NIST initiatives; remediate non-compliant resources.
- Logging: enable Activity Log to dedicated Log Analytics + diagnostic settings for key services.
- Key Vault: enable purge protection, RBAC, network ACLs.
- Compute: enforce Azure Disk Encryption where required.

  

  

  

8.4 FindingIngestPort

  

  

  

commit(findings, evidence) -> AppendResult

  

  

- Upload evidence bodies to Blob Storage with content-addressed names.
- Write manifest JSON with mediaType, size, sha256.
- Emit seg.findings.committed event via Event Grid or Service Bus. Stable idempotency key.

  

  

  

ack(run_id) -> Ack

  

  

- Confirm persistence and watermark.

  

  

  

8.5 AttestationPort

  

  

  

sign(run, scope) -> Attestation

  

  

- DSSE envelope over RunSummary.
- Sign with Key Vault asymmetric key (RSA-4096 or EC P-256).
- Store signature and envelope in Blob.

  

  

  

verify(attestation) -> VerifyReport

  

  

- Verify Key Vault signature and payload hash.

  

  

  

publish(attestation, targets) -> PublishReport

  

  

- Blob write and optional Event Grid publish.

  

  

  

9. Evidence Model

  

  

- Media types: application/json, text/plain, application/yaml, application/octet-stream.
- Chunk > 8 MiB into chunks/*.part + manifest.json.
- Redaction filter before commit. Redaction log stored alongside evidence.

  

  

  

10. Observability

  

  

- Tracing: OpenTelemetry around ARG, ARM, Policy, Monitor calls.  
    

- Attributes: tenant, run_id, subscription, location, provider, resourceType, control_id.

-   
    
- Metrics  
    

- azure_adapter_api_throttle_total{provider,operation}
- azure_adapter_inv_latency_ms{port,operation} histogram
- azure_adapter_findings_total{severity,control_id}
- azure_adapter_apply_success_ratio
- azure_adapter_error_total{error_code}

-   
    
- Logs: JSON only. No secrets. Include evidence hashes only.
- Exporters: Azure Monitor OTLP or Prometheus if self-hosted.

  

  

  

11. Security Controls

  

  

- Key Vault  
    

- Keys: kv-attestation, optional HSM-backed.
- Access: MI has Crypto User. RBAC only; disable access policies where possible.

-   
    
- Storage  
    

- Encryption with CMK. Blob versioning, soft delete, immutability optional.
- Public access disabled at account level.
- Private endpoint only.

-   
    
- RBAC  
    

- Least privilege custom roles for apply. Reader for inventory.
- PIM activation for elevated roles with approval and justification.

-   
    
- Network  
    

- Private Endpoints. NSG deny all egress except required service tags.

-   
    
- Supply chain  
    

- Signed OCI images, SBOM, provenance.

-   
    

  

  

  

12. Performance Targets (Adapter slice)

  

  

- Inventory p95: 10k assets across 20 subscriptions and 6 regions ≤ 12 min full sweep.
- Config fetch p95: ≤ 500 ms via ARM cached endpoints, ≤ 1200 ms cold.
- Remediation apply p95: step ≤ 3 s for control-plane operations.

  

  

  

13. Error Model

  

  

Standard:

{

  "error_code": "AZURE_RATE_LIMIT",

  "message": "Throttled by Azure API",

  "retryable": true,

  "details": {"provider":"Microsoft.Compute","operation":"GET"}

}

Common:

  

- AZURE_ACCESS_DENIED
- AZURE_RATE_LIMIT
- AZURE_SERVICE_UNAVAILABLE
- AZURE_ARG_TIMEOUT
- AZURE_POLICY_DENY_ASSIGNMENT
- AZURE_KV_SIGN_FAILED
- AZURE_PRIVATE_ENDPOINT_BLOCKED

  

  

Retry policy: exponential backoff 200–3200 ms with jitter. Circuit-breaker per provider/operation.

  

  

14. CI/CD

  

  

- Build: containerize adapter. Unit + integration tests against Azurite where feasible and live sandbox for gaps.
- Security gates: Trivy scan, license check, SBOM diff, IaC drift, OPA vector tests.
- Deploy: Bicep/Terraform or GitHub Actions/ADO pipelines. Blue/green with health probes.
- Config: versioned adapter.yaml in registry with management group/subscription scopes, regions, features.

  

  

  

15. Rollout

  

  

- Phase 0: read-only in one subscription.
- Phase 1: read-only across target management group.
- Phase 2: remediation plan in staging subscriptions.
- Phase 3: controlled apply with PIM approval and change windows.

  

  

  

16. DR and Resilience

  

  

- Stateless services. Redeployable from container registry.
- Evidence account with GRS or RA-GRS replication.
- Key Vault soft-delete and purge protection on.
- Idempotent checkpoints to resume runs.

  

  

  

17. Compliance Hooks

  

  

- Attestations: DSSE + Key Vault signature, immutable retention.
- Change records: link to Deployment operations, Activity Logs, Policy remediation jobs.
- Audit export: CSV/Parquet export of findings and plans per tenant/subscription.

  

  

  

18. Testing Strategy

  

  

- Unit: ≥90% coverage for mappers, paginators, policy helpers.
- Adapter conformance: run SEG-001 suite.
- Integration: seeded sandbox with 1000+ resources across common providers.
- Soak: 24-hour run across 5 regions, throttle/timeout injection.
- Security: RBAC authZ matrix, KV sign/verify, Storage deny policies.
- Chaos: kill pods, disable Private Endpoint, simulate PIM denial.

  

  

  

19. Acceptance Criteria

  

  

- Inventory covers baseline kinds across Compute, Storage, Network, SQL/Cosmos, AKS, Functions, App Service, Key Vault, Policy, Defender.
- Evidence written to Blob with CMK encryption and correct hashes.
- ≥20 controls evaluate with findings and evidence.
- ≥10 remediations plan and ≥5 apply in staging with rollback verified.
- Attestations sign/verify/publish end-to-end.
- OpenTelemetry dashboards live and SLOs green for two weeks.
- Runbooks executed in staging.
- CI/CD gates pass; images signed; SBOM stored.

  

  

  

20. Role Definitions (sketches)

  

  

  

20.1 RemediationOperator (custom)

  

  

Minimum excerpt. Expand per use case.

{

  "Name": "RemediationOperator",

  "IsCustom": true,

  "Description": "Apply approved security remediations",

  "Actions": [

    "Microsoft.Authorization/policyAssignments/write",

    "Microsoft.PolicyInsights/remediations/*",

    "Microsoft.Resources/deployments/*",

    "Microsoft.Network/networkSecurityGroups/*",

    "Microsoft.Storage/storageAccounts/*",

    "Microsoft.KeyVault/vaults/*",

    "Microsoft.Security/*",

    "Microsoft.OperationalInsights/workspaces/write",

    "Microsoft.Insights/diagnosticSettings/*"

  ],

  "NotActions": [],

  "AssignableScopes": ["/providers/Microsoft.Management/managementGroups/NEUROCIPHER"]

}

  

20.2 Reader+ (custom minimal read gaps)

  

{

  "Name": "ReaderPlusSecurityMeta",

  "IsCustom": true,

  "Actions": [

    "Microsoft.KeyVault/vaults/read",

    "Microsoft.KeyVault/vaults/keys/read",

    "Microsoft.Security/*/read",

    "Microsoft.PolicyInsights/*/read"

  ],

  "AssignableScopes": ["/* appropriate scopes */"]

}

  

21. Configuration

  

  

adapter.yaml:

tenant_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

mg_scopes:

  - "/providers/Microsoft.Management/managementGroups/NC-ROOT"

regions: ["canadacentral","eastus","westeurope"]

features:

  remediation_apply: false

  use_tool_host: true

evidence_storage:

  account: "ncdpsegevidenceprod"

  container: "evidence"

  cmk_key_id: "https://kv-seg-prod.vault.azure.net/keys/attestation-key/..."

key_vault:

  url: "https://kv-seg-prod.vault.azure.net/"

limits:

  max_parallel_subscriptions: 5

  max_parallel_regions: 4

  

22. Adapter API (internal)

  

  

gRPC outline:

service AzureAdapter {

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

  

  

- When: long-running or multi-step evidence gathering and remediation flows.
- How: host tools as Azure Container Apps or Functions; adapter invokes them.
- Isolation: tool host details remain inside the adapter. Core is unaware.

  

  

  

24. Runbooks

  

  

  

24.1 Onboard a subscription

  

  

1. Assign Reader and ReaderPlusSecurityMeta to AdapterManagedIdentity at subscription or management group scope.
2. If apply is needed, onboard RemediationOperator via PIM with approval.
3. Enable Resource Graph for tenant.
4. Smoke test: ARG query returns ≥10 resources.
5. Validate Private Endpoints for Storage and Key Vault.

  

  

  

24.2 Key rotation

  

  

1. Create new Key Vault key.
2. Update adapter.yaml CMK.
3. New evidence uses new key. Old blobs accessible until key retirement.

  

  

  

24.3 Policy denies

  

  

- Inspect Microsoft.Authorization/policyAssignments and denyAssignments.
- Add remediation exclusions or staged initiative if needed.
- Re-plan.

  

  

  

24.4 High throttling

  

  

- Reduce parallelism per provider.
- Add ARG query limits.
- Consider regional distribution of calls.

  

  

  

25. DR Drill

  

  

- Simulate Storage account outage. Verify RA-GRS read from secondary.
- Rotate to secondary Key Vault if regional outage.
- Resume pending plans with idempotency keys.

  

  

  

26. Cost Profile

  

  

- ARG queries: low cost.
- Storage: evidence dominates cost.
- Key Vault: sign and wrap operations per run/evidence batch.
- Policy remediation jobs: per-resource operations.
- Container Apps/Functions: pay-per-use for tool host if enabled.

  

  

  

27. Acceptance Checklist

  

  

- Inventory across selected management groups and regions.
- Evidence in Blob with CMK, content-addressed.
- ≥20 controls evaluate with findings and evidence.
- ≥10 remediations plan and ≥5 apply in staging with rollback.
- Attestations sign/verify/publish end-to-end.
- OpenTelemetry dashboards live; SLOs green two weeks.
- Runbooks executed in staging.
- CI/CD gates pass; images signed; SBOM stored.

