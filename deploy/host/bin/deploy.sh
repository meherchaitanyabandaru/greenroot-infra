#!/usr/bin/env bash
# Deploy an API image tag: migrate, switch, verify, roll back on failure.
#
#   sudo /opt/greenroot/bin/deploy.sh v1.4.0
#
# 1. pulls the image from ECR;
# 2. runs pending migrations with that image (as greenroot_migrator);
# 3. restarts the API on the new image and waits until it is healthy;
# 4. if it is not healthy within 90 s, starts the previous tag again.
# Migrations are additive by convention (README "Changing the schema"), so the
# previous image still runs on the migrated schema during a rollback.
source "$(dirname "$0")/common.sh"

tag=${1:?usage: deploy.sh <image-tag>}
previous=$(cat "$GR_DIR/current-tag" 2>/dev/null || true)

ecr_login
log "pulling $ECR_REPO:$tag"
docker pull -q "$ECR_REPO:$tag" >/dev/null

log "applying migrations"
docker run --rm --network host -e AWS_SECRETS_ID="$SECRET_ID" -e AWS_REGION="$AWS_REGION" \
  --entrypoint /app/migrate "$ECR_REPO:$tag" up

write_env "$tag"
log "starting $tag"
compose up -d --remove-orphans

healthy() {
  local id
  id=$(compose ps -q api)
  [[ -n "$id" ]] && [[ "$(docker inspect --format '{{.State.Health.Status}}' "$id")" == healthy ]]
}

for _ in $(seq 1 45); do
  if healthy; then
    echo "$tag" >"$GR_DIR/current-tag"
    log "deployed $tag (previous: ${previous:-none})"
    docker image prune -af --filter "until=720h" >/dev/null || true
    exit 0
  fi
  sleep 2
done

log "ERROR: $tag did not become healthy; last API log lines:"
compose logs --tail 40 api >&2 || true
if [[ -n "$previous" && "$previous" != "$tag" ]]; then
  log "rolling back to $previous"
  write_env "$previous"
  compose up -d
fi
exit 1
