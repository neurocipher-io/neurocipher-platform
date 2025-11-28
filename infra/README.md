# Infrastructure

Infrastructure as Code for Neurocipher platform.

## Structure

```
infra/
├── modules/          # Cloud-agnostic Terraform modules
├── aws/
│   └── environments/
│       ├── dev/      # Development environment
│       ├── stg/      # Staging environment
│       └── prod/     # Production environment
├── gcp/              # GCP-specific (placeholder)
└── azure/            # Azure-specific (placeholder)
```

## Standards

- Environment names: `dev`, `stg`, `prod` per REF-002
- Resource tags per REF-001 §6.1
- KMS aliases per REF-002: `alias/nc-dp-data-{env}`
- S3 buckets per REF-002: `s3://nc-dp-{env}-raw`, `s3://nc-dp-{env}-norm`

## Strategy

AWS-first implementation with abstraction layer for future GCP and Azure support.
