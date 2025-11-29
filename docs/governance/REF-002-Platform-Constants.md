---
id: REF-002
title: Platform Constants
owner: Platform Architecture
status: Draft
last_reviewed: 2025-11-10
---

# REF-002 Platform Constants

**Purpose:** Canonical reference for identifiers shared across docs, infrastructure, and services.

## Environments

| Constant | Value | Notes |
| --- | --- | --- |
| `envs` | `dev`, `stg`, `prod` | Slugs used in infrastructure, tagging, and routing. |
| AWS accounts | `nc-dp-dev`, `nc-dp-stg`, `nc-dp-prod` | One per environment. |
| Base URL | `https://api.neurocipher.io/{env-prefix}` | `prod` omits prefix, others use subdomains. |
| API prefix | `/v1` | All paths in `openapi.yaml` include `/v1`. |

## Service and repository names

| Service | Name | Container/ECR repo |
| --- | --- | --- |
| Ingest API | `svc-ingest-api` | `ecr.us-east-1.amazonaws.com/nc/svc-ingest-api` |
| Normalize workers | `svc-normalize` | `.../svc-normalize` |
| Embed workers | `svc-embed` | `.../svc-embed` |
| Query API | `svc-query-api` | `.../svc-query-api` |
| Security Action API | `svc-security-actions` | `.../svc-security-actions` |

## Storage

| Type | Constant |
| --- | --- |
| Raw bucket | `s3://nc-dp-{env}-raw` |
| Normalized bucket | `s3://nc-dp-{env}-norm` |
| Schema bucket | `s3://nc-dp-{env}-schema` |
| DynamoDB table (documents) | `nc-dp-{env}-documents` |
| Security command table | `nc-dp-{env}-security-actions` |

## KMS aliases

| Alias | Purpose |
| --- | --- |
| `alias/nc-dp-data-{env}` | Data encryption for S3, DynamoDB. |
| `alias/nc-dp-schema-{env}` | Schema registry signing. |
| `alias/nc-dp-security-{env}` | Security Engine command payloads. |

## Required tags

`Project=Neurocipher`, `Service=<service-name>`, `Env=<env>`, `Owner=<team>`, `Compliance=SOX|GDPR`, `DataClass=public|internal|restricted`.

Refer to this file when defining IaC variables, alert filters, or documentation literals instead of redefining constants inline.
