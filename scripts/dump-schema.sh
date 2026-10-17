#!/usr/bin/env bash
# Regenerates db/postgresql/schema.sql from a database that is fully migrated
# (`go run ./cmd/migrate up` in greenroot-api). The dump includes the
# schema_migrations rows, so a fresh reset starts with every migration
# recorded and `migrate up` has nothing to do.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/../db/postgresql/schema.sql"
DB_URL="${DATABASE_URL:-postgres:///greenroot?host=/tmp}"

pg_dump --schema-only --no-owner --no-privileges "$DB_URL" > "$OUT"
{
  echo
  echo "--"
  echo "-- Applied migrations (greenroot-api internal/database/migrations)"
  echo "--"
  echo
  pg_dump --data-only --inserts --no-owner --no-privileges --table=public.schema_migrations "$DB_URL" \
    | grep '^INSERT INTO'
} >> "$OUT"
echo "Wrote $OUT"
