#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${INFRA_DIR}/.." && pwd)"

API_DIR="${GREENROOT_API_DIR:-${ROOT_DIR}/greenroot-api}"
ADMIN_DIR="${GREENROOT_ADMIN_DIR:-${ROOT_DIR}/greenroot-admin}"
MOBILE_DIR="${GREENROOT_MOBILE_DIR:-${ROOT_DIR}/greenroot-mobile}"

API_PORT="${API_PORT:-8080}"
ADMIN_PORT="${ADMIN_PORT:-5173}"
MOBILE_PORT="${MOBILE_PORT:-4040}"
DATABASE_URL="${DATABASE_URL:-postgres:///greenroot?host=/tmp}"
REDIS_ADDR="${REDIS_ADDR:-localhost:6379}"
JWT_SECRET="${JWT_SECRET:-local-dev-change-me}"

LOG_DIR="${LOG_DIR:-${INFRA_DIR}/logs/local-services}"
PID_DIR="${PID_DIR:-${INFRA_DIR}/tmp/local-services}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Missing required directory: $1" >&2
    exit 1
  fi
}

stop_pid_file() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_file"
  fi
}

stop_port() {
  local port="$1"
  local pids
  pids="$(lsof -ti "tcp:${port}" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill >/dev/null 2>&1 || true
    sleep 1
    pids="$(lsof -ti "tcp:${port}" 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs kill -9 >/dev/null 2>&1 || true
    fi
  fi
}

start_service() {
  local name="$1"
  local dir="$2"
  local log_file="$3"
  shift 3

  echo "Starting ${name}..."
  (
    cd "$dir"
    "$@"
  ) >"$log_file" 2>&1 &
  echo "$!" >"${PID_DIR}/${name}.pid"
}

require_cmd lsof
require_cmd go
require_cmd npm
require_cmd flutter
require_dir "$API_DIR"
require_dir "$ADMIN_DIR"
require_dir "$MOBILE_DIR"

mkdir -p "$LOG_DIR" "$PID_DIR"

for name in api admin mobile; do
  stop_pid_file "${PID_DIR}/${name}.pid"
done

stop_port "$API_PORT"
stop_port "$ADMIN_PORT"
stop_port "$MOBILE_PORT"

start_service api "$API_DIR" "${LOG_DIR}/api.log" \
  env DATABASE_URL="$DATABASE_URL" REDIS_ADDR="$REDIS_ADDR" JWT_SECRET="$JWT_SECRET" HTTP_PORT="$API_PORT" go run ./cmd/api

start_service admin "$ADMIN_DIR" "${LOG_DIR}/admin-ui.log" \
  npm run dev -- --host 0.0.0.0 --port "$ADMIN_PORT"

start_service mobile "$MOBILE_DIR" "${LOG_DIR}/mobile-web.log" \
  flutter run -d chrome --web-hostname 0.0.0.0 --web-port "$MOBILE_PORT"

echo
echo "Services are starting."
echo "  API log:    ${LOG_DIR}/api.log"
echo "  Admin UI:   http://localhost:${ADMIN_PORT}/"
echo "  Mobile web: http://localhost:${MOBILE_PORT}/#/home"
