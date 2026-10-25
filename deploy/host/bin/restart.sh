#!/usr/bin/env bash
# Restart the API (and Redis/Caddy if needed) on the current image so it
# re-reads Secrets Manager. Fails if the API does not come back healthy, e.g.
# when a production setting is missing: the log shows which.
source "$(dirname "$0")/common.sh"

tag=$(cat "$GR_DIR/current-tag")
write_env "$tag"
compose up -d --force-recreate api
for _ in $(seq 1 45); do
  id=$(compose ps -q api)
  if [[ -n "$id" && "$(docker inspect --format '{{.State.Health.Status}}' "$id")" == healthy ]]; then
    log "API healthy on $tag"
    exit 0
  fi
  sleep 2
done
log "ERROR: API not healthy; last log lines:"
compose logs --tail 40 api >&2
exit 1
