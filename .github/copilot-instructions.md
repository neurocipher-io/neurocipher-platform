# Neurocipher Platform - GitHub Copilot Instructions

This repository contains the Neurocipher cloud security platform for SMBs, including documentation, services, infrastructure, and shared libraries.

## Project Overview

The Neurocipher platform is an enterprise cloud security platform built around several key modules:
- **Neurocipher Core**: Continuous cloud security scanning
- **AuditHound**: Compliance assessment and reporting  
- **Agent Forge**: Auto-remediation orchestration
- **MCP Server**: Model Context Protocol integration
- **Data Pipeline**: Ingestion, normalization, embedding, query

## Repository Structure

```
neurocipher-platform/
├── docs/           # Architecture and product documentation (REF-001 format)
├── services/       # Backend services (Lambda, Step Functions, Glue)
├── libs/python/    # Shared Python libraries (nc_models, nc_common, nc_observability)
├── infra/          # Infrastructure as Code (Terraform modules)
├── schemas/        # JSON/Avro schemas and OpenAPI specifications
├── ops/            # Operational artifacts (dashboards, alerts, owners.yaml)
├── migrations/     # Database migrations
└── .github/        # CI/CD workflows
```

## Key Standards & Guidelines

### Naming Conventions

- **Service names**: `svc-{domain}-{function}` (e.g., `svc-ingest-api`)
- **Python packages**: `snake_case` (e.g., `nc_models`, `nc_common`)
- **JSON fields**: `snake_case`
- **API paths**: `/v1/`, kebab-case nouns
- **Filenames**: Use kebab-case, avoid spaces, ampersands, and em dashes
- **Environment names**: `dev`, `stg`, `prod` (not "staging" or "production")

### Identifiers & Data Formats

- **IDs**: Use UUIDv7 format (e.g., `018fa0b8-6cde-7d2a-bd7f-8d9a3f6f1d0a`)
- **Events**: CloudEvents 1.0 envelope, type naming: `domain.service.event.v{major}`
- **Timestamps**: ISO 8601 with Z suffix (e.g., `2025-11-26T18:00:00Z`)
- **Errors**: RFC 7807 Problem Details with `application/problem+json` content-type

### Python Style

- Follow Black defaults (88-char lines, 4-space indent)
- Use type hints for all public functions
- Import order: standard library, third-party, local (managed by isort)
- Test files: `test_<feature>.py` with ≥80% coverage
- Fixtures: Place in `tests/fixtures/`

### Documentation

All documentation must follow REF-001 standards:

- **Required front matter**: `id`, `title`, `owner`, `status`, `last_reviewed`
- **Format**: Mermaid for diagrams (not ASCII art)
- **Style**: Active voice, present tense, sentence-case headings
- **No em dashes**: Use commas, semicolons, or split sentences
- **Required header sections**: Status, Owner, Approvers, Last updated, Applies to, Related

### JSON/YAML

- Use 2-space indents
- Kebab-case filenames (e.g., `event.security.finding.v1.json`)
- Schemas must include: `$schema`, `$id`, `title`, and `examples`

### Security

- **Never commit secrets** or `.env` files - use AWS Secrets Manager and SSM parameters
- Enforce KMS encryption in all infrastructure templates
- Use least-privilege IAM policies
- Review `ops/owners.yaml` before editing IAM-related IaC

## Build & Development Commands

```bash
make init    # Bootstrap Poetry, Node tooling, and pre-commit hooks
make fmt     # Apply Black, isort, and markdownlint
make lint    # Run Spectral, markdownlint, yamllint, and Lychee link checks
make test    # Execute pytest suites with coverage
make build   # Package Lambda bundles and containers, scan dependencies
```

For OpenAPI-only linting: `npm run spectral` (faster when editing `openapi.yaml`)

## Testing Guidelines

- Use pytest for all Python tests
- Maintain ≥80% line coverage
- Run locally before pushing: `make test`
- Full coverage command: `pytest --junitxml=reports/junit.xml --cov=src --cov-report=xml --cov-fail-under=80`
- Keep test data samples in `schemas/events/examples/`

## Commit & Pull Request Guidelines

- **Commit format**: `type: scope` (e.g., `feat: ingestion retries`, `docs: runbook refresh`)
- Reference Jira IDs in commit body
- Avoid mixing IaC with runtime changes unless justified
- PRs must include:
  - Summary of changes
  - Evidence of `make fmt && make lint && make test` passing
  - Linked issue
  - Screenshots/logs for UX or dashboard work
  - Reviewer tags from `ops/owners.yaml`
- Keep PRs in draft until Spectral, markdownlint, and Lychee checks pass in CI

## Validation & CI/CD

- Local validation runs: `markdownlint`, `yamllint`, `ruff`, `black --check`, `isort --check-only`, `pytest`
- CI performs networked checks (Spectral + Lychee) on every push/PR
- Workflows must exist: `.github/workflows/openapi-lint.yml`, `.github/workflows/lint.yml`
- PR checks required: Spectral, Markdownlint, LinkCheck

## Anti-Patterns to Avoid

- Don't use bare `except:` statements
- Avoid mutable default arguments in Python
- Don't use spaces, ampersands, or em dashes in filenames
- Don't mix different types of changes (IaC + runtime) without justification
- Don't add dependencies without checking security advisories
- Don't skip documentation updates when changing APIs or schemas

## Integration Points

When editing security-engine contracts:
1. Update both schema `$id` fields and corresponding guides in `docs/security-engine/`
2. Rerun Spectral validation
3. Validate JSON schema compliance
4. Request review before merging

## References

- [Architecture Index](docs/governance/GOV-ARCH-001-Architecture-Documentation-Index.md)
- [Standards Catalog](docs/governance/REF-001-Glossary-and-Standards-Catalog.md)
- [Platform Context](docs/architecture/ARC-001-Platform-Context-and-Boundaries.md)
- [Platform Constants](docs/REF-002-Platform-Constants.md)
- See `AGENTS.md` and `agents.yaml` for automation and validation rules
