-- =============================================================================
-- GreenRoot local database reset
-- =============================================================================
-- Rebuilds a clean local development database from the single source of truth:
--   1. schema.sql            (the whole schema)
--   2. seed-master.sql       (reference data: roles, sizes, plans, 15 plants…)
--   3. seed-dev-admin.sql    (one admin user, 9000000000)
--
-- Then load botanical names (cmd/botanicalnames load) and create dev users,
-- nurseries, orders… through the API: scripts/dev-data/seed_dev_data.py.
-- Redis is flushed by scripts/reset-dbs.sh, not by this SQL file.
-- =============================================================================

\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS public CASCADE;
-- pg_dump does not emit CREATE SCHEMA public, so schema.sql cannot recreate it.
CREATE SCHEMA public;

\ir schema.sql
\ir seed-master.sql
\ir seed-dev-admin.sql
