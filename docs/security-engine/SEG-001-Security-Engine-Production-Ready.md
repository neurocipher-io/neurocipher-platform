  

id: SEG-001
title: Security Engine — Production Specification
owner: Security Engineering
status: Ready for production implementation
last_reviewed: 2025-11-15

SEG-001 Security Engine — Production Specification

  

  

  

1. Purpose

  

  

Provide a cloud-neutral security evaluation and remediation engine for Neurocipher core (see docs/integrations/). The engine evaluates assets against controls, emits findings with evidence, plans remedial changes, executes remediations per policy, and produces signed attestations. Cloud specifics live in pluggable adapters. Core remains provider-agnostic.

  

  

2. Scope

  

  

Core runtime, ports and adapters, canonical data contracts, evaluation policy model, remediation workflow, evidence handling, observability, security, compliance, performance targets, rollout, and lifecycle. Out of scope: UI, pricing, non-security features.

  

  

3. References

  

  

- REF-001 Documentation Standard
- SRG-001 Schema Registry
- DM-001..DM-005 Data Models
- CI-001..CI-003 CI and Delivery
- OBS-001..OBS-003 Observability
- SEC-002 IAM Policy Maps, SEC-003 Network Policy, SEC-004 KMS Rotation
- SEC-005 Multitenancy policy
- ADR-0xx Ports and Adapters Decision
- OPA Rego v1 policy model
- OpenTelemetry v1.27.0 specs

  

  

  

4. Definitions

  

  

- Port: stable core interface that defines required behavior.
- Adapter: cloud provider implementation of a port.
- Control: policy that evaluates one or more assets and yields a pass, warn, or fail with evidence.
- Finding: record of a control result tied to assets, evidence, and severity.
- Remediation plan: ordered change set that drives a finding toward pass.
- Attestation: signed statement describing an evaluation or remediation run.

  

  

  

5. Architecture

  

  

  

5.1 Context

  

  

Core engine is stateless and runs as a service behind a queue and an API. Policy evaluation occurs in core using OPA. All cloud calls occur inside adapters.

          +-------------------+

          |   Orchestrator    |

          |   (external orchestrator (see docs/integrations/README.md))   |

          +---------+---------+

                    |

           +--------v--------+

           |  Security Core  |

           |   (SEG-001)     |

           +---+---+---+-----+

               |   |   |

     +---------+   |   +-----------+

     |             |               |

+----v----+   +----v----+    +-----v-----+

| AWS     |   | Azure   |    |  GCP      |

| Adapter |   | Adapter |    |  Adapter  |

+----+----+   +----+----+    +-----+-----+

     |             |               |

  Cloud APIs    Cloud APIs      Cloud APIs

  

5.2 Runtime

  

  

- Packaging: OCI image. Non-root. Read-only filesystem. Distroless base.
- Execution: Fargate, k8s, or Cloud Run class. Horizontal scale via queue depth.
- State: stateless workers. Persistent data in object storage and Iceberg tables.
- Policy: OPA as a library with preloaded bundles. No Cedar.

  

  

  

5.3 Data plane

  

  

- Canonical tables in Iceberg: assets, controls, findings, plans, evidence, attestations, runs.
- Evidence blobs: object storage with content-addressed keys (sha256).
- Schema governance: SRG-001 owns versions. Backward compatibility required for N-1.

  

  

  

6. Ports (Core Interfaces)

  

  

All ports are synchronous by contract and can be wrapped asynchronously by the orchestrator. All methods must be idempotent where noted.

  

  

6.1 InventoryPort

  

  

Purpose: enumerate assets and fetch point-in-time configs.

  

Methods:

  

- list_assets(scope: Scope, kinds: list[str], since: Optional[datetime]) -> list[Asset]
- get_config(ref: AssetRef, at: Optional[datetime]) -> ConfigDoc
- search(query: InventoryQuery) -> list[Asset]

  

  

Non-functional:

  

- Pagination required for > 1k assets. Stable cursors.
- Max response time target p95: 800 ms excluding provider I/O.

  

  

  

6.2 EvaluationPort

  

  

Purpose: apply controls to assets and produce findings.

  

Methods:

  

