-- Required extensions for FHIR search and indexing
-- Note: default_transaction_isolation and statement_timeout are set per-connection
-- by the Medplum server, so ALTER SYSTEM is not needed (and may be blocked on
-- managed Postgres providers like Railway).
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
