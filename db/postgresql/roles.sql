-- =============================================================================
-- GreenRoot database roles — least privilege (standard D9)
-- =============================================================================
-- Run once per database as a superuser / the managed-DB admin, after the
-- schema exists. Safe to re-run: it only creates what is missing and re-applies
-- grants.
--
--   psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f roles.sql
--
-- Roles:
--   greenroot_owner     NOLOGIN. Owns every schema object. Nobody logs in as it.
--   greenroot_migrator  LOGIN. Runs cmd/migrate; every session acts as
--                       greenroot_owner, so new objects get the right owner.
--   greenroot_app       LOGIN. The API (DATABASE_URL). Row reads/writes only:
--                       no DDL, no TRUNCATE, cannot touch schema_migrations.
--   greenroot_readonly  LOGIN. Reporting / support queries. SELECT only.
--
-- Passwords are NOT set here. Set them from the secret store:
--   ALTER ROLE greenroot_app PASSWORD '<from secret manager>';
-- and require TLS in pg_hba.conf / the managed-DB settings.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'greenroot_owner') THEN
        CREATE ROLE greenroot_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'greenroot_migrator') THEN
        CREATE ROLE greenroot_migrator LOGIN IN ROLE greenroot_owner;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'greenroot_app') THEN
        CREATE ROLE greenroot_app LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'greenroot_readonly') THEN
        CREATE ROLE greenroot_readonly LOGIN;
    END IF;
END
$$;

-- Never superuser, never able to create roles or databases.
ALTER ROLE greenroot_migrator NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
ALTER ROLE greenroot_app      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
ALTER ROLE greenroot_readonly NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;

-- Migrator sessions create objects as the owner role.
ALTER ROLE greenroot_migrator SET role = 'greenroot_owner';
-- A runaway API query cannot hold locks or a connection forever.
ALTER ROLE greenroot_app SET statement_timeout = '30s';
ALTER ROLE greenroot_app SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE greenroot_readonly SET statement_timeout = '120s';
ALTER ROLE greenroot_readonly SET default_transaction_read_only = on;

-- ── Schema ──────────────────────────────────────────────────────────────────
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO greenroot_owner;
GRANT USAGE ON SCHEMA public TO greenroot_app, greenroot_readonly;

-- ── Ownership of existing objects (extension objects such as PostGIS stay
--    with the extension owner) ───────────────────────────────────────────────
DO $$
DECLARE
    obj record;
BEGIN
    FOR obj IN
        SELECT c.relname, c.relkind
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
          AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
          AND pg_get_userbyid(c.relowner) <> 'greenroot_owner'
          -- Sequences owned by a table column move with the table.
          AND NOT (c.relkind = 'S' AND EXISTS (
                SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a', 'i')))
    LOOP
        EXECUTE format('ALTER %s public.%I OWNER TO greenroot_owner',
            CASE obj.relkind
                WHEN 'S' THEN 'SEQUENCE'
                WHEN 'v' THEN 'VIEW'
                WHEN 'm' THEN 'MATERIALIZED VIEW'
                WHEN 'f' THEN 'FOREIGN TABLE'
                ELSE 'TABLE'
            END, obj.relname);
    END LOOP;

    FOR obj IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        WHERE p.pronamespace = 'public'::regnamespace
          AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
          AND pg_get_userbyid(p.proowner) <> 'greenroot_owner'
    LOOP
        EXECUTE format('ALTER FUNCTION %s OWNER TO greenroot_owner', obj.sig);
    END LOOP;

    FOR obj IN
        SELECT t.typname
        FROM pg_type t
        WHERE t.typnamespace = 'public'::regnamespace
          AND t.typtype = 'e'
          AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = t.oid AND d.deptype = 'e')
          AND pg_get_userbyid(t.typowner) <> 'greenroot_owner'
    LOOP
        EXECUTE format('ALTER TYPE public.%I OWNER TO greenroot_owner', obj.typname);
    END LOOP;
END
$$;

-- ── Grants on existing objects ──────────────────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO greenroot_app;
GRANT USAGE, SELECT, UPDATE           ON ALL SEQUENCES IN SCHEMA public TO greenroot_app;
GRANT EXECUTE                         ON ALL FUNCTIONS IN SCHEMA public TO greenroot_app;
-- The migration ledger is written only by the migrator; the API just reads it
-- (startup check for pending migrations).
REVOKE INSERT, UPDATE, DELETE ON public.schema_migrations FROM greenroot_app;

GRANT SELECT ON ALL TABLES    IN SCHEMA public TO greenroot_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO greenroot_readonly;

-- ── Grants on objects migrations create later ───────────────────────────────
ALTER DEFAULT PRIVILEGES FOR ROLE greenroot_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO greenroot_app;
ALTER DEFAULT PRIVILEGES FOR ROLE greenroot_owner IN SCHEMA public
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO greenroot_app;
ALTER DEFAULT PRIVILEGES FOR ROLE greenroot_owner IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO greenroot_app;
ALTER DEFAULT PRIVILEGES FOR ROLE greenroot_owner IN SCHEMA public
    GRANT SELECT ON TABLES TO greenroot_readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE greenroot_owner IN SCHEMA public
    GRANT SELECT ON SEQUENCES TO greenroot_readonly;