- evaluate(request: EvalRequest) -> EvalResult
- validate_control(control: ControlSpec) -> ValidationReport

  

  

Non-functional:

  

- Deterministic policy execution for the same inputs.
- Policy bundles loaded by version and signed.

  

  

  

6.3 RemediationPort

  

  

Purpose: plan and apply changes with dry-run safety.

  

Methods:

  

- plan(finding: Finding, mode: RemediationMode) -> RemediationPlan
- apply(plan: RemediationPlan, change_window: Optional[Window]) -> ApplyResult
- rollback(plan_id: UUID) -> RollbackResult

  

  

Constraints:

  

- Apply must be idempotent. Partial failures recorded with compensating actions.

  

  

  

6.4 FindingIngestPort

  

  

Purpose: write findings and evidence to storage, emit events.

  

Methods:

  

- commit(findings: list[Finding], evidence: list[EvidenceObj]) -> AppendResult
- ack(run_id: UUID) -> Ack

  

  

  

6.5 AttestationPort

  

  

Purpose: sign and publish attestations.

  

Methods:

  

- sign(run: RunSummary, scope: Scope) -> Attestation
- verify(attestation: Attestation) -> VerifyReport
- publish(attestation: Attestation, targets: list[AttestationTarget]) -> PublishReport

  

  

Crypto:

  

- DSSE-style envelope with Ed25519 default. PQC upgrade path via SRG-001.

  

  

  

7. Canonical Data Contracts (Pydantic v2)

  Python

```
from __future__ import annotations

from pydantic import BaseModel, Field, HttpUrl, AwareDatetime

from typing import Optional, List, Dict, Literal

from uuid import UUID

  

Severity = Literal["critical","high","medium","low","info"]

Result = Literal["pass","warn","fail","error","not_applicable"]

Mode = Literal["plan","apply"]

  

class Scope(BaseModel):

    org_id: str = Field(..., description="Tenant or organization id")

    project: Optional[str] = None

    region: Optional[str] = None

    tags: Dict[str,str] = {}

  

class AssetRef(BaseModel):

    urn: str = Field(..., description="Cloud-neutral URN: urn:asset:{provider}:{type}:{id}")

  

class Asset(BaseModel):

    ref: AssetRef

    kind: str = Field(..., description="Canonical type. Example: vm, bucket, identity, key")

    provider: Literal["aws","azure","gcp","onprem","other"]

    name: Optional[str] = None

    properties: Dict[str, str|int|float|bool] = {}

    discovered_at: AwareDatetime

  

class ConfigDoc(BaseModel):

    asset: AssetRef

    captured_at: AwareDatetime

    schema_version: str

    body: Dict[str, object] = Field(..., description="Provider-normalized config")

  

class ControlSpec(BaseModel):

    id: str

    version: str

    title: str

    benchmark: str = Field(..., description="CIS, NIST, ISO, custom")

    description: str

    inputs: Dict[str, object] = {}

    target_kinds: List[str]

    policy_bundle: str = Field(..., description="Bundle id in SRG-001")

    severity: Severity

    rationale: Optional[str] = None

    remediation_guidance: Optional[str] = None

  

class EvidencePointer(BaseModel):

    hash: str = Field(..., description="sha256")

    uri: Optional[HttpUrl] = None

    media_type: str

  

class Finding(BaseModel):

    id: UUID

    control_id: str

    control_version: str

    asset: AssetRef

    result: Result

    severity: Severity

    message: str

    evidence: List[EvidencePointer] = []

    created_at: AwareDatetime

    updated_at: AwareDatetime

    fingerprint: str = Field(..., description="Stable key for dedup")

  

class RemediationStep(BaseModel):

    action: str

    description: str

    params: Dict[str, object] = {}

  

class RemediationPlan(BaseModel):

    id: UUID

    finding_id: UUID

    mode: Mode

    steps: List[RemediationStep]

    estimated_risk: Literal["low","medium","high"]

    change_window: Optional[Dict[str,str]] = None

    approvals_required: List[str] = []

    created_at: AwareDatetime

  

class ApplyChangeResult(BaseModel):

    step_index: int

    status: Literal["success","skipped","failed","compensated"]

    provider_change_id: Optional[str] = None

    message: Optional[str] = None

  

class ApplyResult(BaseModel):

    plan_id: UUID

    status: Literal["success","partial","failed"]

    results: List[ApplyChangeResult]

    started_at: AwareDatetime

    ended_at: AwareDatetime

  

class RunSummary(BaseModel):

    run_id: UUID

    scope: Scope

    started_at: AwareDatetime

    ended_at: AwareDatetime

    controls: List[str]

    counts: Dict[str,int]  # pass, warn, fail, error

  

class Attestation(BaseModel):

    id: UUID

    run_id: UUID

    statement_type: Literal["evaluation","remediation"]

    payload_hash: str

    signer: str

    signature: str

    created_at: AwareDatetime

    transparency_uri: Optional[HttpUrl] = None

  

class EvalRequest(BaseModel):

    scope: Scope

    control_ids: List[str]

    assets: Optional[List[AssetRef]] = None

    since: Optional[AwareDatetime] = None

  

class EvalResult(BaseModel):

    run: RunSummary

    findings: List[Finding]

    evidence: List[EvidencePointer]
```

  

