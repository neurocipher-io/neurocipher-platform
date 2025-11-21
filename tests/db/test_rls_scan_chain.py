"""
test_rls_scan_chain.py

Local smoke tests for multi-tenant RLS behavior and the scan → finding → ticket chain.
Tests validate:
1. Tenant isolation via app.account_id (RLS policies)
2. Data visibility with correct tenant context
3. Data invisibility with wrong or null tenant context

Run with: NC_DB_LOCAL_TEST=1 pytest tests/db/test_rls_scan_chain.py
"""

import os
from pathlib import Path

import psycopg2
import pytest


def should_run_db_tests():
    """Check if database tests should run based on environment variable."""
    return os.environ.get("NC_DB_LOCAL_TEST", "0") == "1"


@pytest.fixture(scope="module")
def db_config():
    """Database connection configuration from environment variables."""
    return {
        "host": os.environ.get("NC_DB_HOST", "localhost"),
        "port": int(os.environ.get("NC_DB_PORT", "5432")),
        "dbname": os.environ.get("NC_DB_NAME", "nc_dev"),
        "user": os.environ.get("NC_DB_USER", "nc_app_rw"),
        "password": os.environ.get("NC_DB_PASSWORD", "nc_app_rw"),
    }


@pytest.fixture(scope="module")
def db_connection(db_config):
    """Create a database connection for the test module."""
    if not should_run_db_tests():
        pytest.skip("NC_DB_LOCAL_TEST not set to 1, skipping DB tests")

    conn = psycopg2.connect(**db_config)
    conn.autocommit = False
    yield conn
    conn.close()


@pytest.fixture(scope="module")
def setup_test_data(db_connection):
    """Load test data from SQL fixture file."""
    sql_file = Path(__file__).parent / "sql" / "scan_finding_chain_smoke.sql"

    with db_connection.cursor() as cur:
        # Set tenant context before inserting data
        cur.execute("SET SESSION app.account_id = 'acct_scan_1'")

        # Read and execute the SQL fixture
        with open(sql_file, "r") as f:
            sql_content = f.read()
            cur.execute(sql_content)

        db_connection.commit()

    yield

    # Cleanup: Delete all test data
    with db_connection.cursor() as cur:
        # Set tenant context for cleanup
        cur.execute("SET SESSION app.account_id = 'acct_scan_1'")

        # Delete in reverse order of dependencies
        cur.execute("DELETE FROM nc.notification WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.integration WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.ticket WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.remediation WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.evidence WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.finding WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.asset WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.scan WHERE account_id = 'acct_scan_1'")
        cur.execute("DELETE FROM nc.policy WHERE account_id = 'acct_scan_1'")

        # Control is not tenant-scoped, but delete it if exists
        cur.execute("RESET app.account_id")
        cur.execute("DELETE FROM nc.control WHERE id = 'ctrl_001'")

        # Delete account (must be done without tenant context set)
        cur.execute("DELETE FROM nc.account WHERE id = 'acct_scan_1'")

        db_connection.commit()


def count_rows(cursor, table_name):
    """Helper to count rows in a table with current tenant context."""
    # Whitelist of allowed table names to prevent SQL injection
    allowed_tables = {
        "scan",
        "policy",
        "finding",
        "evidence",
        "remediation",
        "ticket",
        "integration",
        "notification",
        "asset",
    }

    if table_name not in allowed_tables:
        raise ValueError(f"Invalid table name: {table_name}")

    query = f"""
        SELECT count(*) 
        FROM nc.{table_name} 
        WHERE account_id = nc.current_account_id()
    """
    cursor.execute(query)
    result = cursor.fetchone()
    return result[0] if result else 0


