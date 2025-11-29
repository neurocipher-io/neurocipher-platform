# GOV-MIG-001 Monorepo Migration Checklist

Status: Draft for review  
Owner: Architecture  
Last updated: 2025-11-26  

## 1. Purpose

This document defines the required steps and checks to migrate the existing
`neurocipher-data-pipeline` repository into the `neurocipher-platform`
monorepo structure without breaking builds, tests, or deployment workflows.

## 2. Pre-migration checks

- [ ] CI is green on the current repository layout.
- [ ] All default branches and environments are identified.
- [ ] All existing paths referenced in:
  - [ ] GitHub Actions workflows.
  - [ ] Makefiles.
  - [ ] Dockerfiles and docker-compose files (if any).
  - [ ] Test configuration (pytest, coverage, etc.).
  - [ ] Local development scripts.
- [ ] A backup of the repository (branch or tag) is created:
  - [ ] `git tag monorepo-pre-migration` or equivalent.

## 3. Repository rename

- [ ] GitHub repository renamed from `neurocipher-data-pipeline` to `neurocipher-platform`.
- [ ] Local remotes updated:
  - [ ] `git remote set-url origin git@github.com:neurocipher-io/neurocipher-platform.git`
- [ ] `README.md` updated to:
  - [ ] State that this is the monorepo for the Neurocipher platform.
  - [ ] Explain that the data pipeline is currently the primary implemented module.

## 4. Documentation structure creation

- [ ] Create documentation directories:
  - [ ] `docs/governance/`
  - [ ] `docs/product/`
  - [ ] `docs/architecture/`
  - [ ] `docs/data-models/`
  - [ ] `docs/ingestion/`
  - [ ] `docs/services/`
  - [ ] `docs/security-controls/`
  - [ ] `docs/ai/`
  - [ ] `docs/observability/`
  - [ ] `docs/runbooks/`
- [ ] Move existing documentation into appropriate directories:
  - [ ] `REF-001-*` → `docs/governance/`
  - [ ] Data model docs (DM-*) → `docs/data-models/`
  - [ ] Ingestion docs (ING-*) → `docs/ingestion/`
  - [ ] Security docs (SEC-*) → `docs/security-controls/`
  - [ ] MCP / governance / observability docs → correct subfolders.
  - [x] `System-Architecture-Blueprint.md` → `docs/architecture/` (completed).

- [ ] Add and commit `GOV-ARCH-001-Architecture-Documentation-Index.md`.

## 5. Introduce services/ layout

- [ ] Create `services/` directory:
  - [ ] `mkdir -p services/nc-data-pipeline`
- [ ] Move pipeline code into `services/nc-data-pipeline/`:
  - [ ] `migrations/` → `services/nc-data-pipeline/migrations/`
  - [ ] `schemas/` → `services/nc-data-pipeline/schemas/`
  - [ ] `tests/` → `services/nc-data-pipeline/tests/`
  - [ ] `openapi.yaml` → `services/nc-data-pipeline/openapi.yaml`
  - [ ] `Makefile` → `services/nc-data-pipeline/Makefile`
- [ ] Create a new root-level `Makefile` that delegates:
  - [ ] `make fmt` → `make -C services/nc-data-pipeline fmt`
  - [ ] `make lint` → `make -C services/nc-data-pipeline lint`
  - [ ] `make test` → `make -C services/nc-data-pipeline test`

## 6. Update CI and tooling

- [ ] Update all GitHub Actions workflows:
  - [ ] Paths to tests, migrations, and schemas reflect `services/nc-data-pipeline/`.
  - [ ] Any `working-directory` settings updated.
- [ ] Update any Docker build contexts and paths:
  - [ ] Ensure Dockerfiles refer to new locations.
- [ ] Update references in:
  - [ ] `AGENTS.md` or agent configuration files.
  - [ ] `WARP.md` if it references old paths.

## 7. Post-migration validation

- [ ] Run `make fmt` at repo root.
- [ ] Run `make lint` at repo root.
- [ ] Run `make test` at repo root.
- [ ] Ensure CI is green with the new layout.
- [ ] Validate manual smoke tests:
  - [ ] `make db_local_up` still works.
  - [ ] `make db_local_migrate` still works.
  - [ ] `make db_local_smoke_test` still works.

## 8. Acceptance criteria

The migration is considered complete when:

- CI pipelines pass using the new structure.
- Local developer commands behave as before.
- All documentation links in `README.md` and `GOV-ARCH-001` resolve correctly.
- There is a clear path to add new services under `services/` without further
  restructuring.