# GreenRoot — Subscription Lifecycle

> Source of truth: `greenroot-api/internal/modules/subscriptions/`  
> Schema: `greenroot-infra/db/postgresql/greenroot_schema.sql`

---

## 1. DB Tables

### `subscription_plans`

Catalog of available plans. Managed by admin. Read-only for everyone else.

| Column | Type | Notes |
|---|---|---|
| `plan_id` | `bigint` PK | Internal ID |
| `plan_code` | `varchar(50)` UNIQUE | Human-readable code e.g. `BASIC`, `PRO` |
| `plan_name` | `varchar(100)` | Display name |
| `description` | `text` | Optional |
| `monthly_price` | `numeric(12,2)` | Price for MONTHLY billing cycle |
| `yearly_price` | `numeric(12,2)` | Price for YEARLY billing cycle |
| `max_users` | `integer` | Seat limit — NULL = unlimited |
| `max_nurseries` | `integer` | Nursery limit — NULL = unlimited |
| `is_active` | `boolean` DEFAULT `true` | Only active plans can be subscribed to |
| `created_at` | `timestamp` | |
| `updated_at` | `timestamp` | |

Index: `idx_subscription_plans_active ON (is_active)`

---

### `user_subscriptions`

One row per subscription instance. A user can have at most one `ACTIVE` subscription at a time.

| Column | Type | Notes |
|---|---|---|
| `user_subscription_id` | `bigint` PK | Internal ID |
| `subscription_code` | `varchar(20)` UNIQUE | Public code: `SUB-000001` (auto-generated) |
| `user_id` | `bigint` FK → `users` | Subscriber |
| `plan_id` | `bigint` FK → `subscription_plans` | Plan at time of subscribe |
| `start_date` | `date` | Inclusive |
| `end_date` | `date` | Inclusive; NULL = open-ended |
| `subscription_status` | `varchar(30)` DEFAULT `ACTIVE` | See status machine below |
| `auto_renew` | `boolean` DEFAULT `false` | Flag only — no background job yet |
| `created_at` | `timestamp` | |
| `updated_at` | `timestamp` | |

Indexes:
- `idx_user_subscriptions_user_status ON (user_id, subscription_status)`
- `idx_user_subscriptions_plan ON (plan_id)`

---

### `payments` (subscription payments)

Shared table with orders. Subscription payments use `payment_for = 'SUBSCRIPTION'` and link via `user_subscription_id`.

Relevant columns:

| Column | Type | Notes |
|---|---|---|
| `payment_id` | `bigint` PK | |
| `payment_code` | `varchar(30)` | Public code: `PAY-000001` |
| `user_subscription_id` | `bigint` FK | Links to subscription |
| `payment_for` | `varchar(30)` | Always `'SUBSCRIPTION'` for sub payments |
| `payer_user_id` | `bigint` FK → `users` | |
| `amount` | `numeric(15,2)` | Computed from billing cycle + plan price |
| `payment_method` | `varchar(50)` | One of the allowed methods (see §4) |
| `payment_status` | `varchar(30)` | `PENDING` or `SUCCESS` |
| `payment_date` | `timestamp` | Set when status = SUCCESS |
| `provider` | `varchar(50)` | e.g. `razorpay` — NULL for offline |
| `provider_payment_id` | `varchar(255)` | Gateway payment ID |
| `provider_order_id` | `varchar(255)` | Gateway order ID |
| `provider_signature` | `text` | Gateway signature |
| `transaction_reference` | `varchar(255)` | Internal ref |
| `notes` | `text` | Auto-filled: `"Subscription created"` or `"Subscription renewed"` |

Index: `idx_payments_subscription ON (user_subscription_id)`

---

## 2. Status Machine

```
                ┌──────────────────────────────┐
                │            CREATE            │
                │       status = ACTIVE        │
                └──────────────┬───────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
          PAUSED          CANCELLED          EXPIRED
    (admin only)      (owner or admin)   (admin only)
              │
              ▼
           ACTIVE  ◄──── RENEW (owner or admin)
```

