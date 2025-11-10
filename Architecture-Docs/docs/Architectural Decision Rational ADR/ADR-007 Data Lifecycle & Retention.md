  

ADR-007 Data Lifecycle and Retention

  

  

- Status: Proposed
- Date: 2025-10-23
- Owners: Data Governance

  

  

  

Context

  

  

Different data types require different retention windows. Costs and compliance drive lifecycle control.

  

  

Decision

  

  

Implement tiered lifecycle policies.

  

- Raw S3 data: 90-day retention then Glacier Deep Archive.
- Normalized objects: 180-day retention.
- Embeddings and metadata: retained indefinitely unless flagged for deletion.
- DLQ messages: 14-day retention.
- Audit logs: 1-year minimum.

  

  

  

Alternatives

  

  

1. Infinite retention.
2. Periodic full purges.

  

  

Rejected for cost or data loss risk.

  

  

Consequences

  

  

- Predictable storage growth.
- Automatic cleanup via lifecycle rules.
- Restore possible within 48 h from Glacier.