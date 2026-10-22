# GreenRoot — Subscription Lifecycle

> Source of truth: `greenroot-api/internal/modules/subscriptions/`  
> Schema: `greenroot-infra/db/postgresql/schema.sql`
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
Trial expires → `user_subscriptions.status = EXPIRED` (set by expiry job — not yet built)
        ↓
Owner must pay → in-app Razorpay screen → subscription renewed
        ↓
Manager gate checks owner's active subscription on every protected API call
```

---

### Manager / Manager-gate rule

Managers do not subscribe; the owner's subscription covers them. Built:

1. At login/refresh the access token gets the nursery (owned or managed) and the
   owner's subscription tier + end date (`auth.GetTokenContext`). PAUSED and
   CANCELLED rows don't count; an `EXPIRED` row ends no later than the day it was
   marked expired, even if its `end_date` is later.
2. Write handlers call `RequireActiveSubscription`: active → OK; up to 7 days past
   the end → OK with an `X-Subscription-Warning` header (grace); after that
   `402 subscription_expired`; no subscription → `402 subscription_required`.
   Buyers, drivers and admins are never gated.
3. **Changes apply immediately.** Every create / renew / cancel / admin status change
   marks the owner's nursery in Redis (`claims:stale:nursery:{id}`, 1 h). Access
   tokens of that nursery (owner *and* managers) issued before the change get
   `401 token_stale`; the app's refresh-and-retry picks up the new claims. Without
   this a paused owner kept working — or a paying owner stayed blocked — for up to
   the 15-minute token lifetime.

---

## 2. Pricing

### Breakdown shown to user at payment

| Line | Calculation |
|---|---|
| Plan price | ₹X |
| **Total charged** | ₹X |

### DB storage

No separate tax fields are required for the current subscription flow.

---

## 3. Razorpay Standard Checkout (2026-10-22)

Real payments run when the API has **both** `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` (local: `greenroot-api/.env`, git-ignored). With either missing, payments stay **mock** (`razorpay_mock`, journeys and local dev unchanged).

**Flow (owner taps Pay in the app):**
1. `POST /api/v1/subscriptions/payment-order` `{subscription_id?, plan_id?, billing_cycle, promo_code?}`. The API prices the plan itself (plan, cycle, promo; the app never sends an amount) and creates a Razorpay order with notes `user_id`, `subscription` (`new` or the id), `plan_id`, `billing_cycle`. It returns `{payment_order: {order_id, amount (paise), currency, key_id}}`. The secret never leaves the API.
2. The app opens Razorpay checkout (`razorpay_flutter`) with that order, and gets `razorpay_payment_id`, `razorpay_order_id`, `razorpay_signature`.
3. `POST /subscriptions` or `/subscriptions/{id}/renew` with `provider: "razorpay"`, `provider_order_id`, `provider_payment_id`, `provider_signature`. **Before** anything is created or extended, the API:
   - verifies `HMAC-SHA256(order_id|payment_id, secret)` (constant-time);
   - fetches the order from Razorpay and checks its notes match this user, subscription, plan and cycle, and that the amount matches the price;
   - rejects an order or payment already recorded (`uq_payments_provider_payment` is the last guard).

   The payment is then stored `SUCCESS` with the order id, payment id and signature.

**Renewals stack and are capped (2026-10-22).**
- A renewal starts the day after the current end date (or today, if that has passed).
- It is refused with `409 renewal_too_early` while the subscription is already paid more than **1 year** ahead (`MaxPaidAhead`). This applies to owners and admins, and also to `payment-order`, so no money is taken for a renewal that would be refused.
- Why: pressing renew three times stacked 1.5 years.
- The admin "Record Offline Payment" dialog lists **paid plans only** (it used to renew the ₹0 trial, which recorded no payment) and shows the new period before confirming.

**Rules when Razorpay is on:** owners must pay through Razorpay (mock or no provider → `400 payment_required`); admins can still record manual payments (cash, bank transfer); 100% promo (₹0) needs no payment; orders under ₹1 (100 paise) are refused.

| Error | HTTP | Code |
|---|---|---|
| Keys not configured (`payment-order` only) | 503 | `payments_unavailable` (the app falls back to mock) |
| Owner skipped payment | 400 | `payment_required` (not 402: apps read 402 as "nursery subscription expired") |
| Missing checkout fields | 400 | `invalid_input` |
| Bad signature, or order for another user/plan/cycle/amount | 400 | `payment_verification_failed` |
| Payment or order already used | 409 | `payment_already_used` |
| Razorpay down or keys rejected | 502 | `payment_gateway_error` (not 401: that would sign the user out) |

**Test mode:** card `4100 2800 0000 1007`, CVV `123`, expiry `12/26`, then choose **Success** on Razorpay's demo bank page; UPI `test@razorpay`. Verified on the emulator 2026-10-22 (Growth 6 months, ₹2,499, `PAY-20261022-0001`).

### Refunds (admin)

`POST /api/v1/subscriptions/{id}/payments/{paymentID}/refund` `{reason}`; admin UI → Subscriptions → payment row → **Refund**.

| Condition | Why |
|---|---|
| Admin only; reason required (≥ 5 chars) | Stored in `payments.notes`, `raw_response` and the audit log |
| Payment is `SUCCESS`, provider `razorpay` | Cash and bank payments are refunded outside the app |
| It is the subscription's **latest** successful payment | So exactly one paid period is undone |
| Within **7 days** of payment | Cooling-off window (`RefundWindow` in `refund.go`) |
| Full amount only | No partial refunds |

**Effect** (one transaction, after Razorpay accepts the refund):
- payment → `REFUNDED`;
- subscription `end_date` → the day before the refunded period started;
- `start_date` → when the previous period was paid for (or when the subscription was created);
- `EXPIRED` if that end date has already passed;
- tokens refreshed, expiry rescheduled.

The plan isn't restored (renewals overwrite it).

Refunds go at Razorpay's "normal" speed, 5–7 working days to the customer; the refund `status` is `pending` until then.

**Errors:**
- `409 refund_not_allowed`, with the reason;
- `409 payment_gateway_rejected`, with Razorpay's reason (e.g. already refunded);
- `503` without keys.

Verified 2026-10-22 through the admin UI: `rfnd_Tqvws48TYvSYFp` for `PAY-20261022-0001`.

If Razorpay refunds but the database write fails, the API logs `refund done at Razorpay but not recorded` with the refund id, to be fixed by hand.

**Admin "Record Offline Payment"** (was "Renew Subscription"):
- for money received outside the app (cash, bank transfer, direct UPI, cheque);
- sends no provider, so the payment is recorded `SUCCESS`;
- shows the plan's real prices.

The old dialog sent invalid methods (`NETBANKING`, `RAZORPAY_MOCK` → 400), showed made-up prices, and left payments `PENDING`.

**Not built yet:** a `payment.captured` / `payment.failed` webhook. That covers a payment that succeeds after the app was closed mid-checkout; today such a payment is taken but not applied, and the user contacts support with the payment id. 

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
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

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
| `status` | `varchar(30)` DEFAULT `ACTIVE` | See §5 (API field: `subscription_status`) |
| `is_auto_renew` | `boolean` DEFAULT `false` | Stored — no background job yet (API field: `auto_renew`) |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

Indexes:
- `idx_user_subscriptions_user_status ON (user_id, status)`
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
| `amount` | `numeric(15,2)` | Charged amount |
| `payment_method` | `varchar(50)` | See allowed methods §6 |
| `status` | `varchar(30)` | `PENDING` or `SUCCESS` (API field: `payment_status`) |
| `paid_at` | `timestamptz` | Set when SUCCESS (API field: `payment_date`) |
| `provider` | `varchar(50)` | `razorpay_mock` now; `razorpay` later |
| `provider_payment_id` | `varchar(255)` | Gateway payment ID |
| `provider_order_id` | `varchar(255)` | Gateway order ID |
| `provider_signature` | `text` | Gateway signature |
| `transaction_reference` | `varchar(255)` | Internal ref |
| `notes` | `text` | Includes mock payment remarks |

Index: `idx_payments_subscription ON (user_subscription_id)`

---

## 5. Status Machine

```
Nursery approved by admin
        ↓
  status = ACTIVE  (TRIAL plan, ₹0)
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
| `CANCELLED` | Terminated; `is_auto_renew` forced false | Owner or Admin |
| `EXPIRED` | Period ended; `is_auto_renew` forced false | Admin (manual for now); future cron |