8. Adapter Interface Definitions

  

  

Adapters must implement the ports plus provider bootstrap. Example: Python protocol signatures.

Python
```
from typing import Protocol

  

class InventoryAdapter(Protocol):

    def list_assets(self, scope: Scope, kinds: list[str], since: Optional[AwareDatetime]) -> list[Asset]: ...

    def get_config(self, ref: AssetRef, at: Optional[AwareDatetime]) -> ConfigDoc: ...

    def search(self, query: dict) -> list[Asset]: ...

  

class EvaluationAdapter(Protocol):

    def evaluate(self, request: EvalRequest, controls: list[ControlSpec]) -> EvalResult: ...

    def validate_control(self, control: ControlSpec) -> dict: ...

  

class RemediationAdapter(Protocol):

    def plan(self, finding: Finding, mode: Mode) -> RemediationPlan: ...

    def apply(self, plan: RemediationPlan, change_window: Optional[dict]) -> ApplyResult: ...

    def rollback(self, plan_id: UUID) -> dict: ...

  

class FindingIngestAdapter(Protocol):

    def commit(self, findings: list[Finding], evidence: list[EvidencePointer]) -> dict: ...

    def ack(self, run_id: UUID) -> dict: ...

  

class AttestationAdapter(Protocol):

    def sign(self, run: RunSummary, scope: Scope) -> Attestation: ...

    def verify(self, attestation: Attestation) -> dict: ...

    def publish(self, attestation: Attestation, targets: list[dict]) -> dict: ...

```
  

8.1 AWS Adapter notes

  

  

- Runtime: Bedrock AgentCore for tool execution is allowed inside the AWS adapter. Do not expose it in core.
- Identity: STS assume-role per account and scope. No long-lived keys.
- Tools: Config, CloudTrail, IAM, Security Hub, GuardDuty, SSM, EC2, S3, KMS.
- Evidence: store raw API responses and change set previews as blobs with sha256.

  

  

  

8.2 Azure Adapter notes

  

  

- Services: Resource Graph, Activity Logs, Azure Policy, Defender CSPM, ARM, Key Vault.
- Identity: Managed Identity with tenant-scoped role assignments.

  

  

  

8.3 GCP Adapter notes

  

  

- Services: Cloud Asset Inventory, SCC, Cloud Logging, Org Policy, KMS, IAM.
- Identity: Workload Identity Federation with least privilege.

  

  

  

9. Policy Model

  

  

  

9.1 Bundle layout in SRG-001

  

