# WARP.md

This file provides guidance to WARP (warp.dev) when working with code and configuration in this repository.

## Repository purpose and scope

- AWS-native ingestion and retrieval engine for the Neurocipher platform.
- Pipelines for data normalization, embedding generation, and hybrid vector + keyword search backed by Weaviate and OpenSearch Serverless.
- Includes IaC, CI/CD, observability, and governance for multi-environment deployment (dev, stg, prod) as defined in `docs/Project Instructions.md`, `docs/architecture.md`, and `docs/System-Architecture-Blueprint.md`.

## Architecture and runtime mental model

- **Ingest → Normalize → Embed → Query**

  - Sources (S3 file drops, webhooks, API pulls, DB dumps) enqueue into an SQS ingest queue.
  - A normalize Lambda reads from SQS, writes raw and normalized objects to S3, upserts metadata into the Postgres metadata catalog (nc.source_document, nc.document_chunk, etc.), and enqueues embed tasks.
  - Embed workers on ECS Fargate batch process embed tasks, call embedding models, and upsert into Weaviate (vectors) and OpenSearch Serverless (keyword index) while syncing Postgres metadata updates.
  - A FastAPI-based query API (Fargate) performs vector and keyword search, fuses results (reciprocal rank fusion), and returns hybrid responses.

- **Core services** (see `docs/architecture.md` and `docs/System-Architecture-Blueprint.md`):

  - `ingest` – webhooks and API-pull connectors writing to the ingest queue.
  - `normalize` – MIME routing, parsing, PII detection and tokenization, writing canonical schemas.
  - `embed` – embedding and upsert to Weaviate and OpenSearch.
  - `api` – `/query`, `/ingest`, `/admin`, `/health` endpoints for ingest and retrieval.
  - `batch` – reindex, backfill, migrations, disaster-recovery drills.

- **Security and network**

  - All compute runs in private subnets behind ALB or API Gateway.
  - VPC endpoints for S3, Secrets Manager, RDS (Postgres metadata), and other managed services.
  - Secrets live in AWS Secrets Manager; KMS keys per environment; IAM roles are scoped per service.
  - Threat model and mitigations are defined in `docs/security-controls/SEC-001-Threat-Model-and-Mitigation-Matrix.md`.

- **Lineage and enrichment**

  - Lineage and catalog are specified in `docs/lineage/LIN-001-Data-Lineage-and-Catalog-Specification.md`.
  - Enrichment, routing, and persistence patterns (vector store, analytics lake, search index, DLQ behavior) are defined in `docs/ingestion/ING-003-Enrichment-Routing-and-Persistence.md`.

- **Security Engine integration**

  - Normalization and serving stages emit `event.security.*.v1` events and accept `cmd.security.*.v1` commands via `/v1/security/actions`, with status callbacks via `event.security.action_status.v1`.
  - JSON Schemas for these contracts live under `schemas/events/`.
  - Integration details live under `docs/integrations/` and `docs/security-engine/`.

## Repository layout and major components

Focus on these high-leverage areas instead of listing every directory:

- `services/` – Lambda, ECS, Glue, and Step Functions workloads implementing the ingest/normalize/embed/api/batch services. Each service should follow a `src/` plus `tests/` structure (see `docs/Project Instructions.md`).
- `libs/python/` – Shared Python 3.11 libraries (logging, tracing, auth, error handling, contract helpers) with tests in `libs/python/tests/`.
- `schemas/`:
  - `schemas/openapi/` and root `openapi.yaml` – HTTP API contracts.
  - `schemas/events/` – event and command contracts (for example `event.security.finding.v1.json`, `cmd.security.quarantine.v1.json`, `event.security.action_status.v1.json`) plus examples.
- `docs/` – Primary design and governance source:
  - Architecture and system design (`docs/architecture.md`, `docs/System-Architecture-Blueprint.md`, ADRs in `docs/adr/`).
  - Pipeline specs (`docs/ingestion/`, `docs/serving/serving-contracts/`, `docs/lineage/`).
  - Security controls and threat model (`docs/security-controls/`).
  - Governance and standards (`docs/governance/REF-001-Glossary-and-Standards-Catalog.md`).
  - Integrations catalog (`docs/integrations/README.md` and linked integration specs).
- `iac/` – Terraform and Terragrunt stacks and modules for VPC, S3 buckets, queues, ECS or Fargate services, Lambdas, Weaviate, OpenSearch Serverless, observability, and backup primitives.
- `ops/` – Operational artifacts:
  - `ops/dashboards/` and `ops/alerts/` for Grafana and CloudWatch.
  - `ops/owners.yaml` mapping components to owning teams and used in PR review routing.
