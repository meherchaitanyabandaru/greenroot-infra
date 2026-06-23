# PostgreSQL

This folder contains PostgreSQL sample/demo seed assets for GreenRoot.

Schema migrations live in the API repo:

```text
greenroot-api/internal/database/migrations
```

## Seed File

```bash
greenroot-seed.sql
```

Create and seed a local development database from the API repo first:

```bash
createdb greenroot_dev
cd ../greenroot-api
DATABASE_URL='postgres:///greenroot_dev?host=/tmp' make migrate-up
```

Then load sample/demo data from this folder:

```bash
psql -v ON_ERROR_STOP=1 -d greenroot_dev -f db/postgresql/greenroot-seed.sql
```

Or from this folder:

```bash
createdb greenroot_dev
psql -v ON_ERROR_STOP=1 -d greenroot_dev -f greenroot-seed.sql
```

## Contents

The seed file includes:

* Demo seed data for local development and QA

## Notes

* This is a development seed, not production customer data.
* Apply API migrations before loading this seed.
* Do not put schema changes in this seed file.