bundles/

  cis-1.5/

    manifest.json        # id, version, inputs, target_kinds, signatures

    policies/*.rego      # one control per file

    data/*.json          # lookup tables

    tests/*.json         # vector tests

    CHECKSUMS

    SIGNATURE

  

9.2 Control shape (Rego)

  

  

- Inputs: typed with JSON schema stored in SRG-001.
- Evidence: policy returns evidence stubs; adapter enriches with provider artifacts.
- Determinism: no time-now calls inside policies. All timestamps passed as inputs.

  

  

  

9.3 Test vectors

  

  

- Positive, negative, error. At least 3 per control. Stored with the bundle and in CI.

  

  

  

10. API Surface (Core Service)

  

  

  

10.1 REST outline (OpenAPI fragment)

Yaml

  
```

openapi: 3.1.0

info: {title: Security Engine API, version: 1.0.0}

paths:

  /runs:

    post:

      summary: Start evaluation

      requestBody: { $ref: '#/components/schemas/EvalRequest' }

      responses:

        '200': { $ref: '#/components/schemas/EvalResult' }

  /findings:

    post:

      summary: Commit findings

  /plans:

    post:

      summary: Create remediation plan

  /plans/{id}/apply:

    post:

      summary: Apply plan

  /attestations:

    post:

      summary: Sign and publish attestation

components:

  schemas:

    EvalRequest: {}

    EvalResult: {}

  
```

10.2 Events

  

  

- seg.run.started, seg.run.completed, seg.findings.committed, seg.plan.created, seg.plan.applied, seg.attestation.published.  
    Schema in SRG-001. Emit via the event bus with exactly-once keys.

  

  

  

11. Observability

  

  

- Tracing: OpenTelemetry traces for every port call. Span attributes: tenant, scope, control_id, asset_kind, adapter, result.
- Metrics:  
    

- seg_eval_latency_ms histogram by control_id and adapter
- seg_findings_count counter by severity
- seg_plan_apply_success_ratio gauge
- seg_error_rate counter with error_code

-   
    
- Logs: JSON, structured. No secrets. Evidence content is hashed in logs, not inlined.
- Audit trail: all apply and rollback actions produce immutable logs with DSSE linkage.

  

  

  

12. Security

  

  

- Identity: service-to-service auth via OIDC tokens. Short TTL. Rotate daily.
- RBAC: three roles minimum  
    

- seg.reader: read runs and findings
- seg.operator: start runs, plan, dry-run apply
- seg.admin: apply, rollback, attestation publish

-   
    
- Secrets: per environment KMS. Envelope encrypt evidence pointers if they include URIs.
- Supply chain: signed OCI, SBOM, provenance (SLSA level 3 target).
- Network: deny all by default. Egress only to provider APIs and object storage.
- Data protection: PII disallowed in evidence by policy. Redaction filter pre-commit.

  

  

  

13. Performance and SLOs

  

  

- SLO-1 Evaluation latency: p95 ≤ 500 ms per control excluding provider I/O.
- SLO-2 Finding commit durability: RPO 0, RTO 5 min.
- SLO-3 Apply success ratio: monthly ≥ 99.0 percent for approved plans.
- SLO-4 API availability: monthly ≥ 99.9 percent.

  

  

Load targets:

  

- 100k assets per tenant
- 1k controls per benchmark
- 10 concurrent tenants with 10k assets each

  

  

  

14. Error Model

  

  

Standard shape:

JSON 
```

{

  "error_code": "SEG_ADAPTER_TIMEOUT",

  "message": "Adapter call exceeded timeout",

  "retryable": true,

  "details": { "adapter": "aws", "operation": "list_assets" }

}

```
Common codes:

  

- SEG_SCHEMA_VIOLATION
- SEG_POLICY_LOAD_FAILED
- SEG_ADAPTER_UNAVAILABLE
- SEG_EVIDENCE_WRITE_FAILED
- SEG_APPLY_PARTIAL
- SEG_ATTEST_VERIFY_FAILED

  

  

  

15. Remediation Workflow

  

  

16. Plan: compute minimal change set with safety checks.
17. Approval: enforce change management via policy gates.
18. Apply: execute steps with per-step timeouts, retries, backoff.
19. Verify: re-evaluate controls for affected assets.
20. Attest: sign results and publish.

  

  

Safety:

  

- Dry-run preview with diff and blast radius estimate.
- Guardrails for production hours and change windows.

  

  

  

16. Rollout and Migration

  

  

- Phase 0: enable read-only evaluation in one tenant. No apply.
- Phase 1: enable plan in staging.
- Phase 2: limited apply for low-risk findings.
- Phase 3: general availability with approval gates.

  

  

Migration from AWS-centric engine:

  

- Extract AWS logic into AWS adapter.
- Replace direct SDK calls in core with InventoryPort and RemediationPort calls.
- Validate parity using golden runs and diff on findings.

  

  

  

17. Testing and QA

  

  

- Unit: 95 percent coverage on policy helpers and schema validators.
- Policy tests: vector tests per control.
- Adapter conformance: provider simulators with canned fixtures.
- End-to-end: synthetic tenants with 10k assets.
- Chaos: inject adapter timeouts and partial apply failures.
- Security tests: authz matrix, secret redaction, DSSE verify.

  

  

  

18. Change Management and Versioning

  

  

- Semantic versioning for SEG-001 API.
- Policy bundles semver and signed.
- Breaking changes gated by ADR and deprecation window N+2 releases.
- Data contracts versioned in SRG-001 with migration scripts.

  

  

  

19. Acceptance Criteria

  

  

- All ports implemented with conformance tests for at least one adapter.
- OPA bundles load from SRG-001 with signature verification.
- Findings, evidence, plans, and attestations stored per schema with Iceberg metadata.
- OpenTelemetry traces and metrics present in staging and production.
- SLO dashboards operational.
- At least 20 baseline controls pass end-to-end in one adapter.
- Dry-run and apply workflows complete with approvals and rollback.

  

  

  

20. Appendix A — Ports Diagram

  

+------------------- Security Core -------------------+

|                                                     |

|  +----------------+   +---------------------------+ |

|  | InventoryPort  |   | EvaluationPort           | |

|  | list_assets()  |   | evaluate()               | |

|  | get_config()   |   | validate_control()       | |

|  +--------+-------+   +------------+-------------+ |

|           |                        |               |

|  +--------v-------+       +--------v-----------+   |

|  | FindingIngest  |       | RemediationPort    |   |

|  | commit()       |       | plan() apply()     |   |

|  | ack()          |       | rollback()         |   |

|  +--------+-------+       +--------+-----------+   |

|           |                        |               |

|           +------------+-----------+               |

|                        |                           |

|                 +------v------+                    |

|                 | Attestation |                    |

|                 | sign()      |                    |

|                 | verify()    |                    |

|                 | publish()   |                    |

|                 +-------------+                    |

+----------------------------------------------------+

  

Adapters implement each port per provider and are invoked by the core.

  

21. Appendix B — AWS Adapter Outline

  

  

Purpose: implement ports using AWS services. Bedrock AgentCore is permitted inside this adapter to host tools and long-running steps. It is not referenced by core.

  

Key flows:

  

- Inventory: AWS Config + Resource Explorer with STS assume-role.
- Evaluation: gather configs, pass to core OPA.
- Remediation: SSM Change Manager or direct service APIs with preview and rollback plans.
- Evidence: S3 bucket per tenant with KMS.
- Attestation: Sign with KMS asymmetric keys. Publish to S3 and optional SNS.

  

  

Minimal code skeleton:

class AwsInventoryAdapter(InventoryAdapter):

    def list_assets(...): ...

    def get_config(...): ...

    def search(...): ...

  

class AwsRemediationAdapter(RemediationAdapter):

    def plan(...): ...

    def apply(...): ...

    def rollback(...): ...

  

22. Appendix C — Azure and GCP Adapters

  

  

- Azure: Resource Graph for inventory. ARM for changes. Defender and Policy for signals.
- GCP: Cloud Asset Inventory for inventory. Org Policy and service APIs for changes.

  

  

  

23. Appendix D — Example Control

  

  

ID: cis-storage-public-access-block

Target kinds: bucket

Severity: high

  

Inputs:

{"block_public_acls": true, "block_public_policy": true}

Policy result shape:

{

  "result": "fail",

  "message": "Bucket allows public policy",

  "evidence": [{"hash":"<sha256>","media_type":"application/json"}]

}

AWS remediation steps example:

  

- PutPublicAccessBlock
- DeleteBucketPolicy if policy grants Principal:"*"

  

  

  

24. Appendix E — Evidence Handling

  

  

- Evidence bodies stored as blobs with sha256 hash.
- Findings only contain pointers and hashes.
- Large artifacts chunked at 8 MB with reassembly map.
- Retention default 400 days. Configurable per tenant.

  

  

  

  

Status: Ready for production implementation.

Change: SEG-001 supersedes prior AWS-centric wording.

Impact: No changes to SRG-001. Adapters added per provider.
