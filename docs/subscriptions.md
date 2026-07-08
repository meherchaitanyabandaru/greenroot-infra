# GreenRoot — Subscription Lifecycle

> Source of truth: `greenroot-api/internal/modules/subscriptions/`  
> Schema: `greenroot-infra/db/postgresql/greenroot_schema.sql`  
> Last updated: 2026-07-08

---

## 1. Business Model (Decided)

### Who pays

| Role | Subscription | Reason |
|---|---|---|
| Nursery Owner | **Paid** (after free trial) | Primary revenue source — sells plants, manages orders, uses full platform |
| Manager | **None — inherits from nursery owner** | If owner's subscription lapses → manager is blocked from all activity |
| Customer / Buyer | **Free forever** | More buyers = more value for owners; charging buyers kills the marketplace |
| Driver | **Free forever** | Platform benefit — delivery network |

**Subscription unit: per nursery owner (user_id of the owner).** One owner = one nursery (enforced by API). The owner's subscription covers their nursery and every manager/driver attached to it.

---

### Plans

| Plan code | Price | Period | Assigned by |
|---|---|---|---|
| `TRIAL` | ₹0 | 6 months from nursery approval date | Auto-created by API when admin approves a nursery |
| `STANDARD` | ₹TBD/month or ₹TBD/year | Ongoing after trial | Owner subscribes via in-app payment screen |

Only these two plans. No Basic/Pro tiers initially — add tiers later based on real usage data.

**`TRIAL` plan must be seeded in `subscription_plans`:**
```sql
INSERT INTO public.subscription_plans
  (plan_code, plan_name, description, monthly_price, yearly_price, max_users, max_nurseries, is_active)
VALUES
  ('TRIAL',    'Free Trial',     '6-month free trial for new nursery owners', 0.00, 0.00, NULL, 1, true),
  ('STANDARD', 'Standard Plan',  'Full platform access for nursery owners',   NULL, NULL, NULL, 1, true);
-- Prices for STANDARD to be set once decided.
```

---

### Trial flow

```
Admin approves nursery
        ↓
API auto-creates TRIAL subscription
  start_date = approval date
  end_date   = approval date + 6 months
  amount     = ₹0  →  no payment record created
        ↓
Owner uses platform freely for 6 months
        ↓
[TODO] 30 days before expiry → push notification + in-app banner
        ↓
Trial expires → subscription_status = EXPIRED (set by expiry job — not yet built)
        ↓
Owner must pay → in-app Razorpay screen → subscription renewed
        ↓
Manager gate checks owner's active subscription on every protected API call
```

---

### Manager / Manager-gate rule

Managers do not subscribe. On every manager API call the middleware must:

1. Look up the nursery the manager belongs to.
2. Check that the nursery owner has an `ACTIVE` subscription (end_date ≥ today).
3. If not → return `402 subscription_required`.

**This gate is not yet implemented in the API.** It is a required build item (see §8).

---

## 2. GST & Pricing

Subscription services fall under **SAC code 997331** (software licensing / SaaS).  
GST rate: **18%** (9% CGST + 9% SGST for intra-state; 18% IGST for inter-state).

### Breakdown shown to user at payment

| Line | Calculation |
|---|---|
| Plan price (base) | ₹X |
| GST @ 18% | ₹X × 0.18 |
| **Total charged** | ₹X × 1.18 |

### DB storage

Two columns to be **added to `payments`** (not yet in schema):

| Column | Type | Notes |
|---|---|---|
| `tax_amount` | `numeric(12,2)` | GST amount in ₹ |
| `tax_rate` | `numeric(5,2)` | Rate applied e.g. `18.00` |

Until the migration is done, store the GST note in the `notes` field as:  
`"Subscription renewed. Base: ₹X, GST 18%: ₹Y, Total: ₹Z"`

---

## 3. Mock Razorpay (Current Phase)

Real Razorpay integration comes later. For now:

**Mobile payment screen shows:**
- Plan name + billing cycle selector (Monthly / Yearly)
- Base price
- GST 18% line
- Total
- "Pay Now" button

**On tap "Pay Now":**
- Mobile calls `POST /api/v1/subscriptions/{id}/renew` with:
  ```json
  {
    "billing_cycle": "MONTHLY",
    "payment_method": "UPI",
    "provider": "razorpay_mock",
    "provider_order_id": "MOCK-ORDER-<timestamp>"
  }
  ```
