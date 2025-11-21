PYTHON_SOURCES=services libs/python

PG_CONTAINER_NAME ?= nc-pg-local
PG_IMAGE ?= postgres:15
PG_PORT ?= 5432
PG_USER ?= postgres
PG_PASSWORD ?= postgres
PG_DB ?= nc_dev

.PHONY: fmt lint test db_local_up db_local_migrate db_local_down db_local_smoke_test

fmt:
	ruff --fix .
	isort .
	black .

lint:
	markdownlint docs AGENTS.md
	yamllint .
	ruff .
	isort --check-only .
	black --check .

test:
	mkdir -p reports
	pytest $(PYTHON_SOURCES) --cov=src --cov-report=xml:reports/coverage.xml --junitxml=reports/junit.xml

# Local Postgres for schema and migration validation
# Starts a Postgres 15 container, creates $(PG_DB), and applies migrations under migrations/postgres/.
db_local_up:
	@docker ps -a --format '{{.Names}}' | grep -q '^$(PG_CONTAINER_NAME)$$' || \
	  docker run -d --name $(PG_CONTAINER_NAME) \
	    -e POSTGRES_USER=$(PG_USER) \
	    -e POSTGRES_PASSWORD=$(PG_PASSWORD) \
	    -e POSTGRES_DB=$(PG_DB) \
	    -p $(PG_PORT):5432 \
	    -v $(PWD):/workspace \
	    $(PG_IMAGE)
	@echo "Waiting for Postgres to be ready..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
	  docker exec $(PG_CONTAINER_NAME) pg_isready -U $(PG_USER) >/dev/null 2>&1 && break || sleep 1; \
	done

# Apply all Postgres migrations in order to the local container database.
# For convenience in local development, drop and recreate $(PG_DB) each time so
# migrations can assume a clean baseline without needing IF NOT EXISTS on every object.
db_local_migrate:
	@docker exec -i $(PG_CONTAINER_NAME) sh -lc 'set -e; \
	  dropdb -U $(PG_USER) $(PG_DB) >/dev/null 2>&1 || true; \
	  createdb -U $(PG_USER) $(PG_DB); \
	  for f in /workspace/migrations/postgres/*.sql; do \
	    echo "Applying $$f"; \
	    psql -U $(PG_USER) -d $(PG_DB) -v ON_ERROR_STOP=1 -f "$$f"; \
	  done'

# Stop the local Postgres container if it is running.
db_local_down:
	@docker stop $(PG_CONTAINER_NAME) >/dev/null 2>&1 || true

# Install Python test dependencies if needed
db_test_deps:
	@which pytest > /dev/null 2>&1 || pip install -q -r tests/requirements.txt

# Run local smoke tests for RLS and scan → finding → ticket chain
# Prerequisites: Docker running, db_local_up and db_local_migrate completed
# Usage: NC_DB_LOCAL_TEST=1 make db_local_smoke_test
db_local_smoke_test: db_local_up db_local_migrate db_test_deps
	@echo "Running local smoke tests for multi-tenant RLS and scan chain..."
	@NC_DB_LOCAL_TEST=1 \
	 NC_DB_HOST=localhost \
	 NC_DB_PORT=$(PG_PORT) \
	 NC_DB_NAME=$(PG_DB) \
	 NC_DB_USER=nc_app_rw \
	 NC_DB_PASSWORD=nc_app_rw \
	 pytest tests/db/test_rls_scan_chain.py -v
