# Database Operations

How the GreenRoot PostgreSQL database is run in production: roles, backups, point-in-time recovery, restore drills, server settings and monitoring. Standards: `greenroot-docs/06-decisions/enterprise-engineering-standards.md` (D8–D12).

## 1. Roles (D9)

Create once per database, as the admin user, after the schema exists:

```bash
psql "$ADMIN_DATABASE_URL" -v ON_ERROR_STOP=1 -f db/postgresql/roles.sql
psql "$ADMIN_DATABASE_URL" -c "ALTER ROLE greenroot_migrator PASSWORD '<secret store>'" \
                           -c "ALTER ROLE greenroot_app PASSWORD '<secret store>'" \
                           -c "ALTER ROLE greenroot_readonly PASSWORD '<secret store>'"
```

| Role | Used by | Can |
|---|---|---|
| `greenroot_owner` | nobody logs in | owns every schema object |
| `greenroot_migrator` | `cmd/migrate` (`MIGRATE_DATABASE_URL`) | DDL, acting as the owner |
| `greenroot_app` | the API (`DATABASE_URL`) | read/write rows; no DDL, no `TRUNCATE`; 30 s statement timeout |
| `greenroot_readonly` | reporting, support | `SELECT` only |

The API refuses a production start if its role is a superuser, bypasses RLS, owns objects or can create in `public`. `roles.sql` is idempotent: re-run it after restoring a backup into a new server.

## 2. Backups and recovery (D11)

**Targets:** RPO ≤ 5 minutes, RTO ≤ 1 hour, backups kept 35 days, one restore drill per month.

Two layers:

| Layer | What it gives | How |
|---|---|---|
| **Point-in-time recovery** | Restore to any second in the retention window (RPO ≈ seconds) | Continuous WAL archiving by the host — see below |
| **Logical backups** | A portable, verifiable snapshot that restores into any PostgreSQL 17 | `scripts/db-backup.sh`, daily |

### Point-in-time recovery — by host

| Host | Setting |
|---|---|
| Azure Database for PostgreSQL – Flexible Server | Backup retention **35 days**; **geo-redundant backup** on; zone-redundant high availability for the RTO |
| AWS RDS / Aurora PostgreSQL | Automated backups, retention **35 days**; Multi-AZ; copy snapshots to a second region |
| Self-managed | `pgBackRest` with `archive_mode = on`, `archive_command = 'pgbackrest --stanza=greenroot archive-push %p'`, full backup weekly + differential daily, repository in a different region; `archive_timeout = 60` keeps the RPO under 5 minutes on quiet systems |

Record the chosen host and its settings in this file when production is provisioned. **Until a host exists, production RPO/RTO are targets, not measurements**; the drills above prove the procedure and the tooling.

### Logical backups

```bash
DATABASE_URL=<greenroot_readonly URL> BACKUP_DIR=/var/backups/greenroot BACKUP_RETENTION_DAYS=35 scripts/db-backup.sh
```

- The dump and a **manifest** (row count per table + applied migrations) come from one `REPEATABLE READ` snapshot, so the manifest exactly describes the dump even while the database is being written.
- Each dump is checked with `pg_restore --list` and gets a SHA-256 file. Files are created `0600` (dumps hold personal data). Copy them to storage in another region with encryption at rest.

### Point-in-time recovery drill

```bash
scripts/pitr-drill.sh
```

Proves the PITR mechanism end to end on a throwaway PostgreSQL 17 cluster: continuous WAL archiving → base backup → writes after the backup → disaster (`TRUNCATE orders CASCADE`) → restore the base backup and replay WAL to the second before the disaster → verify that the orders and items are back, the post-backup write was replayed and every constraint is valid. Managed hosts and pgBackRest use the same WAL mechanism; on a managed host, also run the host's own restore-to-time into a new server once per quarter.

**Automated:** `.github/workflows/recovery-drills.yml` runs the PITR drill and the backup/restore drill on every push to this repo and on the 1st of every month (PostgreSQL 17 + PostGIS from PGDG).

### Restore drill — monthly and after every schema change

```bash
ADMIN_DATABASE_URL=postgres://admin@host/postgres BACKUP_DIR=/var/backups/greenroot scripts/db-restore-drill.sh
```

