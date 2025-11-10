  

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