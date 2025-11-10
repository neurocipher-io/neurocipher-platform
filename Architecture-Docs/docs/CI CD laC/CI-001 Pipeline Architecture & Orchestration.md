Understood. All future docs use this structure. Nexis references removed.

  

  

CI/CL-001 — Continuous Integration Platform and Workflow Specification

  

  

Status: Draft for review

Owners: Release Engineering, QA Lead, Security Lead

Applies to: Neurocipher and AuditHound repositories under the neurocipher organization

Default region: ca-central-1

  

  

1. Objective

  

  

Provide a deterministic CI system with enforced quality gates, supply chain controls, and reproducible build artifacts that downstream CD trusts.

  

  

2. Scope

  

  

- Languages: Python 3.12, Node 20, Bash.
- Targets: containerized services, Python libraries, Terraform IaC, OpenAPI specs, event schemas.
- Out of scope: mobile clients and desktop apps.

  

  

  

3. Platforms and identity

  

  

- VCS: GitHub. Default branch: main.
- CI: GitHub Actions with reusable workflows.
- Runners: ubuntu-latest. Optional self-hosted GPU for model jobs.
- Cloud identity: GitHub OIDC to AWS. No long-lived cloud keys in CI.
- Job permissions scoped to least privilege.

  

  

  

4. Repository taxonomy and path filters

  

  

