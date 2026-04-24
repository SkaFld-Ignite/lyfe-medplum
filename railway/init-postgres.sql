-- Required for Medplum's optimistic concurrency control
ALTER SYSTEM SET default_transaction_isolation = 'repeatable read';

-- Query timeout (60 seconds) for safety
ALTER SYSTEM SET statement_timeout = '60000';

-- Required extensions for FHIR search and indexing
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Apply settings without restart
SELECT pg_reload_conf();
