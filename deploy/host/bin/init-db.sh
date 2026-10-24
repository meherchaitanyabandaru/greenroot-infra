#!/usr/bin/env bash
# One-time database setup on a fresh RDS instance:
#   schema + master data (greenroot-infra/db/postgresql), least-privilege roles
#   with passwords from the API secret. Safe to re-run: it stops if the schema
#   already exists, and only re-applies roles/passwords.
#
#   sudo /opt/greenroot/bin/init-db.sh [git-ref]     # default: master
source "$(dirname "$0")/common.sh"

ref=${1:-master}
master_secret=$(aws secretsmanager get-secret-value --secret-id "$DB_MASTER_SECRET_ARN" --query SecretString --output text)
master_user=$(jq -er .username <<<"$master_secret")
master_pass=$(jq -er .password <<<"$master_secret")
db_host=$(setting DATABASE_URL | sed -E 's#^postgres://[^@]+@([^:/]+).*#\1#')
admin_url="postgres://${master_user}:$(jq -rn --arg p "$master_pass" '$p|@uri')@${db_host}:5432/greenroot?sslmode=require"

log "fetching schema files ($ref)"
rm -rf "$GR_DIR/infra"
git clone -q --depth 1 --branch "$ref" https://github.com/meherchaitanyabandaru/greenroot-infra "$GR_DIR/infra"

if psql_container "$admin_url" -XAtc "SELECT to_regclass('public.users') IS NOT NULL" | grep -q t; then
  log "schema already present: skipping schema and master data"
else
  log "loading schema.sql and seed-master.sql"
  psql_container "$admin_url" -q -f /infra/db/postgresql/schema.sql
  psql_container "$admin_url" -q -f /infra/db/postgresql/seed-master.sql
fi

# RDS's master is not a superuser: it must belong to greenroot_owner to hand
# objects over to it in roles.sql.
log "applying least-privilege roles"
psql_container "$admin_url" -q -c "DO \$\$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'greenroot_owner') THEN CREATE ROLE greenroot_owner NOLOGIN; END IF;
END \$\$;" -c "GRANT greenroot_owner TO CURRENT_USER"
psql_container "$admin_url" -q -f /infra/db/postgresql/roles.sql

# Passwords travel on stdin, never on a command line.
log "setting role passwords from the API secret"
{
  printf "ALTER ROLE greenroot_app PASSWORD '%s';\n" "$(setting DB_APP_PASSWORD)"
  printf "ALTER ROLE greenroot_migrator PASSWORD '%s';\n" "$(setting DB_MIGRATOR_PASSWORD)"
  printf "ALTER ROLE greenroot_readonly PASSWORD '%s';\n" "$(setting DB_READONLY_PASSWORD)"
} | psql_container "$admin_url" -q

log "database ready. Next: deploy.sh <tag> (applies migrations), then create-admin.sh"