- services/* dockerized services.
- libs/python/* Python packages.
- iac/* Terraform modules and stacks.
- schemas/{openapi,events}/* API and event contracts.
- ops/* runbooks and dashboards.  
    Path filters ensure jobs run only when impacted.

  

  

  

5. Triggers and concurrency

  

  

- pull_request to main.
- push to any branch.
- release on tags v*.
- workflow_dispatch for ad hoc runs.
- schedule nightly 02:00 ET for security scans.
- Concurrency: cancel in progress on same ref for non-release jobs.

  

  

  

6. Branching, versioning, and change control

  

  

- Trunk based with short-lived feature branches.
- SemVer via annotated tags vMAJOR.MINOR.PATCH.
- Conventional Commits drive changelog.
- Protected branch checks required before merge to main.

  

  

  

7. Quality gates

  

  

Any failure blocks merge and deploys.

  

- Lint: zero errors.
- Type check: zero errors.
- Unit test coverage: lines ≥ 85 percent and branches ≥ 80 percent.
- Secrets scan: zero findings.
- SAST: no critical or high vulnerabilities.
- Container scan: no critical or high vulnerabilities.
- IaC scan: no critical or high misconfigurations.
- License policy: allowed list only.
- Contract checks: no unapproved breaking changes.
- SBOM and provenance required for all builds.

  

  

  

8. Toolchain and pinned versions

  

  

- Python 3.12 with Poetry, Ruff, Black, MyPy, Pytest, Coverage.py.
- Node 20 with Biome or ESLint if JS present.
- Shell: ShellCheck, shfmt.
- YAML: yamllint.
- SAST: CodeQL. Optional Semgrep for policy gaps.
- Secrets: Gitleaks.
- Containers: Docker Buildx. Trivy for fs and image scanning.
- IaC: Terraform, TFLint, Checkov or tfsec.
- Contracts: Spectral, openapi-diff, event schema diff.
- SBOM: Syft SPDX JSON.
- Provenance and signing: Cosign keyless with OIDC and SLSA provenance.

  

  

  

9. CI stages and order

  

  

10. Setup  
    

- Checkout full history.
- Detect project type by paths.
- Restore caches keyed by lockfiles.

3.   
    
4. Static checks  
    

- Ruff, Black check, MyPy.
- ShellCheck, yamllint.
- Fail on any error.

6.   
    
7. Unit tests  
    

- Pytest with coverage XML and JUnit.
- Enforce coverage gates.
- Upload reports for PR annotations.

9.   
    
10. Build  
    

- Python: wheels and sdist.
- Services: Docker Buildx for linux/amd64.
- Tag image repo:sha and repo:pr-<num> on PRs.

12.   
    
13. Security and compliance  
    

- Gitleaks.
- CodeQL init and analyze.
- Trivy filesystem and image.
- Checkov or tfsec on iac/*.
- OSS license scan with ORT or Licensee.

15.   
    
16. Contracts  
    

- Spectral lint on OpenAPI.
- Backward compatibility diff vs main.
- Event schema compatibility diff.
- Breaking change requires breaking-change: true label and CODEOWNER approval.

18.   
    
19. Supply chain  
    

- Syft SBOM SPDX JSON.
- Cosign attestations.
- SLSA provenance for containers and packages.

21.   
    
22. Artifacts and publishing  
    

- Upload wheels, sbom, sarif, coverage.xml, junit, provenance, image digest.
- On release: push images to ECR, wheels to internal index, mirror artifacts to S3 with KMS.

24.   
    

  

  

  

25. Required checks on 

main

  

  

lint, types, unit-tests, coverage-threshold, codeql, trivy, gitleaks, iac-scan, contract-checks, sbom-provenance.

At least one CODEOWNER review for iac/, schemas/, security/.

  

  

11. Matrix and caching policy

  

  

- Python matrix default ["3.12"]. Add versions only when required.
- Limit matrix width to control cost.
- Caches: Poetry and pip by lock hash, Docker layers by digest, Terraform plugin cache.
- Cache TTL 7 days. Nightly warm-up job.

  

  

  

12. Timeouts and resource classes

  

  

- Lint and unit: 10 minutes.
- Build and scan: 20 minutes.
- CodeQL: 45 minutes.
- Jobs fail on timeout.

  

  

  

13. Flaky test policy

  

  

- Quarantine tag @flaky.
- Quarantined tests run but do not gate merge.
- Ticket required to remove from quarantine within 14 days.

  

  

  

14. Documentation and PR hygiene

  

  

- PR template requires risk notes, test evidence, and contract summary.
- Auto-changelog from Conventional Commits.
- Coverage and scan summaries posted to PR.

  

  

  

15. Notifications and tickets

  

  

- On failing gate, create issue with labels ci-fail and component.
- Security findings auto-issue with severity and remediation owner.

  

  

  

16. Artifact retention and backup

  

  

- GitHub artifacts: 30 days branches, 365 days releases.
- S3 mirror: 180 days Standard-IA then 2 years Glacier. KMS CMK.
- Hashes and provenance stored with artifacts.

  

  

  

17. Compliance mapping

  

  

- ADR-008: gates 7 to 9.
- ADR-009: cache reuse, matrix limits, nightly consolidation.
- ADR-010: artifact mirroring and retention for recovery.

  

  

  

18. Local parity for developers

  

  

- Pre-commit with Ruff, Black, MyPy, Gitleaks.
- make test for unit tests with coverage.
- make contract-check for Spectral and diffs.
- Dockerfile builds locally with Buildx parity target.

  

  

  

19. Example reusable workflows

  

  

.github/workflows/ci.yml

name: CI

on:

  pull_request:

  push:

    branches: [ main ]

concurrency:

  group: ${{ github.workflow }}-${{ github.ref }}

  cancel-in-progress: true

jobs:

  ci:

    uses: neurocipher-org/.github/.github/workflows/reusable_ci.yml@main

    with:

      coverage_min_lines: '0.85'

      coverage_min_branches: '0.80'

      trivy_fail_on: 'HIGH,CRITICAL'

      path_filters: |

        services/ingest/**

        libs/python/common/**

        iac/**

        schemas/**

    secrets: inherit

reusable_ci.yml core

name: Reusable CI

on:

  workflow_call:

    inputs:

      coverage_min_lines: { type: string, default: '0.85' }

      coverage_min_branches: { type: string, default: '0.80' }

      trivy_fail_on: { type: string, default: 'HIGH,CRITICAL' }

      path_filters: { type: string, required: false }

jobs:

  detect:

    runs-on: ubuntu-latest

    outputs:

      changed: ${{ steps.filter.outputs.changes }}

    steps:

      - uses: actions/checkout@v4

      - id: filter

        uses: dorny/paths-filter@v3

        with:

          filters: ${{ inputs.path_filters }}

  lint_types_tests:

    if: ${{ needs.detect.outputs.changed != '[]' }}

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5

        with: { python-version: '3.12' }

      - run: pipx install poetry

      - run: poetry install --no-interaction --no-root

      - run: poetry run ruff check .

      - run: poetry run black --check .

      - run: poetry run mypy .

      - run: poetry run pytest --junitxml=junit.xml --cov --cov-report=xml

      - name: Enforce coverage

        run: python - <<'PY'

import sys,xml.etree.ElementTree as ET

r=ET.parse('coverage.xml').getroot().attrib

lines=float(r['lines-covered'])/float(r['lines-valid'])

branches=float(r.get('branches-covered','0'))/float(r.get('branches-valid','1'))

ok = lines>=float('${{ inputs.coverage_min_lines }}') and branches>=float('${{ inputs.coverage_min_branches }}')

print(f'lines={lines:.3f} branches={branches:.3f}')

sys.exit(0 if ok else 1)

PY

      - uses: actions/upload-artifact@v4

        with: { name: unit-artifacts, path: |

          junit.xml

          coverage.xml

        }

  sast_supplychain:

    needs: lint_types_tests

    runs-on: ubuntu-latest

    permissions: { security-events: write }

    steps:

      - uses: actions/checkout@v4

      - uses: gitleaks/gitleaks-action@v2

      - uses: github/codeql-action/init@v3

        with: { languages: python }

      - uses: github/codeql-action/analyze@v3

      - uses: aquasecurity/trivy-action@0.20.0

        with:

          scan-type: fs

          format: sarif

          output: trivy.sarif

          severity: ${{ inputs.trivy_fail_on }}

      - uses: anchore/sbom-action@v0

        with:

          path: .

          format: spdx-json

          output-file: sbom.spdx.json

      - uses: actions/upload-artifact@v4

        with: { name: security-artifacts, path: |

          trivy.sarif

          sbom.spdx.json

        }

  contracts:

    needs: lint_types_tests

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

        with: { fetch-depth: 0 }

      - name: Spectral

        run: npx -y @stoplight/spectral-cli lint schemas/openapi/**/*.yaml

      - name: OpenAPI compatibility

        run: npx -y openapi-diff ./schemas/openapi/current.yaml origin/main:schemas/openapi/current.yaml

      - name: Event schema compatibility

        run: ./scripts/schema_diff.sh

  

20. Security controls in CI

  

  

- Restrict egress to required endpoints.
- Enforce base images by digest.
- Disallow latest tags in Dockerfiles.
- Prevent credentials in logs.
- Mandatory review on security/, iac/, schemas/ paths.

  

  

  

21. KPIs

  

  

- Median CI duration per PR under 12 minutes.
- Flaky test rate under 2 percent.
- Time to fix failed main under 2 hours.
- Security SLA: critical within 24 hours, high within 3 days.

  

  

  

22. Incident handling

  

  

- Red main freezes deploys.
- On-call owner triages and links issues.
- Hotfix branches allowed with the same gates.

  

  

  

23. Acceptance criteria

  

  

- All jobs green on sample PRs in services/*, libs/*, iac/*, schemas/*.
- Protected branch rules enabled and verified.
- Artifacts mirrored to S3 and decryptable with KMS policy.
- Reproducible build confirmed by digest match on re-run