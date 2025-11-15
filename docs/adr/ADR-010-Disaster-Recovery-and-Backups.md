id: ADR-010
title: Disaster Recovery and Backups
owner: Platform Reliability
status: Accepted
last_reviewed: 2025-10-23

ADR-010 Disaster Recovery and Backups

  

  

- Status: Accepted
- Date: 2025-10-23
- Owners: Platform Reliability

  

  

  

Context

  

  

Loss of storage or corruption in vector indexes can impact both Neurocipher Core consumers and partner integrations. Recovery time must remain minimal.

  

  

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

## Acceptance Criteria

- S3 versioning and cross-region replication are enabled for designated buckets, and DynamoDB PITR plus exports to S3 are configured for critical tables.
- Weaviate snapshot jobs are running on the defined schedule, writing to S3 with checksum validation, and restore procedures are documented and tested.
- Backup and restore configurations for Terraform state and secrets (including KMS key rotation cadences) are implemented as described in this ADR.
- DR-001 reflects the RPO/RTO targets defined here (≤ 1 h RPO, ≤ 4 h RTO), and periodic DR exercises demonstrate that these targets are achievable.
- Runbooks for disaster recovery and backup/restore operations exist under `docs/runbooks/` and are kept current.

  

  

  

Links

  

  

- ops/runbooks/recovery.md
- infra/modules/backup/
