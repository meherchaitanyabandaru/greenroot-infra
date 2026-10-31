# Production rollout: data retention (migrations `20261031_03_retention_rules`, `20261031_04_market_retention`, `20261031_05_orders_quotations_retention`, `20261031_06_retention_jobs`)

> Status (2026-10-31): **ready, not deployed.** Do not deploy until the legal gates below are cleared. Policy: [`../data-retention.md`](../data-retention.md).

## What it changes

| | Before | After |
|---|---|---|
| Schema | — | Tables `retention_rules`, `retention_runs`, `retention_holds` (legal holds); `retention_runs.excluded`; 7 indexes on time columns used by cleanups |
| Rules | Hard-coded: read notifications 90 days, Mango usage 90 days (`AI_USAGE_RETENTION_DAYS`), Mango proposals 7 days | The same three as rules, **ON, same periods**; 18 new rules **OFF** (8 on legal review hold, 4 report-only) |
| Orders/quotations | — | Rule classification and period unit; financial-year functions `fy_start`, `fy_retained_until`; holds on orders, quotations, payments; 3 indexes; financial-year archive in the reports API (`fy`, `q`, `format=pdf`) |
| Clean-up jobs (`06`) | — | `retention_rules.allows_manual_jobs` (**off** for every rule; refused on held and report-only rules); job columns on `retention_runs` (date range, filters, schedule, reason, confirmed count, progress, export key and expiry); statuses `QUEUED`, `DONE`, `CANCELLED` and trigger `JOB` added; one live job per rule + range + filters (unique index). New private bucket `retention-exports` |
| API | Purges in the background loop | Retention scheduler (daily per rule, advisory lock); admin routes `/admin/retention*` |
| Admin | — | Logs → Data Retention |

No personal data is deleted by deploying this: the three ON rules do what the old code did; everything else only dry-runs.

## Gates before production (all required)

1. Legal confirmation: CERT-In 180-day logs, DPDP erasure, GPS dispute periods, GST / Income-tax / Companies Act, RBI payment data, TRAI DLT (see `data-retention.md` §4 and §4a).
2. Decision on API log retention (`LOG_RETENTION_DAYS`, today 90; CERT-In may require 180).
3. Product owner sign-off on this runbook.

None of these enable a rule; enabling any rule is a separate approval (see "Turning a rule on").

## 1. Pre-checks

1. **Backup:** confirm the managed backup and PITR window (35 days) are healthy and take an on-demand snapshot named `pre-retention-20261031_03`. Record its id.
2. **Schema baseline.** Migrations up to `20261031_02` were folded into `schema.sql` on 2026-10-31. A database must already contain everything up to that point:
   ```sql
   SELECT version FROM public.schema_migrations ORDER BY version DESC LIMIT 3;
   SELECT to_regclass('public.notifications') IS NOT NULL
      AND EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_name = 'notifications' AND column_name = 'push_status') AS has_latest_folded_change;
   ```
   `has_latest_folded_change` must be `true`. If it is `false`, the database predates the fold: stop and compare it with `schema.sql` (`pg_dump --schema-only` diff) before going on.
3. **Not already applied:** `SELECT version FROM public.schema_migrations WHERE version LIKE '20261031_0%_retention%';` → no rows. (Any row means it already ran; both are idempotent, so step 2 is then a no-op for it.)

## 2. Apply (as the migrator role)

```bash
cd greenroot-api
MIGRATE_DATABASE_URL='<greenroot_migrator URL, sslmode=verify-full>' go run ./cmd/migrate up
# expected: applied 20261031_03_retention_rules
#           applied 20261031_04_market_retention
#           applied 20261031_05_orders_quotations_retention
#           applied 20261031_06_retention_jobs
```

**Before `06` in production:** create the bucket `<prefix>retention-exports` **private** (no bucket policy, no CDN, encryption at rest, versioning off), readable and writable only by the API's role. Local MinIO and CI create it on start (`EnsureBuckets`). The API streams downloads itself; never add a public or presigned path to it.

Verify: `SELECT count(*) FROM public.retention_rules WHERE allows_manual_jobs;` → **0**.

