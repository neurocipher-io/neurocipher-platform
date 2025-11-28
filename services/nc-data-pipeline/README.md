# nc-data-pipeline

Neurocipher Data Pipeline service.

## Services

- `svc-ingest-api` - Raw data ingestion from cloud providers
- `svc-normalize` - Transformation and enrichment
- `svc-embed` - Vector embedding workers
- `svc-query-api` - Query and analytics API

## Structure

```
nc-data-pipeline/
├── src/nc_data_pipeline/   # Service code (to be implemented)
├── tests/                  # Service-specific tests
└── README.md
```

## Note

Database migrations and schemas remain at repository root until
service implementation begins. See MIGRATION-PLAN.md Phase 4 notes.
