TEST-002 Continuous Integration & Test Automation

  

  

  

Status

  

  

Accepted

  

  

Date

  

  

2025-10-24

  

  

Context

  

  

Neurocipher Pipeline and AuditHound depend on deterministic, repeatable builds and rapid feedback to maintain release confidence. Manual validation is insufficient at current code velocity. A unified Continuous Integration (CI) pipeline is required to ensure:

  

- Automated execution of all test suites (unit, integration, security, performance).
- Consistent build artifact generation across environments.
- Enforcement of quality gates before merge or deployment.

  

  

The pipeline must integrate directly with GitHub Actions and AWS CodeBuild for hybrid workflows.

  

  

  

  

Decision

  

  

Adopt a fully automated CI/CD test pipeline with the following characteristics:

  

1. Triggering  
    

- On every push, pull_request, and scheduled nightly build.
- Separate workflows for feature, staging, and production branches.

3.   
    
4. Automation Layers  
    

- Unit Tests: Executed via pytest or unittest, producing JUnit XML results.
- Integration Tests: Run in ephemeral containers using docker-compose within GitHub Actions.
- Static Analysis: Run ruff, bandit, and mypy for lint, security, and typing.
- Code Coverage: Measured with coverage.py; threshold ≥ 85%.
- Artifact Build: Docker image built and pushed to AWS ECR on successful tests.
- Notifications: Failures broadcast to Slack / Teams via webhook.

6.   
    
7. Environment Consistency  
    

- Base image pinned (python:3.11-slim) to avoid drift.
- Secrets managed via GitHub Secrets and AWS Secrets Manager.
- Test data isolated in temporary S3 buckets with automatic teardown.

9.   
    
10. Performance & Load Hooks  
    

- pytest-benchmark integrated into nightly workflow.
- Thresholds feed metrics into CloudWatch for trend tracking.

12.   
    

  

  

  

  

  

Rationale

  

  

Automated CI testing enforces quality and prevents regression.

Hybrid orchestration between GitHub Actions and AWS CodeBuild gives elasticity and parallelism without vendor lock-in.

The defined coverage and linting thresholds guarantee baseline maintainability and security posture.

  

  

  

  

Implementation

  

  

1. Workflow Definition  
    

- File: .github/workflows/ci.yml
- Key Jobs: lint, unit_tests, integration_tests, build_and_push.

3.   
    
4. Example Snippet

  

name: CI Pipeline

on: [push, pull_request]

jobs:

  test:

    runs-on: ubuntu-latest

    steps:

      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5

        with: { python-version: '3.11' }

      - run: pip install -r requirements.txt

      - run: pytest --junitxml=reports/junit.xml --cov=src --cov-report=xml

      - run: ruff check .

      - run: bandit -r src/

      - run: mypy src/

      - run: docker build -t neurocipher/app:${{ github.sha }} .

  

2.   
    
3. Quality Gate Enforcement  
    

- PR merge blocked if coverage < 85 % or any test fails.
- Build must pass vulnerability scan before ECR push.

5.   
    
6. Reporting  
    

- Results aggregated in CodeBuild reports and uploaded to S3.
- Slack notifications via GitHub Actions workflow event.

8.   
    

  

  

  

  

  

References

  

  

- ADR-008 Testing & Quality Gates
- AWS CodeBuild Docs – Report Groups
- GitHub Actions Workflow Syntax v3
- OWASP CI/CD Security Best Practices