- `.github/workflows/` – CI pipelines:
  - `lint.yml` – Spectral OpenAPI lint and link checking via Lychee.
  - `openapi-lint.yml` – OpenAPI-specific Spectral lint on `openapi.yaml` and event schemas.
- Root files:
  - `AGENTS.md` – repo-specific automation and validation guidance.
  - `agents.yaml` – machine-readable policy for automation, validation commands, approvals, and CI requirements.
  - `Makefile` – main local entrypoints for formatting, linting, and testing.
  - `.spectral.yaml`, `.yamllint.yaml`, and other linter configs.

## Development workflow and commands

Use `make` as the primary entrypoint. Always inspect the current `Makefile` before relying on a target.

### Formatting and linting

- `make fmt`:

  - Runs `ruff --fix .`, `isort .`, and `black .` over the repo.
  - Use before committing any Python changes.

- `make lint`:

  - Runs `markdownlint docs AGENTS.md`, `yamllint .`, `ruff .`, `isort --check-only .`, and `black --check .`.
  - Mirrors the local portion of CI lint. Spectral and HTTP link checks run in GitHub Actions.

- Spectral and OpenAPI lint:

  - CI runs Spectral via:
    - `.github/workflows/lint.yml` using `spectral lint -r spectral:oas openapi.yaml`.
    - `.github/workflows/openapi-lint.yml` using `spectral lint openapi.yaml --fail-severity=warn`.
  - `agents.yaml` intentionally configures `validation.openapi.command` as an echo placeholder.  
    - When running inside a hosted sandbox (for example, Codex), do not install Spectral or perform networked checks by default; rely on CI and treat OpenAPI lint as deferred unless explicitly requested.  
    - When running locally on your own machine (for example, in Warp), you may install and run Spectral as needed to mirror CI behavior.

### Testing

- `make test`:

  - Creates `reports/` and runs `pytest` against the Python sources (`services` and `libs/python`) with coverage and JUnit XML reporting.
  - Coverage is written to `reports/coverage.xml`; JUnit output to `reports/junit.xml`.

- Testing expectations (see `AGENTS.md` and `docs/Project Instructions.md`):

  - Pytest is the test runner for unit and contract suites.
  - Tests live alongside services (`services/**/tests/`) and in `libs/python/tests/`.
  - Maintain at least 80 percent line coverage. Canonical command pattern:

    - `pytest --junitxml=reports/junit.xml --cov=src --cov-report=xml --cov-fail-under=80`.

- Running a single test:

  - All tests in one file:
    - `pytest services/<service>/tests/test_<feature>.py`.
  - A single test function:
    - `pytest services/<service>/tests/test_<feature>.py::test_name`.
  - For libs:
    - `pytest libs/python/<pkg>/tests/test_<feature>.py::test_name`.
  - `-k substring` can be used for filtered runs, keeping paths within `services/` and `libs/python/`.

### Additional targets and commands described in docs

`docs/Project Instructions.md` describes a richer Makefile surface:

- `make init` – bootstrap development environment (Poetry, Node tooling, pre-commit hooks).
- `make build` – container build and dependency scan.
- `make deploy-dev` – deploy preview stack to a dev environment.
- `make e2e`, `make loadgen`, `make eval` – end-to-end tests, synthetic load, and relevance evaluation.

These targets may not all be implemented in the current root `Makefile`. When referencing them:

- Inspect `Makefile` (and any included makefiles) to confirm they exist.
- If they are absent, describe them as planned or documented targets and either:
  - Fall back to `make fmt`, `make lint`, and `make test`, or
  - Propose concrete underlying commands instead of assuming the higher-level targets.

## Documentation, contracts, and governance

Use the docs and schemas in this repo as the primary source of truth. WARP should point users at them rather than duplicating content.

- **Standards and naming** – `docs/governance/REF-001-Glossary-and-Standards-Catalog.md`:

  - Repositories and paths use kebab-case and avoid spaces, ampersands, and em dashes for code/config artifacts.
  - Board-level and spec documents under `docs/**` follow `AREA-NNN Title.md` naming and required front matter as defined in REF-001.
  - APIs: JSON over HTTPS; version in the path (for example `/v1/...`); RFC 7807 error format; idempotency with an `Idempotency-Key` header.

- **Data and API contracts**:

  - HTTP API contracts live in `openapi.yaml` and `schemas/openapi/`. Treat OpenAPI as the canonical interface definition.
  - Event and command contracts live in `schemas/events/**` and are versioned (`*.v1.json`, etc.). Breaking changes require new versions plus any necessary migrators.
  - Contract and schema updates should be paired with updates to:
    - Examples under `schemas/events/examples/`.
    - Relevant specs (for example `docs/ingestion/`, `docs/serving/serving-contracts/`, `docs/security-engine/`).

