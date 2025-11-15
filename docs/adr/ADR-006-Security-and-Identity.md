id: ADR-006
title: Security and Identity
owner: Security Lead
status: Accepted
last_reviewed: 2025-10-23

ADR-006 Security and Identity

  

  

- Status: Accepted
- Date: 2025-10-23
- Owners: Security Lead

  

  

  

Context

  

  

Sensitive ingestion requires isolation, least privilege, and auditability.

  

  

Decision

  

  

Use AWS IAM Roles with fine-grained trust and scoped permissions.

  

- GitHub Actions assumes role via OIDC.
- Runtime roles per service (ingest, normalize, embed, index, api).
- No static credentials stored in code or repo.
- Secrets stored in AWS Secrets Manager, encrypted by KMS key per environment.
- Network: Private subnets, VPC endpoints for S3 and Secrets Manager.
- TLS enforced.
- SBOM and provenance attestations generated in CI.

  

  

  

Alternatives

  

  

1. Central service account shared across workloads.
2. HashiCorp Vault.

  

  

Rejected for weaker isolation or extra ops complexity.

  

  

Consequences

  

  

- Zero standing credentials.
- Fine-grained revocation.
- More IAM policies to manage.

## Acceptance Criteria

- GitHub Actions uses OIDC to assume environment-scoped IAM roles; there are no static AWS access keys or secrets checked into the repository or stored in CI.
- Each core service (ingest, normalize, embed, index, api) runs with its own IAM role and least-privilege policy, and no shared "god" service account is used across workloads.
- Secrets required by services are stored exclusively in AWS Secrets Manager and encrypted with per-environment KMS keys, with access policies defined in SEC-002/SEC-004.
- Network controls (private subnets, VPC endpoints for S3 and Secrets Manager, TLS) are implemented as described here and in SEC-003, and verified via IaC and security scans.
- SBOMs and provenance attestations are generated in CI for deployable artifacts and stored according to security and compliance requirements.