The drill verifies the checksum, restores the newest dump into a scratch database, compares it with the manifest (every table's row count and the migration list), checks that every constraint is valid, reports how long the restore took, and drops the scratch database. It exits non-zero on any mismatch. Record each run:

| Date | Backup | Result | Restore time | By |
|---|---|---|---|---|
| 2026-10-17 | local CI database | ✅ 77 tables match, migrations match, constraints valid | 1 s | development check |
| 2026-10-17 | PITR drill (local PG 17.10) | ✅ recovered to the second before `TRUNCATE orders CASCADE`; 5 orders + 8 items back; post-backup write replayed | 1–2 s | development check |

Verified failure modes (2026-10-17): a tampered manifest and a corrupted dump both fail the restore drill; replaying WAL *through* the disaster fails the PITR drill (orders 0, expected 5).

**Full recovery runbook:**
1. Restore: PITR to the chosen time on the host, or `pg_restore` the latest dump into a new database.
2. `psql -f db/postgresql/roles.sql` and set role passwords.
3. `MIGRATE_DATABASE_URL=... go run ./cmd/migrate status` — nothing pending.
4. Point the API's `DATABASE_URL` at the restored database; check `/readyz`.

## 3. Server settings

| Setting | Value | Why |
|---|---|---|
| `shared_preload_libraries` | `pg_stat_statements` | query statistics (then `CREATE EXTENSION pg_stat_statements;` as admin) |
| `pg_stat_statements.track` | `top` | |
| `log_min_duration_statement` | `500ms` | slow-query log |
| `log_lock_waits` | `on` | |
| `track_io_timing` | `on` | |
| `timezone` | `UTC` | server default; the API sets its own session zone (`DB_TIMEZONE`, default `Asia/Kolkata`) |
| `ssl` / `require_secure_transport` | on | TLS only; app connection strings use `sslmode=verify-full` |
| `idle_in_transaction_session_timeout` | `60s` (also set on `greenroot_app`) | |
| Connection pooling | PgBouncer in transaction mode, or the host's built-in pooler | the API opens up to `DB_MAX_OPEN_CONNS` (25) per instance |

## 4. Monitoring

Alert on: replication/backup failure, storage > 80 %, connections > 80 % of `max_connections`, p95 query time > 300 ms (from `pg_stat_statements`), any `deadlock_detected`, a restore drill older than 35 days.

```sql
-- Slowest queries by total time
SELECT calls, round(total_exec_time) AS total_ms, round(mean_exec_time, 1) AS mean_ms, left(query, 120)
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;

-- Largest tables
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)), n_live_tup
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;
```

## 5. Growth and retention (D10)

Append-only tables: `audit_logs`, `security_audit_logs`, `user_activities`, `user_sessions`, `sms_messages`, `email_messages`, `vehicle_locations`. They are indexed by time today. **Partition by month when a table passes ~10 million rows** (declarative partitioning; detach and archive old partitions instead of deleting rows).

Retention periods are a legal decision (DPDP Act 2023, TRAI record-keeping, tax law). **Owner action:** confirm one period per table and record it here before go-live. Until then nothing is deleted.

## 6. Botanical names (World Flora Online)

`public.botanical_names` holds every scientific plant name from the [WFO taxonomic backbone](https://www.worldfloraonline.org/downloadData): ~1.66 M rows (453 k accepted, 1.02 M synonyms, 182 k unchecked). It is reference data for validating names and mapping synonyms; the catalog stays in `public.plants`, linked by `plants.wfo_id`. Neither the 910 MB download nor the cleaned file is in git (`.gitignore`).

Run once per database, after loading `schema.sql`, from `greenroot-api`:

```bash
# 1. Put the WFO download at greenroot-infra/classification.csv (tab separated), then clean it.
#    Keeps 8 columns, validates every row, writes greenroot-infra/db/seed-data/botanical_names.csv (~160 MB).
go run ./cmd/botanicalnames clean

# 2. Load in batches of 5000 (as greenroot_app; ~2 min locally with the search indexes).
DATABASE_URL=... go run ./cmd/botanicalnames load
```

- **Search:** `schema.sql` includes `pg_trgm` and a trigram index, so picker searches over all names take a few milliseconds. If the migrator role may not create extensions, run `CREATE EXTENSION pg_trgm;` once as the admin before `migrate up`.
- **Linking:** after loading, `load` runs `link`, which sets `plants.wfo_id` for catalog plants entered by hand whose scientific name means exactly one species; ambiguous ones are listed as "still unlinked" for an admin. `go run ./cmd/botanicalnames link` runs it alone.
- **Resume:** each batch commits together with its row count in `public.import_checkpoints`. If the load stops (Ctrl-C, lost connection, container stop), run the same command again; it continues after the last committed row. Running it after it finished does nothing.
- **New WFO release:** download, `clean`, then `load -restart`. Rows are upserted by `wfo_id`, so names already linked from `plants` keep their IDs.
- **Licence:** WFO data requires attribution; check the terms on the WFO site before showing it in the apps.