| Status | Meaning | Transitions allowed |
|---|---|---|
| `ACTIVE` | Subscription is live | → PAUSED, CANCELLED, EXPIRED (all admin); RENEW extends dates |
| `PAUSED` | Temporarily suspended | → ACTIVE, CANCELLED, EXPIRED (all admin) |
| `CANCELLED` | Terminated; `auto_renew` forced to `false` | No further transitions |
| `EXPIRED` | End date passed; `auto_renew` forced to `false` | → ACTIVE via RENEW |

**Note:** Setting status to `CANCELLED` or `EXPIRED` automatically sets `auto_renew = false` in the DB.

---

## 3. Business Rules

### Uniqueness
- A user may have **at most one ACTIVE subscription** at any time.
- `Create` checks `FindActiveByUser` before inserting. Returns `409 active_subscription_exists` if one exists.

### Plan validation
- The chosen plan must have `is_active = true`. Subscribing to an inactive plan returns `400 invalid_input`.

### Billing cycles
| Cycle value | Duration | Price used |
|---|---|---|
| `MONTHLY` (default) | start → start + 1 month − 1 day | `monthly_price` |
| `YEARLY` or `ANNUAL` | start → start + 1 year − 1 day | `yearly_price` |

Any other value → `400 invalid_input`.

### Start date
- If not provided, defaults to **today** (truncated to midnight UTC).
- Accepts `YYYY-MM-DD` format only.

### Renewal date logic
- If the current `end_date` is in the future, the new period starts the **day after** the existing end date (no gap, no overlap).
- If `end_date` is in the past or NULL, the new period starts **today**.

### Payment on create / renew
- A payment record is created automatically on `Create` and `Renew`.
- If `amount = 0` (plan has no price for the cycle), **no payment record is created**.
- Payment method defaults to `CARD` if the field is empty.
- If `provider` is empty and method is **not** `CARD`, `payment_status` is set to `SUCCESS` immediately (offline payment assumed complete).
- If `provider` is set (gateway payment), `payment_status` starts as `PENDING` — gateway confirmation is pending (see §5 — not yet wired).

### Access control (RBAC)

| Operation | Who can call |
|---|---|
| List plans | Anyone (no auth required) |
| Get plan | Anyone (no auth required) |
| List subscriptions | Own subscriptions only; Admin sees all |
| Get subscription | Own or Admin |
| Create subscription | Own; Admin can set `user_id` to create for any user |
| Update status | **Admin only** |
| Renew | Own or Admin |
| Cancel | Own or Admin |

---

## 4. Allowed Payment Methods

`UPI`, `CARD`, `CASH`, `BANK_TRANSFER`, `NET_BANKING`, `WALLET`, `COD`, `CHEQUE`, `OTHER`

Sending any other value returns `400 invalid_input`.

---

## 5. API Routes

All subscription routes are under `/api/v1`. Plans are public; subscription operations require `Authorization: Bearer <token>`.

