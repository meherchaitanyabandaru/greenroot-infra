#!/usr/bin/env bash
# Shared helpers for the host scripts. /etc/greenroot/host.env is written by
# cloud-init (Terraform) and holds only non-secret identifiers.
set -euo pipefail

GR_DIR=/opt/greenroot
# shellcheck disable=SC1091
source /etc/greenroot/host.env # AWS_REGION, SECRET_ID, ECR_REPO, API_HOST, LOG_GROUP, BACKUP_BUCKET, ACME_EMAIL, DB_MASTER_SECRET_ARN, ENVIRONMENT

export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }

# setting KEY: one value from the API secret (never printed by callers).
setting() {
  aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text |
    jq -er --arg k "$1" '.[$k] // empty'
}

ecr_login() {
  aws ecr get-login-password | docker login --username AWS --password-stdin "${ECR_REPO%%/*}" >/dev/null
}

# write_env TAG: the compose .env (0600). The Redis password is the only
# secret here; the API reads its own settings from Secrets Manager.
write_env() {
  local tag=$1 tmp
  tmp=$(mktemp "$GR_DIR/.env.XXXX")
  chmod 600 "$tmp"
  {
    echo "API_IMAGE=$ECR_REPO:$tag"
    echo "API_VERSION=$tag"
    echo "AWS_SECRETS_ID=$SECRET_ID"
    echo "AWS_REGION=$AWS_REGION"
    echo "API_HOST=$API_HOST"
    echo "ACME_EMAIL=$ACME_EMAIL"
    echo "LOG_GROUP=$LOG_GROUP"
    echo "REDIS_PASSWORD=$(setting REDIS_PASSWORD)"
  } >"$tmp"
  mv "$tmp" "$GR_DIR/.env"
}

compose() { docker compose --project-directory "$GR_DIR" -f "$GR_DIR/docker-compose.yml" "$@"; }

# psql_container URL ARGS...: psql 17 without installing it on the host.
psql_container() {
  local url=$1
  shift
  docker run --rm -i --network host -e PGURL="$url" -v "$GR_DIR/infra:/infra:ro" public.ecr.aws/docker/library/postgres:17-alpine \
    sh -c 'exec psql "$PGURL" -X -v ON_ERROR_STOP=1 "$@"' psql "$@"
}
