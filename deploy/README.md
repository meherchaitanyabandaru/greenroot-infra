# Deploying GreenRoot on AWS

Everything needed to run GreenRoot in production, at launch cost (about
USD 30–35 a month in `ap-south-1`):

| Piece | Where | Cost driver |
|---|---|---|
| API + Redis + Caddy (TLS) | one EC2 `t4g.small`, Docker Compose | ~USD 12 |
| PostgreSQL 17 + PostGIS | RDS `db.t4g.micro`, 20 GB gp3, 14-day PITR | ~USD 15 |
| Images (selfies, plants, ads, logos) | S3 (private) behind CloudFront `files.<domain>` | pennies |
| Private files (licences, delivery photos, PDFs) | S3, presigned links only | pennies |
| Admin dashboard | S3 + CloudFront `admin.<domain>` | pennies |
| Every secret and setting | one Secrets Manager secret | USD 0.40 |
| Logs, alarms, uptime check | CloudWatch + SNS email + Route 53 health check | ~USD 2 |

No NAT gateway, no load balancer, no access keys: the host's IAM role is
the only AWS identity, and shell access is SSM Session Manager.

```
deploy/
  terraform/   the AWS stack (terraform test = mocked apply with assertions)
  host/        what runs on the EC2 host: docker-compose.yml, Caddyfile,
               bin/ (deploy, restart, init-db, create-admin, backup, set-secret)
```

---

## 1. First launch (once)

Prerequisites: an AWS account, the domain (Route 53 zone optional), Terraform
≥ 1.6, Docker with buildx, the AWS CLI with the Session Manager plugin.

```bash
# 1. State bucket (once per account), then the stack.
aws s3api create-bucket --bucket <you>-tf-state --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api put-bucket-versioning --bucket <you>-tf-state --versioning-configuration Status=Enabled

cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars     # domain, alarm_email, route53_zone_id
terraform init -backend-config="bucket=<you>-tf-state" \
  -backend-config="key=greenroot/production.tfstate" -backend-config="region=ap-south-1"
terraform apply
```

Without a Route 53 zone: create the records from `terraform output
cdn_certificate_validation` first (the apply waits on the certificate only
with Route 53; otherwise re-run `terraform apply` once it is issued), then
those in `terraform output dns_records_to_create`.

Confirm the two SNS subscription emails (alarms).

```bash
# 2. Build and push the API image (Graviton = arm64).
REPO=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password | docker login --username AWS --password-stdin "${REPO%%/*}"
cd ../../../greenroot-api
docker buildx build --platform linux/arm64 --build-arg VERSION=v1.0.0 -t "$REPO:v1.0.0" --push .

# 3. On the host (no SSH: Session Manager).
aws ssm start-session --target "$(terraform -chdir=../greenroot-infra/deploy/terraform output -raw api_instance_id)"
sudo /opt/greenroot/bin/init-db.sh            # schema, master data, least-privilege roles
sudo /opt/greenroot/bin/deploy.sh v1.0.0      # migrations, start, health check
sudo /opt/greenroot/bin/create-admin.sh 98XXXXXXXX "First" "Last"
```

`https://api.<domain>/health` answers; Caddy obtained the TLS certificate.

```bash
# 4. Admin dashboard.
cd greenroot-admin
VITE_API_BASE_URL=https://api.<domain> npm ci && npm run build
aws s3 sync dist/ "s3://$(terraform output -raw admin_bucket)/" --delete
aws cloudfront create-invalidation --distribution-id "$(terraform output -raw admin_distribution_id)" --paths '/*'
```

The stack starts as **`APP_ENV=staging`** with mock SMS/email/payments
allowed, so you can test everything end to end before the provider accounts
are ready. **Production refuses to start until every real key is in.**

---

## 2. Go live: put the real keys in

All settings live in the Secrets Manager secret `greenroot-production/api`
(JSON of environment variables). Change them with `set-secret.sh` on the
host (value on stdin, never in shell history) or in the AWS console, then
`sudo /opt/greenroot/bin/restart.sh`. A missing production setting makes the
restart fail with the exact list.