### Plans (public)

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/subscription-plans` | List all active plans |
| `GET` | `/api/v1/subscription-plans/{id}` | Get plan by ID |

### Subscriptions (authenticated)

| Method | Path | Who | Description |
|---|---|---|---|
| `GET` | `/api/v1/subscriptions` | Owner/Admin | List; query: `user_id`, `subscription_status`, `search`, `page`, `per_page` |
| `GET` | `/api/v1/subscriptions/me` | Owner | My subscriptions (page 1, per_page 50) |
| `GET` | `/api/v1/subscriptions/{id}` | Owner/Admin | Get one by internal ID |
| `POST` | `/api/v1/subscriptions` | Owner/Admin | Create new subscription |
| `PUT` | `/api/v1/subscriptions/{id}/status` | **Admin only** | Force status to ACTIVE / PAUSED / CANCELLED / EXPIRED |
| `POST` | `/api/v1/subscriptions/{id}/renew` | Owner/Admin | Renew; extends dates + creates payment |
| `POST` | `/api/v1/subscriptions/{id}/cancel` | Owner/Admin | Cancel immediately |

---

### Request Bodies

**`POST /api/v1/subscriptions`**
```json
{
  "plan_id": 1,
  "billing_cycle": "MONTHLY",
  "start_date": "2026-07-08",
  "auto_renew": false,
  "payment_method": "UPI",
  "provider": "razorpay",
  "provider_order_id": "order_xyz"
}
```
- `plan_id` required; `billing_cycle` defaults to `MONTHLY`; `start_date` defaults to today.
- Admin only: `"user_id": 5` to create on behalf of another user.

**`PUT /api/v1/subscriptions/{id}/status`** (Admin only)
```json
{ "subscription_status": "PAUSED" }
```

**`POST /api/v1/subscriptions/{id}/renew`**
```json
{
  "billing_cycle": "YEARLY",
  "payment_method": "CASH"
}
```

**`POST /api/v1/subscriptions/{id}/cancel`**
```json
{
  "cancel_immediately": true,
  "reason": "Switching to a different plan"
}
```
- `cancel_immediately` is stored in the audit log but does not affect behaviour — cancellation is always immediate.

---

### Response Shape (subscription object)

```json
{
  "subscription": {
    "id": 1,
    "subscription_code": "SUB-000001",
    "user_id": 3,
    "plan_id": 1,
    "plan_code": "BASIC",
    "plan_name": "Basic Plan",
    "start_date": "2026-07-08T00:00:00Z",
    "end_date": "2026-08-07T00:00:00Z",
    "subscription_status": "ACTIVE",
    "auto_renew": false,
    "created_at": "2026-07-08T10:00:00Z",
    "latest_payment": {
      "id": 1,
      "payment_code": "PAY-000001",
      "amount": 499.00,
      "payment_method": "UPI",
      "payment_status": "PENDING",
      "provider": "razorpay",
      "provider_order_id": "order_xyz"
    }
  }
}
```

---

### Error Codes

| HTTP | Code | Cause |
|---|---|---|
| 400 | `invalid_input` | Bad billing cycle, inactive plan, invalid start date, bad payment method |
| 403 | `forbidden` | Non-admin trying to access/create for another user, or UpdateStatus |
| 404 | `not_found` | Subscription or plan ID does not exist |
| 409 | `active_subscription_exists` | User already has an ACTIVE subscription |
| 500 | `subscriptions_error` | Unexpected DB or server error |

---

## 6. Audit Trail

Every create, status update, renew, and cancel writes to `public.audit_logs`:

| Field | Value |
|---|---|
| `table_name` | `user_subscriptions` |
| `record_id` | `user_subscription_id` |
| `action_type` | `INSERT` (create) or `UPDATE` (all others) |
| `new_data` | JSON payload of what changed |
| `changed_by` | Actor user ID |
| `source_ip` | Request IP |
| `user_agent` | Request user agent |

---

## 7. What Is Not Yet Implemented

| Gap | Detail |
|---|---|
| **Auto-expiry job** | `auto_renew` and `end_date` exist in DB but no background cron checks and expires subscriptions. Status must be manually set to `EXPIRED` via admin API. |
| **Auto-renew job** | `auto_renew = true` is stored but no job acts on it — renewals are manual only. |
| **Payment gateway capture** | `provider`, `provider_payment_id`, `provider_signature` fields are stored but there is no Razorpay/PayU webhook handler or capture call. All gateway payments stay `PENDING` until manually updated. |
| **`cancel_immediately = false`** | The "cancel at end of period" grace behaviour is defined in the DTO but not implemented — both values result in immediate cancellation. |
| **Plan upgrades / downgrades** | No proration or mid-cycle plan change logic exists. Workaround: cancel + create new. |
| **Admin UI lifecycle forms** | Renew and cancel forms in `greenroot-admin` are not built (listed in ADMIN.md priority queue). |
