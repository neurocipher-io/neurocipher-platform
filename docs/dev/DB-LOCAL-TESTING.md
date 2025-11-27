---
id: DB-LOCAL-TESTING
title: Local Database Testing Guide
owner: data-team
status: active
last_reviewed: 2025-11-21
---

# Local Database Testing Guide

This guide describes how to run local smoke tests for the Neurocipher data pipeline database schema, focusing on multi-tenant RLS (Row-Level Security) behavior and the scan → finding → ticket chain.

## Overview

The local smoke test harness validates:

1. **Multi-tenant isolation** via `app.account_id` session variable
2. **RLS policies** enforce visibility rules based on tenant context
3. **Scan → Finding → Ticket chain** integrity and relationships
4. **Data visibility** with correct tenant context (one row per table)
5. **Data invisibility** with wrong tenant context (zero rows)
6. **Data invisibility** with null tenant context (zero rows)

## Prerequisites

### Required Software

- **Docker** (for running local Postgres 15 container)
- **Python 3.9+** with pip
- **Make** (for running Makefile targets)

### Environment Setup

The test harness uses environment variables with sensible defaults:

| Variable          | Default      | Description                           |
|-------------------|--------------|---------------------------------------|
| `NC_DB_HOST`      | `localhost`  | Database host                         |
| `NC_DB_PORT`      | `5432`       | Database port                         |
| `NC_DB_NAME`      | `nc_dev`     | Database name                         |
| `NC_DB_USER`      | `nc_app_rw`  | Application role with RLS enforcement |
| `NC_DB_PASSWORD`  | `nc_app_rw`  | Password for nc_app_rw role           |
| `NC_DB_LOCAL_TEST`| `0`          | Set to `1` to enable tests            |

## Running the Smoke Tests

### Quick Start

Run the complete smoke test suite with a single command:

```bash
NC_DB_LOCAL_TEST=1 make db_local_smoke_test
```

This command will:

1. Start the local Postgres container (`db_local_up`)
2. Apply all migrations including role creation (`db_local_migrate`)
3. Install Python test dependencies if needed (`db_test_deps`)
4. Run the pytest suite for RLS and scan chain validation

### Step-by-Step Execution

For more control, you can run each step separately:

```bash
# 1. Start the local Postgres container
make db_local_up

# 2. Apply migrations (creates nc schema, tables, and nc_app_rw role)
make db_local_migrate

# 3. Install Python dependencies
pip install -r tests/requirements.txt

# 4. Run the smoke tests
NC_DB_LOCAL_TEST=1 pytest tests/db/test_rls_scan_chain.py -v
```

### Expected Output

When tests pass, you should see output similar to:

```
tests/db/test_rls_scan_chain.py::TestRLSScanChain::test_tenant_isolation_with_correct_account PASSED
tests/db/test_rls_scan_chain.py::TestRLSScanChain::test_tenant_isolation_with_wrong_account PASSED
tests/db/test_rls_scan_chain.py::TestRLSScanChain::test_tenant_isolation_with_null_account PASSED
tests/db/test_rls_scan_chain.py::TestRLSScanChain::test_scan_finding_chain_integrity PASSED

======================== 4 passed in 2.34s ========================
```

## Test Structure

### Test Files

```
tests/
├── db/
│   ├── sql/
│   │   └── scan_finding_chain_smoke.sql    # SQL fixture with test data
│   └── test_rls_scan_chain.py              # pytest test suite
└── requirements.txt                         # Python dependencies
```

### Test Cases

#### 1. `test_tenant_isolation_with_correct_account`

Validates that when `app.account_id` is set to `acct_scan_1`, exactly one row is visible in each tenant-scoped table:

- `nc.scan`
- `nc.policy`
- `nc.finding`
- `nc.evidence`
- `nc.remediation`
- `nc.ticket`
- `nc.integration`
- `nc.notification`
- `nc.asset`

#### 2. `test_tenant_isolation_with_wrong_account`

Validates that when `app.account_id` is set to `acct_other` (different tenant), zero rows are visible in all tenant-scoped tables.

#### 3. `test_tenant_isolation_with_null_account`

Validates that when `app.account_id` is null (via `RESET app.account_id`), zero rows are visible in all tenant-scoped tables.

#### 4. `test_scan_finding_chain_integrity`

Validates the complete chain:

```
scan_001 → find_001 → evidence_001
                    → remediation_001
                    → ticket_001
```

Also verifies that all foreign key relationships are intact.

## Database Schema

### Application Role: nc_app_rw

The `nc_app_rw` role is created by migration `0003_nc_app_role.sql` with:

- `LOGIN` capability with password `nc_app_rw`
- `USAGE` on `nc` schema
- `SELECT`, `INSERT`, `UPDATE`, `DELETE` on all tables
- `EXECUTE` on all functions and procedures
- Default privileges for future objects

### RLS Enforcement

All tenant-scoped tables have:

1. **RLS enabled**: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
2. **Tenant policy**: `CREATE POLICY ... USING (account_id = nc.current_account_id())`
3. **Tenant guard trigger**: `trg_tenant_guard` that calls `nc.enforce_tenant_context()`

The `nc.current_account_id()` function returns:

```sql
SELECT current_setting('app.account_id', true)
```

## Troubleshooting

### Tests are Skipped

If you see:

```
tests/db/test_rls_scan_chain.py::TestRLSScanChain SKIPPED
```

**Solution**: Set `NC_DB_LOCAL_TEST=1` environment variable.

### Connection Refused

If you see:

```
psycopg2.OperationalError: could not connect to server
```

**Solution**: Ensure the Postgres container is running:

```bash
docker ps | grep nc-pg-local
make db_local_up
```

### Permission Denied

If you see:

```
ERROR:  permission denied for schema nc
```

**Solution**: Ensure migrations have been applied (especially `0003_nc_app_role.sql`):

```bash
make db_local_migrate
```

### Role nc_app_rw Does Not Exist

If you see:

```
FATAL:  role "nc_app_rw" does not exist
```

**Solution**: Migration `0003_nc_app_role.sql` creates the role. Re-run migrations:

```bash
make db_local_migrate
```

## Cleanup

To stop the local Postgres container:

```bash
make db_local_down
```

To remove the container entirely:

```bash
docker rm -f nc-pg-local
```

## CI/CD Integration

The smoke tests are **not** automatically run in CI by default. They require:

- Docker daemon available
- Local Postgres container running
- `NC_DB_LOCAL_TEST=1` environment variable

To enable in CI, add these steps to your pipeline:

```yaml
- name: Run DB Smoke Tests
  run: |
    NC_DB_LOCAL_TEST=1 make db_local_smoke_test
```

## References

- [DM-003 Physical Schemas and Storage Map](../data-models/DM-003-Physical-Schemas-and-Storage-Map.md)
- Migrations: `/migrations/postgres/` (0001_nc_core_metadata.sql, 0002_nc_security_and_finding_chain.sql, 0003_nc_app_role.sql)
- [Pytest Documentation](https://docs.pytest.org/)