| Setting | Value | Before setting it |
|---|---|---|
| `SMS_PROVIDER` | `aws` | DLT: register the Principal Entity, header `GRROOT` and **every** template in [docs/sms.md](../docs/sms.md) (including `DELIVERY_UNCONFIRMED`); AWS End User Messaging SMS: register the sender ID with the PE and template IDs, request production access. Enter the DLT IDs in Admin → SMS / DLT until Readiness is all green. |
| `EMAIL_PROVIDER` | `ses` | SES in ap-south-1: verify the domain (SPF/DKIM/DMARC), request production access, set the From address in Admin → Email. |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | live keys (`rzp_live_…`) | Razorpay KYC done. |
| `RAZORPAY_WEBHOOK_SECRET` | webhook secret | Dashboard → Webhooks → `https://api.<domain>/api/v1/webhooks/razorpay`, events `payment.captured`, `order.paid`, `refund.processed`, `refund.failed`. |
| `FCM_SERVICE_ACCOUNT_JSON` | the service-account key JSON | Firebase project → Service accounts → Generate key (`set-secret.sh FCM_SERVICE_ACCOUNT_JSON < key.json`). Build the app with the matching `FCM_*` values (greenroot-mobile README). |
| `ADMIN_ALLOWED_CIDRS` | optional, e.g. office/VPN IPs | Admin accounts then work only from those networks. |
| `APP_ENV` | `production` | All of the above. |
| `ALLOW_MOCK_PROVIDERS` | `false` | — (ignored in production anyway) |

```bash
sudo /opt/greenroot/bin/set-secret.sh SMS_PROVIDER <<<aws
sudo /opt/greenroot/bin/set-secret.sh RAZORPAY_KEY_SECRET        # paste, Enter, Ctrl-D
sudo /opt/greenroot/bin/set-secret.sh FCM_SERVICE_ACCOUNT_JSON < key.json
sudo /opt/greenroot/bin/set-secret.sh APP_ENV <<<production
sudo /opt/greenroot/bin/restart.sh
```

Then one real test: an OTP to your phone, a ₹1-plan payment and its refund
from Admin, a push to your device.

---

## 3. Releases

```bash
docker buildx build --platform linux/arm64 --build-arg VERSION=v1.4.0 -t "$REPO:v1.4.0" --push .
aws ssm send-command --instance-ids <id> --document-name AWS-RunShellScript \
  --parameters 'commands=["/opt/greenroot/bin/deploy.sh v1.4.0"]'
```

`deploy.sh` pulls the tag, applies migrations (as `greenroot_migrator`),
switches the API and waits for it to be healthy; if it is not healthy in 90 s
it starts the previous tag again. Tags are immutable in ECR; the last 20 are
kept for rollbacks (`deploy.sh <older tag>`). Migrations are additive by
convention, so an older image keeps running on a newer schema.

CI can do the same without keys: the `github_deploy_role_arn` output is an
OIDC role for the API repository's `v*` tags (ECR push + SSM send-command).

---

## 4. Backups and recovery

| Layer | What | Retention | Restore |
|---|---|---|---|
| RDS automated backups | snapshots + WAL | 14 days, to the second | Console → RDS → Restore to point in time (new instance), then point `DATABASE_URL`/`MIGRATE_DATABASE_URL` at it and `restart.sh` |
| Logical dump | `pg_dump` daily 03:30 IST, verified, with row-count manifest (`scripts/db-backup.sh`) | 35 days in a versioned, encrypted S3 bucket | `scripts/db-restore-drill.sh` against any PostgreSQL 17 (proves completeness), or `pg_restore` into a new RDS |
| Host volume | EBS snapshots (Redis AOF, Caddy certificates) | 7 daily | not needed for data: Redis holds only rate limits, sessions and caches |
| Files | S3 (11 nines durability); private documents keep old versions 30 days | — | S3 versioning |

The `backup-missing` alarm fires when no logical backup succeeded for 26 hours.
The recovery drills in CI (monthly and on every schema change) restore a
backup and a point-in-time copy and check them; run `db-restore-drill.sh`
against a downloaded production dump each quarter.

Host lost? `terraform apply` recreates it (CloudWatch also auto-recovers it
onto new hardware); then `deploy.sh <current tag>`. Data lives in RDS and S3.

---

## 5. Alarms (email)

| Alarm | Meaning / action |
|---|---|
| `PaymentIssues` | Razorpay money needs a human: Admin → Payment issues (refund or apply, then resolve with a note) |
| `RefundNotRecorded` | Money went back at Razorpay but the subscription was not updated: fix the dates by hand |
| `WebhookRetries` | Razorpay webhooks failing repeatedly (database or Razorpay trouble) |
| `ApiErrors`, `ApiPanics` | error spike in the API log: CloudWatch Logs `/greenroot/production/api` |
| `api-down` | `https://api.<domain>/health` failing from Route 53 checkers |
| `backup-missing` | no logical backup for 26 h: `journalctl -u greenroot-backup` |
| host status/CPU, db CPU/storage/memory/connections/credits | capacity: resize the instance or DB class in `terraform.tfvars` |

Logs: CloudWatch `/greenroot/production/api` (API, Caddy and Redis
containers, JSON). Mobile numbers are masked in API logs.

---

## 6. Scaling later

- More API capacity: a larger instance type first; beyond one host, move the
  API to ECS Fargate behind an ALB and Redis to ElastiCache (the API is
  stateless apart from Redis).
- Database: `db_instance_class = "db.t4g.small"` (or larger) and
  `db_multi_az = true` for automatic failover.
