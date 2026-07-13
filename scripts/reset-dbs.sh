#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DB_URL="${DATABASE_URL:-postgres:///greenroot?host=/tmp}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_DB="${REDIS_DB:-0}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
SKIP_REDIS_FLUSH="${SKIP_REDIS_FLUSH:-0}"

RESET_SQL="${GREENROOT_RESET_SQL:-${INFRA_DIR}/db/postgresql/reset-local.sql}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

psql_exec() {
  psql "$DB_URL" -v ON_ERROR_STOP=1 "$@"
}

redis_args=(-h "$REDIS_HOST" -p "$REDIS_PORT" -n "$REDIS_DB")
if [[ -n "$REDIS_PASSWORD" ]]; then
  redis_args+=(-a "$REDIS_PASSWORD")
fi

require_cmd psql
require_file "$RESET_SQL"

if [[ "$SKIP_REDIS_FLUSH" != "1" ]]; then
  require_cmd redis-cli
fi

echo "Resetting PostgreSQL database:"
echo "  ${DB_URL}"
echo

echo "Running reset SQL:"
echo "  ${RESET_SQL}"
psql_exec -f "$RESET_SQL"

if [[ "$SKIP_REDIS_FLUSH" == "1" ]]; then
  echo "Skipping Redis flush because SKIP_REDIS_FLUSH=1"
else
  echo "Flushing Redis DB ${REDIS_DB} at ${REDIS_HOST}:${REDIS_PORT}"
  redis-cli "${redis_args[@]}" FLUSHDB >/dev/null
fi

echo
echo "Fresh GreenRoot local data is ready."
echo "  Admin mobile: 9000000000"
echo "  Dev OTP:      123456"
echo "  Seeded:       roles, plant master data, subscription plans, one admin user"