Each migration is one transaction: it either applies fully or not at all. It is idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`) and never overwrites existing rule rows. The API refuses to start in production while a migration is pending, so this must run before the new API starts.

## 3. Verify the schema and rule states

```sql
SELECT rule_code, is_enabled, requires_legal_review, is_dry_run_only, period_days
FROM public.retention_rules ORDER BY rule_code;
```

Expected, exactly:

| rule_code | is_enabled | requires_legal_review | is_dry_run_only | period_days |
|---|---|---|---|---|
| CRASH_REPORTS | f | f | f | 90 |
| EMAIL_LOG_MASK | f | f | f | 180 |
| GPS_TRAILS | f | **t** | f | 90 |
| MARKET_AD_LOCATION | f | f | f | 90 |
| MARKET_AD_PHOTOS | f | f | **t** | 90 |
| ORDERS_COMPLETED | f | **t** | f | 8 (FY) |
| ORDERS_CANCELLED | f | **t** | f | 8 (FY) |
| PAYMENTS | f | **t** | f | 8 (FY) |
| ORDER_DOCUMENTS | f | **t** | **t** | 8 (FY) |
| DELIVERY_PROOF | f | **t** | **t** | 8 (FY) |
| QUOTATIONS_ACCEPTED | f | f | f | 8 (FY) |
| QUOTATIONS_CLOSED | f | f | f | 730 |
| QUOTATIONS_DRAFT | f | f | f | 365 |
| MANGO_PROPOSALS | **t** | f | f | 7 |
| MANGO_USAGE | **t** | f | f | 90 |
| MARKET_CHAT | f | f | f | 365 |
| NOTIFICATIONS_READ | **t** | f | f | 90 |
| ORPHAN_FILES | f | f | **t** | 30 |
| OTP_REQUEST_LOG | f | **t** | f | 30 |
| SESSIONS | f | **t** | f | 30 |
| SMS_LOG_MASK | f | f | f | 180 |

Anything else: stop, do not deploy the API, investigate.

## 4. Deploy API, then admin

Deploy the API build containing `internal/modules/retention`, then the admin build. `AI_USAGE_RETENTION_DAYS` is no longer read (the period is the `MANGO_USAGE` rule); removing it from the environment is optional.

## 5. Post-deploy checks (first 24 hours)

1. Admin → Data Retention loads; summary shows **3 rules on, 3 legal review holds, 0 failed runs**.
2. After the first scheduled pass (at API start):
   ```sql
   SELECT r.rule_code, x.mode, x.status, x.eligible, x.held, x.affected, x.error_code
   FROM public.retention_runs x JOIN public.retention_rules r USING (retention_rule_id)
   ORDER BY x.started_at DESC LIMIT 20;
   ```
   Expected: `EXECUTE` only for NOTIFICATIONS_READ, MANGO_USAGE, MANGO_PROPOSALS (counts comparable to what the old purge logged); `DRY_RUN` for the other 18 with `affected = 0`; no `FAILED`. Several API servers: one run per rule per day; any extra is `SKIPPED already_running`.
3. Send the dry-run counts (Admin → *Dry run all rules*) to the product owner.

## 6. Rollback

| Situation | Action |
|---|---|
| New API misbehaves, schema fine | Roll back the API (and admin) to the previous build. The old build ignores the new tables and runs its old purges (same three cleanups, same periods). Leave the tables in place. |
| Need to remove the schema too | After the API rollback, as the migrator: run `20261031_06_retention_jobs.down.sql` (remove job export files first: `SELECT export_object_key FROM public.retention_runs WHERE export_object_key IS NOT NULL`), then `20261031_05_orders_quotations_retention.down.sql`, then `20261031_04_market_retention.down.sql`, then `20261031_03_retention_rules.down.sql` (in `greenroot-api/internal/database/migrations`), then `DELETE FROM public.schema_migrations WHERE version IN ('20261031_03_retention_rules', '20261031_04_market_retention', '20261031_05_orders_quotations_retention', '20261031_06_retention_jobs');`. Loses only rule settings, run history and legal holds (record the active holds first: `SELECT * FROM public.retention_holds WHERE released_at IS NULL`). No personal data. |
| Data must be recovered (any cause) | Restore the `pre-retention-20261031_03` snapshot or PITR to just before the incident, per `database-operations.md` §2. Then reconcile account deletions made after the restore point (`data-retention.md` §5). |

The migration deletes nothing and the three ON rules match the old behaviour, so a data restore is not an expected part of this rollout.

## 7. Turning a rule on (later, per rule)

Only after written approval of that rule (and legal clearance for ⚖️ rules):
1. Admin → Data Retention → *Dry run* on the rule; record eligible / on hold / bytes.
2. Product owner approves those counts.
3. Super admin → *Change* → switch on with the approval reference as the reason (audit-logged). For a ⚖️ rule, first *Legal review is complete* with who confirmed it and when.
4. Next day: check the rule's `EXECUTE` run (affected ≈ approved eligible, no `FAILED`).
5. To stop at once: *Change* → switch off (takes effect from the next run; a run in progress finishes its current batch).

`ORPHAN_FILES`, `MARKET_AD_PHOTOS`, `ORDER_DOCUMENTS` and `DELIVERY_PROOF` cannot be switched on: deleting files needs a separate, reviewed code change.

**Orders, payments, quotations:** the order and payment rules (⚖️) need legal review cleared first; the quotation rules need only the approval. Each anonymises (never deletes); dry-run first and check the counts on Admin → Data Retention → Details.
