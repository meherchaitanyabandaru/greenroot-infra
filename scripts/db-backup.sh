#!/usr/bin/env bash
# Logical backup of the GreenRoot database (pg_dump custom format).
#
#   DATABASE_URL=... BACKUP_DIR=/var/backups/greenroot ./db-backup.sh
#
# This is the portable layer: a consistent snapshot you can restore anywhere.
# Point-in-time recovery (RPO <= 5 min) comes from the database host's WAL
# archiving (managed PITR or pgBackRest); see docs/database-operations.md.
# Keeps BACKUP_RETENTION_DAYS (default 14) of dumps; verifies each dump is
# readable before reporting success.
set -euo pipefail

DB_URL="${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

for cmd in pg_dump pg_restore; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

mkdir -p "$BACKUP_DIR"
umask 077 # dumps contain personal data
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="${BACKUP_DIR}/greenroot-${stamp}.dump"
tmp="${out}.partial"

manifest="${out}.manifest"
export GR_DB_URL="$DB_URL" GR_DUMP_TMP="$tmp" GR_MANIFEST_TMP="${manifest}.partial"

# One REPEATABLE READ snapshot for both the dump and the row-count manifest,
# so the restore drill can prove the restore is complete even though the
# live database keeps changing. --no-owner/--no-privileges: restorable into
# any database; roles.sql re-applies ownership and grants.
psql "$DB_URL" -Xq -v ON_ERROR_STOP=1 <<'SQL'
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT pg_export_snapshot() AS snap \gset
\setenv GR_SNAPSHOT :snap
\getenv manifest_path GR_MANIFEST_TMP
\pset format unaligned
\pset tuples_only on
\o :manifest_path
SELECT format('%s=%s', c.relname,
       (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM public.%I', c.relname), false, true, '')))[1])
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r'
ORDER BY c.relname;
SELECT 'schema_migrations:' || string_agg(version, ',' ORDER BY version) FROM public.schema_migrations;
\o
\! pg_dump --snapshot="$GR_SNAPSHOT" --format=custom --compress=6 --no-owner --no-privileges --file="$GR_DUMP_TMP" "$GR_DB_URL" || touch "$GR_DUMP_TMP.failed"
COMMIT;
SQL
[[ ! -e "${tmp}.failed" ]] || { rm -f "${tmp}.failed" "$tmp"; echo "pg_dump failed" >&2; exit 1; }

# A dump that pg_restore cannot list is not a backup.
pg_restore --list "$tmp" >/dev/null
[[ -s "${manifest}.partial" ]] || { echo "manifest was not written" >&2; exit 1; }
mv "$tmp" "$out"
mv "${manifest}.partial" "$manifest"
(cd "$BACKUP_DIR" && { sha256sum "$(basename "$out")" 2>/dev/null || shasum -a 256 "$(basename "$out")"; }) >"${out}.sha256"

find "$BACKUP_DIR" -name 'greenroot-*.dump' -type f -mtime +"$RETENTION_DAYS" -print -delete | sed 's/^/pruned /'
find "$BACKUP_DIR" \( -name 'greenroot-*.dump.sha256' -o -name 'greenroot-*.dump.manifest' \) -type f -mtime +"$RETENTION_DAYS" -delete

echo "backup ok: $out ($(du -h "$out" | cut -f1))"
