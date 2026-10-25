# One Secrets Manager secret holds every API setting as a JSON object of
# environment variables. The API reads it at start-up (AWS_SECRETS_ID).
#
# Terraform writes it once with generated secrets and the infrastructure's
# endpoints; afterwards it is yours: add RAZORPAY_*, FCM_SERVICE_ACCOUNT_JSON,
# switch SMS_PROVIDER/EMAIL_PROVIDER, flip APP_ENV to production — in the
# console or with deploy/host/bin/set-secret.sh — then restart the API.
# Terraform never overwrites your edits (ignore_changes).

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "random_password" "delivery_code" {
  length  = 64
  special = false
}

resource "random_password" "redis" {
  length  = 40
  special = false
}

resource "random_password" "db_app" {
  length  = 40
  special = false
}

resource "random_password" "db_migrator" {
  length  = 40
  special = false
}

resource "random_password" "db_readonly" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "api" {
  name                    = "${local.name}/api"
  description             = "GreenRoot API settings (JSON of env vars). Edit, then restart the API."
  recovery_window_in_days = 7
}

locals {
  db_host = aws_db_instance.main.address
  # TLS is required (rds.force_ssl=1 refuses plaintext too). The RDS CA is not
  # in the image's trust store, so the certificate itself is not verified; the
  # database is reachable only from the host's security group inside the VPC.
  db_url = "postgres://%s:%s@${local.db_host}:5432/greenroot?sslmode=require"

  initial_settings = {
    APP_ENV = "staging" # flip to "production" once SMS, email, Razorpay and FCM keys are in
    # Until then staging may run mock providers; production refuses them.
    ALLOW_MOCK_PROVIDERS = "true"

    DATABASE_URL          = format(local.db_url, "greenroot_app", random_password.db_app.result)
    MIGRATE_DATABASE_URL  = format(local.db_url, "greenroot_migrator", random_password.db_migrator.result)
    READONLY_DATABASE_URL = format(local.db_url, "greenroot_readonly", random_password.db_readonly.result)
    DB_APP_PASSWORD       = random_password.db_app.result
    DB_MIGRATOR_PASSWORD  = random_password.db_migrator.result
    DB_READONLY_PASSWORD  = random_password.db_readonly.result

    REDIS_ADDR     = "redis:6379"
    REDIS_PASSWORD = random_password.redis.result

    JWT_SECRET           = random_password.jwt.result
    DELIVERY_CODE_SECRET = random_password.delivery_code.result

    CORS_ALLOWED_ORIGINS = "https://${local.admin_host}"
    TRUSTED_PROXIES      = "172.16.0.0/12" # the Docker network Caddy forwards from

    STORAGE_ENDPOINT      = "s3.${var.region}.amazonaws.com"
    STORAGE_REGION        = var.region
    STORAGE_USE_SSL       = "true"
    STORAGE_USE_IAM_ROLE  = "true"
    STORAGE_BUCKET_PREFIX = local.prefix
    STORAGE_PUBLIC_URL    = "https://${local.files_host}"

    AWS_REGION     = var.region
    SMS_PROVIDER   = "mock" # "aws" after DLT registration + AWS SMS production access
    EMAIL_PROVIDER = "mock" # "ses" after SES domain verification + production access

    RAZORPAY_KEY_ID          = ""
    RAZORPAY_KEY_SECRET      = ""
    RAZORPAY_WEBHOOK_SECRET  = ""
    FCM_SERVICE_ACCOUNT_JSON = ""

    ADMIN_ALLOWED_CIDRS = join(",", var.admin_allowed_cidrs)
    LOG_LEVEL           = "info"
  }
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id     = aws_secretsmanager_secret.api.id
  secret_string = jsonencode(local.initial_settings)
  lifecycle {
    ignore_changes = [secret_string] # your edits win from here on
  }
}