- **Architecture and ADRs**:

  - High-level system design is captured in `docs/architecture.md` and `docs/System-Architecture-Blueprint.md`.
  - Architectural decisions (AWS-native stack, Weaviate, OpenSearch Serverless, multi-account topology, and similar) are documented in ADRs under `docs/adr/` (for example `ADR-001-Architecture-Baseline`).
  - When proposing structural changes, cross-check and update the corresponding ADRs and references in `docs/architecture.md`.

- **Integrations and serving contracts**:

  - Cross-product integrations (including the Security Engine and other modules) are cataloged in `docs/integrations/README.md`. Add new integration details there rather than embedding them ad hoc into core docs.
  - Serving contracts for online and offline flows are indexed in `docs/serving/serving-contracts/README.md` and the linked `SVC-*` specs.

## Automation, CI/CD, and sandbox constraints

Automation behavior is governed by `AGENTS.md` and `agents.yaml`. WARP should respect these policies.

- **Automation scope** from `agents.yaml`:

  - Automation is explicitly scoped to `docs/**`, `schemas/**`, `ops/**`, `iac/**`, `openapi.yaml`, and `.spectral.yaml`.
  - Sensitive paths are excluded: anything under `**/.env`, files matching `*secrets*`, and anything under `.aws/`.

- **Filename and content rules**:

  - For code, config, and non-spec artifacts, filenames must be kebab-case and avoid spaces, ampersands, and em dashes. Enforcement commands (for example ripgrep checks) are defined in `agents.yaml` and `AGENTS.md`.
  - Governance and spec documents under `docs/**` follow the `AREA-NNN Title.md` naming and front-matter rules from REF-001.
  - Certain partner names are treated as banned terms except within `docs/integrations/**`. Consult `agents.yaml` before introducing new references.
  - Markdown specs require front matter, naming, and style per REF-001. Prefer updating existing specs over introducing new ad hoc design notes.

- **Security Engine contracts**:

  - `agents.yaml` asserts specific event and command schema files under `schemas/events/` for the Security Engine interface. Keep schemas and docs in sync when editing these.

- **Validation commands and hosted sandboxes**:

  - `agents.yaml` defines `validation.*` commands.  
    - In hosted sandbox environments (for example, Codex), OpenAPI and link checks may be configured as echo-only placeholders; do not attempt to run heavy networked tooling there unless explicitly requested.  
    - In your own local environment (Warp, dev laptop, CI runners), you can run the full validation commands defined in `agents.yaml` and the Makefile.

- **Approvals and forbidden operations**:

  - Certain actions require explicit approval:
    - Any deletion.
    - Changes under `.github/workflows/**` (CI configuration).
    - Operations involving merges to `main`, rebases, or force pushes.
  - Operations touching secrets or `.aws/**` are forbidden for automation.
  - WARP should not create commits, merge branches, or alter CI workflows unless the user explicitly asks and understands the impact.

- **CI expectations**:

  - CI runs Spectral, markdownlint, and Lychee link checks. Keep `.github/workflows/lint.yml` and `.github/workflows/openapi-lint.yml` green.
  - PRs should show evidence of `make fmt && make lint && make test` and follow commit naming conventions (`type: scope` with ticket IDs) as described in `AGENTS.md`.
  - Ownership and review routing should respect `ops/owners.yaml`.

## How WARP should behave in this repository

- Treat `AGENTS.md`, `agents.yaml`, `docs/architecture.md`, `docs/System-Architecture-Blueprint.md`, `docs/governance/REF-001-Glossary-and-Standards-Catalog.md`, and the relevant specs (`ING-003`, `LIN-001`, `SEC-001`, serving contracts) as canonical context before proposing structural changes to code, contracts, or infrastructure.
- When editing:

  - **Python code** – follow the Black, isort, and ruff configuration enforced by `make fmt` and `make lint`. Use type hints and Pydantic models for IO as described in `docs/Project Instructions.md`.
  - **Schemas and OpenAPI** – keep JSON Schema and OpenAPI aligned. Rely on CI Spectral lint. Avoid breaking changes without version bumps and migrators.
  - **Docs** – enforce front matter, naming, and style per REF-001 and `agents.yaml`. Prefer updating existing specs over adding new ones.

- Prefer `make fmt`, `make lint`, and `make test` as the default pre-commit checks you recommend or run.  
- Avoid heavy networked tools only when you are constrained to a hosted sandbox (for example, Codex). In your own local environment, use the full toolchain as defined in this repo.  
- When in doubt about changes touching security, IAM, data contracts, or cross-service behavior, reference the relevant spec or ADR and indicate which documents and schemas must be updated alongside the code.
