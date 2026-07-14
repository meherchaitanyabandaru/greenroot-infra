-- =============================================================================
-- GreenRoot local database reset
-- =============================================================================
-- Rebuilds a clean local development database:
--   1. current schema
--   2. master/reference data
--   3. one local admin user
--
-- Redis is flushed by scripts/reset-dbs.sh, not by this SQL file.
-- =============================================================================

\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS public CASCADE;

\ir schema.sql
\ir seed-master.sql
\ir seed-dev-admin.sql
\ir seed-dev-data.sql
