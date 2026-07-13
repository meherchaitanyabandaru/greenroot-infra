# Local Reset And Redis

## Local Reset

Use `scripts/reset-dbs.sh` for daily fresh testing.

The reset rebuilds PostgreSQL from the canonical infra schema, clears app data, and loads only:

- Platform roles: `ADMIN`, `SUPER_ADMIN`, `BUYER`, `NURSERY_OWNER`, `MANAGER`, `DRIVER`
- Nursery-scoped roles
- Plant master data
- Subscription plans
- One platform admin user

Admin login for local testing:

- Mobile: `9000000000`
- Dev OTP: `123456`

`CUSTOMER` is not a platform RBAC role. Customer-facing users use the `BUYER` role. `CUSTOMER` remains valid only as a quotation/invite concept such as `quotation_type = CUSTOMER`.

`TRANSPORT_PROVIDER` is not part of the current mobile/API business flow and is not seeded for local testing.

## Redis Reset

The reset script runs `FLUSHDB` against the configured Redis DB unless `SKIP_REDIS_FLUSH=1` is set.

Redis contains temporary runtime state only:

- `otp:` login OTPs
- `blocklist:` JWT logout/delete blocklist entries
- `workspace:` per-user workspace cache
- `cache:subscription_plans` subscription plan cache
- `ad:views:` and `ad:saves:` market counters
- `notifications` stream events
- `expiry:quotations` and `expiry:subscriptions` scheduled expiry sets
- Redis GEO live driver location keys

Redis is not the source of truth for business data. PostgreSQL/PostGIS remains authoritative for persistent records, addresses, market pickup locations, delivery snapshots, and historical trip data.

## Restart Services

Use `scripts/restart-services.sh` to restart local development services:

- API: `http://localhost:8080`
- Admin UI: `http://localhost:5173`
- Mobile web: `http://localhost:4040/#/home`

Logs are written under `logs/local-services/`.