- API creates payment record with `payment_status = SUCCESS`, `notes = "Mock payment — Razorpay integration pending"`, `provider = "razorpay_mock"`.
- Response shows updated subscription with `latest_payment.payment_status = "SUCCESS"`.

**When real Razorpay is wired:**
- Replace `provider = "razorpay_mock"` with real Razorpay SDK flow.
- Add webhook handler to receive `payment.captured` event and call `UpdateStatus` on the payment record.
- No DB schema changes needed — all fields already exist.

---

## 4. DB Tables

### `subscription_plans`

| Column | Type | Notes |
|---|---|---|
| `plan_id` | `bigint` PK | Internal ID |
| `plan_code` | `varchar(50)` UNIQUE | `TRIAL`, `STANDARD` |
| `plan_name` | `varchar(100)` | Display name |
| `description` | `text` | Optional |
| `monthly_price` | `numeric(12,2)` | ₹0.00 for TRIAL; TBD for STANDARD |
| `yearly_price` | `numeric(12,2)` | ₹0.00 for TRIAL; TBD for STANDARD |
| `max_users` | `integer` | NULL = unlimited |
| `max_nurseries` | `integer` | 1 for both plans (one owner = one nursery) |
| `is_active` | `boolean` DEFAULT `true` | |
| `created_at` | `timestamp` | |
| `updated_at` | `timestamp` | |

Index: `idx_subscription_plans_active ON (is_active)`

---

### `user_subscriptions`

One row per subscription instance. A user may have at most one `ACTIVE` subscription at a time.

| Column | Type | Notes |
|---|---|---|
| `user_subscription_id` | `bigint` PK | |
| `subscription_code` | `varchar(20)` UNIQUE | Auto-generated: `SUB-000001` |
| `user_id` | `bigint` FK → `users` | The nursery owner |
| `plan_id` | `bigint` FK → `subscription_plans` | Plan at time of create/renew |
| `start_date` | `date` | Inclusive |
| `end_date` | `date` | Inclusive; NULL = open-ended |
| `subscription_status` | `varchar(30)` DEFAULT `ACTIVE` | See §5 |
| `auto_renew` | `boolean` DEFAULT `false` | Stored — no background job yet |
| `created_at` | `timestamp` | |
| `updated_at` | `timestamp` | |

Indexes:
- `idx_user_subscriptions_user_status ON (user_id, subscription_status)`
- `idx_user_subscriptions_plan ON (plan_id)`

---

### `payments` (subscription payments)

Subscription payments share the `payments` table with order payments. Identified by `payment_for = 'SUBSCRIPTION'`.

| Column | Type | Notes |
|---|---|---|
| `payment_id` | `bigint` PK | |
| `payment_code` | `varchar(30)` | Auto-generated: `PAY-000001` |
| `user_subscription_id` | `bigint` FK | Links to subscription |
| `payment_for` | `varchar(30)` | Always `'SUBSCRIPTION'` |
| `payer_user_id` | `bigint` FK → `users` | Nursery owner |
| `amount` | `numeric(15,2)` | **Base price only** (excl. GST until tax columns added) |
| `payment_method` | `varchar(50)` | See allowed methods §6 |
| `payment_status` | `varchar(30)` | `PENDING` or `SUCCESS` |
| `payment_date` | `timestamp` | Set when SUCCESS |
| `provider` | `varchar(50)` | `razorpay_mock` now; `razorpay` later |
| `provider_payment_id` | `varchar(255)` | Gateway payment ID |
| `provider_order_id` | `varchar(255)` | Gateway order ID |
| `provider_signature` | `text` | Gateway signature |
| `transaction_reference` | `varchar(255)` | Internal ref |
| `notes` | `text` | Includes mock/GST remarks |
| `tax_amount` ⚠️ | `numeric(12,2)` | **To be added** — GST amount in ₹ |
| `tax_rate` ⚠️ | `numeric(5,2)` | **To be added** — e.g. `18.00` |

⚠️ = column not yet in schema. Migration required.

Index: `idx_payments_subscription ON (user_subscription_id)`

---

## 5. Status Machine

```
Nursery approved by admin
        ↓
  subscription_status = ACTIVE  (TRIAL plan, ₹0)
        ↓
        ├──────────────────────────────┐
        ▼                              ▼
     PAUSED                       CANCELLED
  (admin only)               (owner or admin)
        │
        ▼
     ACTIVE  ◄──── RENEW (owner pays → STANDARD plan)
        │
        ▼
     EXPIRED  ◄──── end_date passed (admin sets, or future cron)
        │
        └──── RENEW (owner pays again → back to ACTIVE)
```

