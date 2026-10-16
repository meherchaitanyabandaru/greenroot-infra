# Upgrade migrations

`schema.sql` + `seed-*.sql` build a **fresh** database (`scripts/reset-dbs.sh`).
The files here upgrade an **existing** database (staging, production) without
losing data. Apply them in filename order, before deploying the API version
that needs them:

```bash
for f in db/postgresql/migrations/*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

| File | Adds | Needed by |
|---|---|---|
| `20261016_001_messaging_sms_email.sql` | SMS (DLT) and email tables + system templates | greenroot-api 427eb67+ (SMS), 06678e2+ (email) |
| `20261016_002_fk_lookup_indexes.sql` | 4 indexes on foreign keys used in read paths | — (performance only) |

Rules for new migrations:

- **Idempotent:** use `IF NOT EXISTS`, and `ON CONFLICT DO NOTHING` / `WHERE NOT EXISTS` for seed rows, so a re-run is harmless and never overwrites admin edits.
- **Indexes on live tables:** use `CREATE INDEX CONCURRENTLY`, with no `BEGIN`/`COMMIT` in that file.
- **Keep `schema.sql` in sync:** after applying locally, refresh it with `pg_dump --schema-only --no-owner --no-privileges` and check the diff contains only your change.
- **Test before committing:** run the file twice against a database built from the previous `schema.sql`, then compare the affected tables with a fresh install.
