#!/usr/bin/env bash
# Point-in-time recovery drill (standard D11) on a throwaway local cluster.
#
#   WORK_DIR=/tmp/gr-pitr ./pitr-drill.sh
#
# Proves the recovery procedure end to end with PostgreSQL's own tools, the
# same mechanism managed hosts (Azure Flexible Server, RDS) and pgBackRest use:
#   1. a primary with continuous WAL archiving (archive_mode, archive_command)
#   2. the GreenRoot schema and seed data, then a base backup
#   3. normal writes after the backup (must be recovered)
#   4. a "disaster": TRUNCATE orders CASCADE (orders, items, dispatches, …)
#   5. restore the base backup, replay WAL to the moment before the
#      disaster (recovery_target_time), promote
#   6. verify: post-backup writes present, disaster undone, constraints valid
# Reports recovery time (RTO) and data-loss window (RPO). Needs initdb,
# pg_ctl, pg_basebackup and psql (PostgreSQL 17) on PATH. Cleans up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/../db/postgresql"
WORK_DIR="${WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/gr-pitr.XXXXXX")}"
PRIMARY_PORT="${PRIMARY_PORT:-5440}"
RESTORE_PORT="${RESTORE_PORT:-5441}"

for cmd in initdb pg_ctl pg_basebackup psql; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

# Unix socket paths are limited to ~103 bytes, so sockets get a short dir.
SOCK_DIR="$(mktemp -d /tmp/grpitr.XXXXXX)"
PRIMARY="${WORK_DIR}/primary"
RESTORED="${WORK_DIR}/restored"
ARCHIVE="${WORK_DIR}/wal-archive"
BASE="${WORK_DIR}/base"
mkdir -p "$ARCHIVE"

cleanup() {
  pg_ctl -D "$PRIMARY" -m immediate stop >/dev/null 2>&1 || true
  pg_ctl -D "$RESTORED" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$SOCK_DIR"
  [[ "${KEEP_PITR_DIR:-0}" == "1" ]] || rm -rf "$WORK_DIR"
}
trap cleanup EXIT

p() { psql "host=${SOCK_DIR} port=$1 dbname=greenroot" -XAtq -v ON_ERROR_STOP=1 "${@:2}"; }

echo "1. primary with WAL archiving"
initdb -D "$PRIMARY" -U postgres --auth=trust >/dev/null
cat >>"${PRIMARY}/postgresql.conf" <<EOF
port = ${PRIMARY_PORT}
listen_addresses = ''
unix_socket_directories = '${SOCK_DIR}'
wal_level = replica
archive_mode = on
archive_command = 'test ! -f ${ARCHIVE}/%f && cp %p ${ARCHIVE}/%f'
archive_timeout = 60
timezone = 'UTC'
EOF
pg_ctl -D "$PRIMARY" -l "${WORK_DIR}/primary.log" -w start >/dev/null
psql "host=${SOCK_DIR} port=${PRIMARY_PORT} dbname=postgres user=postgres" -XAtq -c "CREATE DATABASE greenroot" -c "CREATE ROLE ${USER} SUPERUSER LOGIN" 2>/dev/null || true

echo "2. schema + seed data, then base backup"
for f in schema.sql seed-master.sql seed-dev-admin.sql seed-dev-data.sql; do
  p "$PRIMARY_PORT" -f "${SQL_DIR}/${f}" >/dev/null
done
pg_basebackup -h "$SOCK_DIR" -p "$PRIMARY_PORT" -U postgres -D "$BASE" -X stream -c fast >/dev/null

echo "3. writes after the backup"
p "$PRIMARY_PORT" -c "INSERT INTO public.audit_logs (module, entity_type, action_type, record_id) VALUES ('pitr-drill', 'marker', 'INSERT', 424242)"
orders_before=$(p "$PRIMARY_PORT" -c "SELECT count(*) FROM public.orders")
items_before=$(p "$PRIMARY_PORT" -c "SELECT count(*) FROM public.order_items")
sleep 1
target=$(p "$PRIMARY_PORT" -c "SELECT now()::text")
sleep 1

echo "4. disaster: orders and everything that references them truncated"
PGOPTIONS="-c client_min_messages=warning" p "$PRIMARY_PORT" -c "TRUNCATE public.orders CASCADE"
[[ "$(p "$PRIMARY_PORT" -c "SELECT count(*) FROM public.orders")" == "0" ]] || { echo "disaster simulation failed" >&2; exit 1; }
# Make sure the WAL containing the disaster (and the target) is archived.
p "$PRIMARY_PORT" -c "SELECT pg_switch_wal()" >/dev/null
for _ in $(seq 1 30); do
  last=$(p "$PRIMARY_PORT" -c "SELECT last_archived_wal FROM pg_stat_archiver")
  current=$(p "$PRIMARY_PORT" -c "SELECT pg_walfile_name(pg_current_wal_lsn())")
  [[ -n "$last" && "$last" < "$current" || "$last" == "$current" ]] && [[ -f "${ARCHIVE}/${last}" ]] && break
  sleep 1
done
pg_ctl -D "$PRIMARY" -m fast stop >/dev/null

echo "5. restore base backup and replay WAL to ${target}"
started=$(date +%s)
cp -R "$BASE" "$RESTORED"
chmod 700 "$RESTORED"
cat >>"${RESTORED}/postgresql.conf" <<EOF
port = ${RESTORE_PORT}
archive_mode = off
restore_command = 'cp ${ARCHIVE}/%f %p'
recovery_target_time = '${target}'
recovery_target_action = 'promote'
EOF
touch "${RESTORED}/recovery.signal"
pg_ctl -D "$RESTORED" -l "${WORK_DIR}/restored.log" -w -t 120 start >/dev/null
for _ in $(seq 1 60); do
  [[ "$(p "$RESTORE_PORT" -c "SELECT pg_is_in_recovery()")" == "f" ]] && break
  sleep 1
done
rto=$(( $(date +%s) - started ))

echo "6. verify"
orders_after=$(p "$RESTORE_PORT" -c "SELECT count(*) FROM public.orders")
items_after=$(p "$RESTORE_PORT" -c "SELECT count(*) FROM public.order_items")
marker=$(p "$RESTORE_PORT" -c "SELECT count(*) FROM public.audit_logs WHERE module = 'pitr-drill' AND record_id = 424242")
invalid=$(p "$RESTORE_PORT" -c "SELECT count(*) FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND NOT convalidated")
recovered_to=$(p "$RESTORE_PORT" -c "SELECT pg_last_xact_replay_timestamp()::text")

fail=0
[[ "$orders_after" == "$orders_before" ]] || { echo "FAIL: orders ${orders_after}, expected ${orders_before}" >&2; fail=1; }
[[ "$items_after" == "$items_before" ]] || { echo "FAIL: order_items ${items_after}, expected ${items_before}" >&2; fail=1; }
[[ "$marker" == "1" ]] || { echo "FAIL: the write made after the base backup was not recovered" >&2; fail=1; }
[[ "$invalid" == "0" ]] || { echo "FAIL: ${invalid} constraints not valid" >&2; fail=1; }
[[ "$fail" == "0" ]] || exit 1

echo "PITR drill ok: recovered to ${target} (last replayed transaction ${recovered_to}); ${orders_after} orders and ${items_after} items restored after the disaster; post-backup write recovered; constraints valid; recovery took ${rto}s"