@pytest.mark.skipif(not should_run_db_tests(), reason="NC_DB_LOCAL_TEST not set")
class TestRLSScanChain:
    """Test suite for RLS and scan → finding → ticket chain."""

    def test_tenant_isolation_with_correct_account(
        self, db_connection, setup_test_data
    ):
        """Test that data is visible with correct tenant context."""
        with db_connection.cursor() as cur:
            # Set the correct tenant context
            cur.execute("SET SESSION app.account_id = 'acct_scan_1'")

            # Verify all tables have exactly 1 row visible
            assert count_rows(cur, "scan") == 1, "Expected 1 scan for acct_scan_1"
            assert count_rows(cur, "policy") == 1, "Expected 1 policy for acct_scan_1"
            assert count_rows(cur, "finding") == 1, "Expected 1 finding for acct_scan_1"
            assert (
                count_rows(cur, "evidence") == 1
            ), "Expected 1 evidence for acct_scan_1"
            assert (
                count_rows(cur, "remediation") == 1
            ), "Expected 1 remediation for acct_scan_1"
            assert count_rows(cur, "ticket") == 1, "Expected 1 ticket for acct_scan_1"
            assert (
                count_rows(cur, "integration") == 1
            ), "Expected 1 integration for acct_scan_1"
            assert (
                count_rows(cur, "notification") == 1
            ), "Expected 1 notification for acct_scan_1"

            # Also verify asset
            assert count_rows(cur, "asset") == 1, "Expected 1 asset for acct_scan_1"

    def test_tenant_isolation_with_wrong_account(self, db_connection, setup_test_data):
        """Test that data is invisible with wrong tenant context."""
        with db_connection.cursor() as cur:
            # Set a different tenant context
            cur.execute("SET SESSION app.account_id = 'acct_other'")

            # Verify all tables have 0 rows visible
            assert count_rows(cur, "scan") == 0, "Expected 0 scans for acct_other"
            assert count_rows(cur, "policy") == 0, "Expected 0 policies for acct_other"
            assert count_rows(cur, "finding") == 0, "Expected 0 findings for acct_other"
            assert (
                count_rows(cur, "evidence") == 0
            ), "Expected 0 evidence for acct_other"
            assert (
                count_rows(cur, "remediation") == 0
            ), "Expected 0 remediations for acct_other"
            assert count_rows(cur, "ticket") == 0, "Expected 0 tickets for acct_other"
            assert (
                count_rows(cur, "integration") == 0
            ), "Expected 0 integrations for acct_other"
            assert (
                count_rows(cur, "notification") == 0
            ), "Expected 0 notifications for acct_other"
            assert count_rows(cur, "asset") == 0, "Expected 0 assets for acct_other"

    def test_tenant_isolation_with_null_account(self, db_connection, setup_test_data):
        """Test that data is invisible with null tenant context."""
        with db_connection.cursor() as cur:
            # Reset tenant context (sets it to null)
            cur.execute("RESET app.account_id")

            # Verify all tables have 0 rows visible
            assert count_rows(cur, "scan") == 0, "Expected 0 scans with null context"
            assert (
                count_rows(cur, "policy") == 0
            ), "Expected 0 policies with null context"
            assert (
                count_rows(cur, "finding") == 0
            ), "Expected 0 findings with null context"
            assert (
                count_rows(cur, "evidence") == 0
            ), "Expected 0 evidence with null context"
            assert (
                count_rows(cur, "remediation") == 0
            ), "Expected 0 remediations with null context"
            assert (
                count_rows(cur, "ticket") == 0
            ), "Expected 0 tickets with null context"
            assert (
                count_rows(cur, "integration") == 0
            ), "Expected 0 integrations with null context"
            assert (
                count_rows(cur, "notification") == 0
            ), "Expected 0 notifications with null context"
            assert count_rows(cur, "asset") == 0, "Expected 0 assets with null context"

    def test_scan_finding_chain_integrity(self, db_connection, setup_test_data):
        """Test that the complete scan → finding → ticket chain is present."""
        with db_connection.cursor() as cur:
            # Set the correct tenant context
            cur.execute("SET SESSION app.account_id = 'acct_scan_1'")

            # Verify scan exists
            cur.execute(
                """
                SELECT id, status, control_set_id 
                FROM nc.scan 
                WHERE account_id = nc.current_account_id()
            """
            )
            scan = cur.fetchone()
            assert scan is not None, "Scan should exist"
            assert scan[0] == "scan_001", "Scan ID should be scan_001"
            assert scan[1] == "COMPLETED", "Scan status should be COMPLETED"

            # Verify finding is linked to scan
            cur.execute(
                """
                SELECT id, scan_id, asset_id, status, severity 
                FROM nc.finding 
                WHERE account_id = nc.current_account_id()
            """
            )
            finding = cur.fetchone()
            assert finding is not None, "Finding should exist"
            assert finding[0] == "find_001", "Finding ID should be find_001"
            assert finding[1] == "scan_001", "Finding should be linked to scan_001"
            assert finding[3] == "OPEN", "Finding status should be OPEN"
            assert finding[4] == "HIGH", "Finding severity should be HIGH"

            # Verify evidence is linked to finding
            cur.execute(
                """
                SELECT id, finding_id 
                FROM nc.evidence 
                WHERE account_id = nc.current_account_id()
            """
            )
            evidence = cur.fetchone()
            assert evidence is not None, "Evidence should exist"
            assert evidence[1] == "find_001", "Evidence should be linked to find_001"

            # Verify remediation is linked to finding
            cur.execute(
                """
                SELECT id, finding_id, status 
                FROM nc.remediation 
                WHERE account_id = nc.current_account_id()
            """
            )
            remediation = cur.fetchone()
            assert remediation is not None, "Remediation should exist"
            assert (
                remediation[1] == "find_001"
            ), "Remediation should be linked to find_001"

            # Verify ticket is linked to finding
            cur.execute(
                """
                SELECT id, finding_id, provider, external_key 
                FROM nc.ticket 
                WHERE account_id = nc.current_account_id()
            """
            )
            ticket = cur.fetchone()
            assert ticket is not None, "Ticket should exist"
            assert ticket[1] == "find_001", "Ticket should be linked to find_001"
            assert ticket[2] == "JIRA", "Ticket provider should be JIRA"