| Status | Meaning | Who can trigger |
|---|---|---|
| `ACTIVE` | Subscription live — owner + managers can operate | Created on approve; restored by RENEW |
| `PAUSED` | Temporarily suspended by admin | Admin only |
| `CANCELLED` | Terminated; `auto_renew` forced false | Owner or Admin |
| `EXPIRED` | Period ended; `auto_renew` forced false | Admin (manual for now); future cron |

---

## 6. Business Rules

### One active subscription per user
`Create` calls `FindActiveByUser` first. If an ACTIVE subscription exists → `409 active_subscription_exists`.

### Plan must be active
`is_active = false` plans cannot be subscribed to → `400 invalid_input`.

### Billing cycles
| Cycle | Duration | Price column |
|---|---|---|
| `MONTHLY` (default) | start → start + 1 month − 1 day | `monthly_price` |
| `YEARLY` / `ANNUAL` | start → start + 1 year − 1 day | `yearly_price` |

TRIAL plan uses `monthly_price = 0` but is always created with a fixed 6-month `end_date` (set by the nursery approval handler — not by billing cycle math).

### Renewal date
- If existing `end_date` is in the future → new period starts the day after (no gap, no overlap).
- If `end_date` is past or NULL → new period starts today.

### Payment on create / renew
- If `amount = 0` (TRIAL) → **no payment record created**.
- Payment method defaults to `CARD` if not supplied.
- `provider` empty + method ≠ `CARD` → `payment_status = SUCCESS` immediately (offline cash/UPI assumed done).
- `provider` set (Razorpay mock or real) → `payment_status = PENDING` until webhook updates it.

### RBAC

| Operation | Nursery Owner | Manager | Buyer | Driver | Admin |
|---|---|---|---|---|---|
| List plans | ✅ | ✅ | ✅ | ✅ | ✅ |
| Get plan | ✅ | ✅ | ✅ | ✅ | ✅ |
| List subscriptions | Own only | ❌ | ❌ | ❌ | All |
| Get subscription | Own only | ❌ | ❌ | ❌ | ✅ |
| Create subscription | Own only | ❌ | ❌ | ❌ | Any user |
| Update status | ❌ | ❌ | ❌ | ❌ | ✅ |
| Renew | Own only | ❌ | ❌ | ❌ | ✅ |
| Cancel | Own only | ❌ | ❌ | ❌ | ✅ |

---

## 7. Allowed Payment Methods

`UPI`, `CARD`, `CASH`, `BANK_TRANSFER`, `NET_BANKING`, `WALLET`, `COD`, `CHEQUE`, `OTHER`

Any other value → `400 invalid_input`.

---

## 8. API Routes

All under `/api/v1`. Plans are public (no auth). All subscription routes require `Authorization: Bearer <token>`.

