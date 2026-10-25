#!/usr/bin/env bash
# Daily logical backup to S3 (systemd greenroot-backup.timer).
#
# RDS already keeps automated snapshots + point-in-time recovery (14 days).
# This adds an independent pg_dump copy outside RDS, verified and with its
# row-count manifest (scripts/db-backup.sh), in a versioned, encrypted bucket.
# On success it publishes GreenRoot/BackupSucceeded=1; the CloudWatch alarm
# fires if no success is reported for 26 hours.
source "$(dirname "$0")/common.sh"

[[ -d "$GR_DIR/infra/scripts" ]] || git clone -q --depth 1 https://github.com/meherchaitanyabandaru/greenroot-infra "$GR_DIR/infra"
work=$(mktemp -d /var/tmp/greenroot-backup.XXXX)
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"

# pg_dump 17 in a container; the read-only role is enough for a full dump.
docker run --rm --network host -e DATABASE_URL="$(setting READONLY_DATABASE_URL)" -e BACKUP_DIR=/backups \
  -e BACKUP_RETENTION_DAYS=1 -v "$work:/backups" -v "$GR_DIR/infra/scripts:/scripts:ro" public.ecr.aws/docker/library/postgres:17-alpine \
  sh -c 'apk add --no-cache bash coreutils >/dev/null && bash /scripts/db-backup.sh'

day=$(date -u +%Y/%m/%d)
aws s3 cp --quiet --recursive "$work" "s3://$BACKUP_BUCKET/$ENVIRONMENT/$day/"
aws cloudwatch put-metric-data --namespace GreenRoot --metric-name BackupSucceeded --value 1 \
  --dimensions Environment="$ENVIRONMENT"
log "backup uploaded to s3://$BACKUP_BUCKET/$ENVIRONMENT/$day/"
