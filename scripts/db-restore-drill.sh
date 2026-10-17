#!/usr/bin/env bash
# Restore drill (standard D11): proves the latest backup restores into a
# working database. Run monthly and after every schema change; it exits
# non-zero on any mismatch.
#
#   ADMIN_DATABASE_URL=postgres:///postgres BACKUP_DIR=... ./db-restore-drill.sh
#
# Steps: verify the checksum of the newest dump, restore it into a fresh
# scratch database, then compare it with the manifest db-backup.sh recorded
# in the same snapshot as the dump (per-table row counts and applied
# migrations), and check every constraint is valid. The live source may have
# changed since the backup; that is expected and not compared. The scratch
# database is dropped afterwards (KEEP_DRILL_DB=1 keeps it).
set -euo pipefail

ADMIN_URL="${ADMIN_DATABASE_URL:?ADMIN_DATABASE_URL is required (connects to a maintenance DB, e.g. postgres)}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DRILL_DB="greenroot_restore_drill_$(date -u +%Y%m%d%H%M%S)"

latest="$(ls -1t "$BACKUP_DIR"/greenroot-*.dump 2>/dev/null | head -1 || true)"
[[ -n "$latest" ]] || { echo "no backups in $BACKUP_DIR" >&2; exit 1; }

manifest="${latest}.manifest"
[[ -f "$manifest" ]] || { echo "missing manifest for $latest (take backups with db-backup.sh)" >&2; exit 1; }
echo "drill: $latest"
if [[ -f "${latest}.sha256" ]]; then
  (cd "$(dirname "$latest")" && { sha256sum -c "$(basename "$latest").sha256" 2>/dev/null || shasum -a 256 -c "$(basename "$latest").sha256"; }) >/dev/null
  echo "checksum ok"
fi

started=$(date +%s)
psql "$ADMIN_URL" -XAtq -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DRILL_DB}"
cleanup() {
  if [[ "${KEEP_DRILL_DB:-0}" != "1" ]]; then
    psql "$ADMIN_URL" -XAtq -c "DROP DATABASE IF EXISTS ${DRILL_DB} WITH (FORCE)" >/dev/null || true
  fi
}
trap cleanup EXIT

# Same server as ADMIN_URL, scratch database name.
# Works for host URLs (postgres://u:p@h:5432/db?x) and socket URLs (postgres:///db?host=/tmp).
DRILL_URL="$(sed -E "s#^(postgres(ql)?://[^/?]*)/[^?]*#\1/${DRILL_DB}#" <<<"$ADMIN_URL")"
[[ "$DRILL_URL" == *"/${DRILL_DB}"* ]] || { echo "cannot derive drill URL from ADMIN_DATABASE_URL" >&2; exit 1; }

pg_restore --exit-on-error --no-owner --no-privileges --dbname="$DRILL_URL" "$latest"
restore_secs=$(( $(date +%s) - started ))

actual="$(psql "$DRILL_URL" -XAtq <<'SQL'
SELECT format('%s=%s', c.relname,
       (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM public.%I', c.relname), false, true, '')))[1])
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;
SELECT 'schema_migrations:' || string_agg(version, ',' ORDER BY version) FROM public.schema_migrations;
SQL
)"
if [[ "$actual" != "$(cat "$manifest")" ]]; then
  echo "FAIL: restore does not match the backup manifest" >&2
  diff "$manifest" <(printf '%s\n' "$actual") >&2 || true
  exit 1
fi

invalid="$(psql "$DRILL_URL" -XAtq -c "SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND NOT convalidated")"
[[ "$invalid" == "0" ]] || { echo "FAIL: $invalid constraints not validated after restore" >&2; exit 1; }

tables=$(grep -c '=' "$manifest")
echo "restore drill ok: ${tables} tables match the backup manifest, migrations match, all constraints valid, restore took ${restore_secs}s"