### Plans

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/subscription-plans` | None | List active plans |
| `GET` | `/api/v1/subscription-plans/{id}` | None | Get plan by ID |

### Subscriptions

| Method | Path | Who | Description |
|---|---|---|---|
| `GET` | `/api/v1/subscriptions` | Owner / Admin | List; filters: `user_id`, `subscription_status`, `search`, `page`, `per_page` |
| `GET` | `/api/v1/subscriptions/me` | Owner | Own subscriptions (page 1, per_page 50) |
| `GET` | `/api/v1/subscriptions/{id}` | Owner / Admin | Get one by ID |
| `POST` | `/api/v1/subscriptions` | Owner / Admin | Create |
| `PUT` | `/api/v1/subscriptions/{id}/status` | **Admin only** | Force status change |
| `POST` | `/api/v1/subscriptions/{id}/renew` | Owner / Admin | Renew + create payment |
| `POST` | `/api/v1/subscriptions/{id}/cancel` | Owner / Admin | Cancel |

### Request bodies

**`POST /api/v1/subscriptions`**
```json
{
  "plan_id": 2,
  "billing_cycle": "MONTHLY",
  "start_date": "2026-07-08",
  "auto_renew": false,
  "payment_method": "UPI",
  "provider": "razorpay_mock",
  "provider_order_id": "MOCK-ORDER-1720432800"
}
```

**`PUT /api/v1/subscriptions/{id}/status`** (Admin only)
```json
{ "subscription_status": "EXPIRED" }
```

**`POST /api/v1/subscriptions/{id}/renew`**
```json
{
  "billing_cycle": "YEARLY",
  "payment_method": "UPI",
  "provider": "razorpay_mock",
  "provider_order_id": "MOCK-ORDER-1720432900"
}
```

**`POST /api/v1/subscriptions/{id}/cancel`**
```json
{
  "cancel_immediately": true,
  "reason": "No longer operating"
}
```

### Response (subscription object)

```json
{
  "subscription": {
    "id": 1,
    "subscription_code": "SUB-000001",
    "user_id": 2,
    "plan_id": 1,
    "plan_code": "TRIAL",
    "plan_name": "Free Trial",
    "start_date": "2026-07-08T00:00:00Z",
    "end_date": "2027-01-07T00:00:00Z",
    "subscription_status": "ACTIVE",
    "auto_renew": false,
    "created_at": "2026-07-08T10:00:00Z",
    "latest_payment": null
  }
}
```

For a paid renewal:
```json
{
  "subscription": {
    "plan_code": "STANDARD",
    "subscription_status": "ACTIVE",
    "latest_payment": {
      "payment_code": "PAY-000002",
      "amount": 499.00,
      "payment_method": "UPI",
      "payment_status": "SUCCESS",
      "provider": "razorpay_mock",
      "provider_order_id": "MOCK-ORDER-1720432900",
      "notes": "Mock payment — Razorpay integration pending. Base: ₹499, GST 18%: ₹89.82, Total: ₹588.82"
    }
  }
}
```

### Error codes

| HTTP | Code | Cause |
|---|---|---|
| 400 | `invalid_input` | Bad billing cycle, inactive plan, invalid date, bad payment method |
| 402 | `subscription_required` | Manager/owner action blocked — no active subscription (gate not yet built) |
| 403 | `forbidden` | Non-admin accessing another user's subscription or UpdateStatus |
| 404 | `not_found` | Subscription or plan not found |
| 409 | `active_subscription_exists` | User already has an ACTIVE subscription |
| 500 | `subscriptions_error` | Unexpected server/DB error |

---

## 9. Audit Trail

Every create, status update, renew, and cancel writes to `public.audit_logs`:

| Field | Value |
|---|---|
| `table_name` | `user_subscriptions` |
| `record_id` | `user_subscription_id` |
| `action_type` | `INSERT` (create) or `UPDATE` (all others) |
| `new_data` | JSON of changed fields |
| `changed_by` | Actor user ID |
| `source_ip` | Request IP |
| `user_agent` | Request user agent |

---

## 10. What Needs to Be Built

### DB migrations
- [ ] Add `tax_amount numeric(12,2)` and `tax_rate numeric(5,2)` columns to `payments`
- [ ] Seed `TRIAL` and `STANDARD` plans in `subscription_plans`

### API
- [ ] **Auto-create TRIAL subscription** when admin approves a nursery (`PATCH /nurseries/{id}/status → APPROVED` handler must call `subscriptions.Create` with TRIAL plan, 6-month end_date, ₹0)
- [ ] **Manager gate middleware** — check nursery owner's active subscription before allowing manager API calls; return `402 subscription_required` if lapsed
- [ ] **`tax_amount` / `tax_rate`** stored on payment create and renew
- [ ] **Auto-expiry cron** — daily job sets `subscription_status = EXPIRED` where `end_date < today AND subscription_status = ACTIVE`
- [ ] **Auto-renew cron** — when `auto_renew = true` and subscription expires, trigger renewal (future)
- [ ] **Razorpay webhook handler** — receive `payment.captured` event, set `payment_status = SUCCESS` (future — when going live)

### Mobile
- [ ] **Subscription status screen** — show current plan, start/end date, payment history; shown if trial expiring or expired
- [ ] **Payment screen** — plan selector (Monthly / Yearly), base price, GST 18% line, total, "Pay Now" button calling mock Razorpay flow
- [ ] **Trial expiry banner** — in-app banner 30 days before expiry

### Admin UI
- [ ] **Renew form** — `POST /subscriptions/{id}/renew`
- [ ] **Cancel form** — `POST /subscriptions/{id}/cancel`
- [ ] **Extend trial** — admin sets `end_date` via `PUT /subscriptions/{id}/status`

### Known gaps (existing code)
- `cancel_immediately = false` (cancel at end of period) is in DTO but not implemented — both values cancel immediately
- Plan upgrades/downgrades have no proration logic — workaround: cancel + create new