---

## 6. Business Rules

### One active subscription per user
`Create` calls `FindActiveByUser` first. If an ACTIVE subscription exists → `409 active_subscription_exists`.

### Plan must be active
`is_active = false` plans cannot be subscribed to → `400 invalid_input`.

### Billing cycles
| Cycle | Duration | Price column |
|---|---|---|
| `SIX_MONTH` (default; `SEMI_ANNUAL`, legacy `MONTHLY`/empty) | start → start + 6 months − 1 day | `monthly_price` (holds the 6-month price) |
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
      "notes": "Mock payment — Razorpay integration pending. Total: ₹499"
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
| `changed_by_user_id` | Actor user ID |
| `source_ip` | Request IP |
| `user_agent` | Request user agent |

---

## 10. What Needs to Be Built

### DB migrations
- [x] Plans seeded: `FREE`, `TRIAL`, `GROWTH`, `ENTERPRISE` (`seed-master.sql`)

### API
- [x] **Auto-create TRIAL subscription** when admin approves a nursery (`PATCH /nurseries/{id}/status → APPROVED` handler must call `subscriptions.Create` with TRIAL plan, 6-month end_date, ₹0)
- [x] **Manager gate middleware** (see §1 — applies to owner and managers) — check nursery owner's active subscription before allowing manager API calls; return `402 subscription_required` if lapsed
- [x] **Auto-expiry cron** — daily job sets `status = EXPIRED` where `end_date < today AND status = ACTIVE` (the expiry worker in `internal/app/expiry_worker.go` now does this)
- [ ] **Auto-renew cron** — when `is_auto_renew = true` and subscription expires, trigger renewal (future)
- [ ] **Razorpay webhook handler** — receive `payment.captured` event, set `payments.status = SUCCESS` (future — when going live)

### Mobile
- [x] **Subscription status screen** — show current plan, start/end date, payment history; shown if trial expiring or expired
- [x] **Payment screen** — plan selector (Monthly / Yearly), price, total, "Pay Now" button calling mock Razorpay flow
- [x] **Trial expiry banner** — in-app banner 30 days before expiry

### Admin UI
- [x] **Renew form** — `POST /subscriptions/{id}/renew`
- [x] **Cancel form** — `POST /subscriptions/{id}/cancel`
- [ ] **Extend trial** — admin sets `end_date` via `PUT /subscriptions/{id}/status`

### Known gaps (existing code)
- `cancel_immediately = false` (cancel at end of period) is in DTO but not implemented — both values cancel immediately
- Plan upgrades/downgrades have no proration logic — workaround: cancel + create new
