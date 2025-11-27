-- 0003_nc_app_role.sql
-- Create application role nc_app_rw with proper privileges for RLS enforcement

-- Create the application role if it doesn't exist
DO $$
DECLARE
  v_password text := current_setting('nc.app_rw_password', true);
BEGIN
  IF v_password IS NULL OR v_password = '' THEN
    RAISE EXCEPTION 'nc_app_rw password must be provided via setting nc.app_rw_password';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nc_app_rw') THEN
    EXECUTE format('CREATE ROLE nc_app_rw WITH LOGIN PASSWORD %L', v_password);
  ELSE
    EXECUTE format('ALTER ROLE nc_app_rw WITH LOGIN PASSWORD %L', v_password);
  END IF;
END$$;

-- Grant usage on the nc schema
GRANT USAGE ON SCHEMA nc TO nc_app_rw;

-- Grant select, insert, update, delete on all tables in nc schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA nc TO nc_app_rw;

-- Grant usage on all sequences (for any serial columns)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA nc TO nc_app_rw;

-- Grant execute on all functions (needed for current_account_id())
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA nc TO nc_app_rw;

-- Grant execute on all procedures
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA nc TO nc_app_rw;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA nc
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO nc_app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA nc
  GRANT USAGE ON SEQUENCES TO nc_app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA nc
  GRANT EXECUTE ON FUNCTIONS TO nc_app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA nc
  GRANT EXECUTE ON ROUTINES TO nc_app_rw;

-- Comment for documentation
COMMENT ON ROLE nc_app_rw IS 'Application role for read-write operations with RLS enforcement';
