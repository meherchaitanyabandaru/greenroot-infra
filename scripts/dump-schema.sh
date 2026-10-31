#!/usr/bin/env bash
# Regenerates db/postgresql/schema.sql — the single source of truth for the
# GreenRoot schema — from a database that has the schema you want.
#
# The output is stable: pg_dump's per-run \restrict/\unrestrict tokens are
# removed, so the file only changes when the schema does. Migration rows are
# not included: the migrations were folded into this file on 2026-10-31 (see
# greenroot-api internal/database/migrations/README.md).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/../db/postgresql/schema.sql"
DB_URL="${DATABASE_URL:-postgres:///greenroot?host=/tmp}"
pg_dump --schema-only --no-owner --no-privileges "$DB_URL" \
  | grep -v -E '^\\(un)?restrict ' > "$OUT"
echo "Wrote $OUT"
