#!/usr/bin/env bash
# Regenerates db/postgresql/schema.sql — the single source of truth for the
# GreenRoot schema — from a database that has the schema you want.
#
# The output is stable: pg_dump's per-run \restrict/\unrestrict tokens are
# removed, so the file only changes when the schema does. Migration rows are
# not included: before launch there are no migrations (see greenroot-api
# internal/database/migrations/README.md).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/../db/postgresql/schema.sql"
DB_URL="${DATABASE_URL:-postgres:///greenroot?host=/tmp}"
pg_dump --schema-only --no-owner --no-privileges "$DB_URL" \
  | grep -v -E '^\\(un)?restrict ' > "$OUT"
# Record the migrations this schema already contains, so `cmd/migrate up` on a
# database built from this file skips them (as CI and new environments do).
{
  echo
  echo "-- Migrations already applied in this schema (cmd/migrate skips them)."
  psql "$DB_URL" -XAt -c "SELECT format('INSERT INTO public.schema_migrations (version, checksum) VALUES (%L, %L) ON CONFLICT DO NOTHING;', version, checksum) FROM public.schema_migrations ORDER BY version"
} >> "$OUT"
echo "Wrote $OUT"
