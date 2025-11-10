  

ADR-010 Disaster Recovery and Backups

  

  

- Status: Accepted
- Date: 2025-10-23
- Owners: Platform Reliability

  

  

  

Context

  

  

Loss of storage or corruption in vector indexes can impact both AuditHound and Neurocipher Core consumers. Recovery time must remain minimal.

  

  

Decision

  

  

Implement multi-layered backup and restore procedures.

  

- S3: versioning enabled, cross-region replication to secondary AWS region.
- DynamoDB: point-in-time recovery (PITR) with daily export to S3.
- Weaviate: nightly snapshot to S3, checksum validated.
- Terraform: state backend replicated via remote locking.
- Secrets: encrypted snapshots with KMS rotation every 90 days.
- RTO: ≤ 4 h; RPO: ≤ 1 h.

  

  

  

Alternatives

  

  

1. Single-region architecture.
2. Manual restore only.

  

  

Rejected for unacceptable downtime.

  

  

Consequences

  

  

- Slightly higher storage cost.
- Periodic validation required.
- Enables regional failover.

  

  

  

Links

  

  

- ops/runbooks/recovery.md
- infra/modules/backup/