# GreenRoot — Subscription Lifecycle

> Source of truth: `greenroot-api/internal/modules/subscriptions/`  
> Schema: `greenroot-infra/db/postgresql/schema.sql`
> Last updated: 2026-10-27 (monthly pricing, 1-month trial, trial-ending reminder)

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

### Plans (2026-10-27)

| Plan code | Price | Managers | Who |
|---|---|---|---|
| `TRIAL` | Free for **1 month** | 1 | Auto-created when an admin approves a nursery |
| `BASIC` — **Silver** | ₹299 / month | 1 | Owner buys in the app |
| `GROWTH` — **Gold** | ₹499 / month | 5 | Owner buys in the app ("Most popular") |
| `ENTERPRISE` — **Platinum** | ₹999 / month | 10 | Owner buys in the app |

Every plan, the trial included, has unlimited orders and quotations and can
post local market ads. Paid owners get a Silver / Gold / Platinum badge on
their profile; codes stay `BASIC` / `GROWTH` / `ENTERPRISE`. `FREE` (buyers' access) is never bought. Customers and drivers never
pay; managers are covered by their owner's plan.

**Manager limits are shown, not enforced.** Nothing stops an owner inviting
more managers than the plan says (see "What needs to be built").

### Trial flow

```
Admin approves nursery
        ↓
API auto-creates TRIAL subscription: start = approval day (IST),
end = start + 1 month − 1 day, ₹0, no payment record
        ↓
Daily job: when 2 days or fewer are left, the owner gets one in-app + push
notification ("Your free GreenRoot trial ends on 29 Oct. Choose a plan from
₹299 a month…"), linked to the subscription screen
        ↓
Home banner counts the days down (last 30 days, so the whole trial)
        ↓
Trial expires → EXPIRED (expiry worker) → owner picks a plan and pays
        ↓
Owner and managers are gated on the owner's active subscription
```

Trials created before 2026-10-27 keep their 6-month end date.

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

`subscription_plans.monthly_price` is the base. The API prices every cycle from
it (`internal/modules/subscriptions/pricing.go`):

Before GST (the owner pays these + 18%: Silver monthly ₹299 + ₹53.82 = ₹352.82):

| Cycle (`billing_cycle`) | Months | Discount | Silver | Gold | Platinum |
|---|---|---|---|---|---|
| `MONTHLY` | 1 | 0% | ₹299.00 | ₹499.00 | ₹999.00 |
| `QUARTERLY` | 3 | 5% | ₹852.15 | ₹1,422.15 | ₹2,847.15 |
| `SIX_MONTH` (half-yearly) | 6 | 10% | ₹1,614.60 | ₹2,694.60 | ₹5,394.60 |
| `YEARLY` | 12 | 15% | ₹3,049.80 | ₹5,089.80 | ₹10,189.80 |

- **Amount** = monthly × months × (100 − discount) / 100, rounded to the paisa.
  Razorpay is charged that amount in paise.
- **18% GST is added on top** (2026-10-27), after the cycle discount and any
  promo: GST = 18% of that amount, rounded to the paisa; the owner pays both.
  Razorpay is charged the total. `payments.amount` is the total and
  `payments.gst_amount` the GST inside it (NULL for payments before GST).
  Plan prices (₹299 / ₹499 / ₹999) are before tax. A GST invoice (GSTIN,
  HSN/SAC, CGST/SGST or IGST split) is still to be built; see the architecture
  review, R10.
- A promo code is applied after the cycle discount.
- `GET /subscription-plans` returns `monthly_price` and `cycle_prices`
  (`billing_cycle`, `months`, `discount_percent`, `list_amount`, `amount`,
  `per_month`) so the apps never compute a price. `six_month_price` and
  `yearly_price` follow the same math for older app builds. `yearly_price` is
  also stored, kept in step on every admin edit.
- Accepted spellings: `SEMI_ANNUAL`/`HALF_YEARLY` → `SIX_MONTH`, `ANNUAL` →
  `YEARLY`, empty → `SIX_MONTH` (older clients). Before 2026-10-27 `MONTHLY`
  meant six months; it now means one month.
- The plan list is cached in Redis (`cache:subscription_plans:v2`, 1 h,
  cleared on every admin edit).

### Breakdown shown to the owner at payment

| Line | Example (Gold, quarterly) |
|---|---|
| Gold × 3 months | ₹1,497.00 |
| Quarterly saving (5%) | −₹74.85 |
| Promo discount (if any) | −₹… |
| GST (18%) | +₹255.99 |
| **Total (incl. GST)** | **₹1,678.14** |

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

### Production hardening (2026-10-22)

| What | How |
|---|---|
| **Money is really captured** | The signature only proves *authorized*. Before extending, the API fetches the payment: it must belong to the order with the same amount; `authorized` → the API captures it; `failed` / `refunded` / `created` → refused. The method stored is the one actually used (card, UPI…), from Razorpay |
| **All or nothing** | The subscription change and its payment row are one DB transaction (`Repository.InTx`). A failed payment insert can't leave free time behind. New subscriptions are also locked per user |
| **Retries are safe** | Sending the same verified payment again (the app retrying after a timeout) returns the subscription it already paid for, not `payment_already_used`. A payment used for a *different* subscription is still refused |
| **Webhook** | `POST /api/v1/webhooks/razorpay`, verified by `X-Razorpay-Signature` (HMAC of the raw body with `RAZORPAY_WEBHOOK_SECRET`). `payment.captured` / `order.paid` apply a paid order the app never confirmed, by re-running create/renew from the order's notes (`user_id`, `subscription`, `plan_id`, `billing_cycle`, `promo_code`). The result is the same whichever arrives first, the app or the webhook. `refund.processed` / `refund.failed` record the refund status. Answers 500 only for problems a retry can fix (DB, Razorpay, lock), so Razorpay retries; if a business rule refuses the payment (e.g. paused meanwhile), it logs `paid but not applied — refund manually` |
| **Production start guard** | Production refuses to start with no keys, with `rzp_test_` keys (both allowed only with `ALLOW_MOCK_PROVIDERS` for a closed beta), or with keys but no `RAZORPAY_WEBHOOK_SECRET` |
| **App** | Checkout opens on the chosen method (UPI/Card) with the user's mobile pre-filled. Cash is removed from the app (cash is an admin "offline payment"). The app no longer signs the user out when the server is unreachable on resume (it did, right after checkout) |

**Verified live in Razorpay test mode:**
- A normal payment: the app confirms, the money is captured, and a late webhook changes nothing.
- The API was down when the user paid: the app stayed signed in, and the webhook applied the payment with real Razorpay data (`pay_TqwlQDQpR3ZXrO`, `pay_TqwsdTEVN8ZGVG`).
- Duplicate webhook deliveries: no change.
- `refund.processed` updated the earlier refund from `pending` to `processed`.

### Going live checklist (Razorpay)

1. Finish KYC in the Razorpay Dashboard and generate **live** keys. Put `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` in the secret store. **Rotate the test secret**, which was shared in chat.
2. Dashboard → Settings → **Payment capture → Automatic** (the API also captures authorized payments, but automatic is the safe default).
3. Dashboard → Webhooks → add `https://<api-host>/api/v1/webhooks/razorpay`, with events `payment.captured`, `order.paid`, `refund.processed`, `refund.failed`. Set a strong secret and put it in `RAZORPAY_WEBHOOK_SECRET`. Repeat in test mode for staging with its own secret.
4. Start the API with `APP_ENV=production`; it refuses to start if any of these are missing or still test values.
5. One real ₹1-plan payment and refund in production before announcing.
6. Watch the logs for `paid but not applied` and `refund done at Razorpay but not recorded` (alert on both).


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
A cycle buys start → start + N months − 1 day: `MONTHLY` 1, `QUARTERLY` 3,
`SIX_MONTH` 6, `YEARLY` 12, priced as in §2. `TRIAL` is 1 month at ₹0, set by
the nursery approval handler. Anything else → `400 invalid_input`.

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
  "cancel_immediately": false,
  "reason": "No longer operating"
}
```

- **Default (`cancel_immediately: false`):** a running subscription is cancelled
  at the end of its paid period. It stays `ACTIVE` with `cancel_requested_at`
  set and `auto_renew` off; at `end_date` the expiry job makes it `CANCELLED`
  (not `EXPIRED`). Renewing before then clears the request.
- **`cancel_immediately: true`:** `CANCELLED` now, no refund (refunds are an
  admin action on the payment).
- Cancelling a cancelled or expired subscription: 409.

**Payment issues (admin):** a captured Razorpay payment that a rule refuses
(e.g. the subscription was paused after checkout) and a refund Razorpay
reports as failed become rows in `payment_issues`, logged with the
`PAYMENT_ISSUE` marker (CloudWatch alarm). `GET /api/v1/payment-issues?status=OPEN`
lists them; settle each in the Razorpay dashboard, then
`POST /api/v1/payment-issues/{id}/resolve {"note": "..."}`.

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
- [x] **Monthly pricing** (2026-10-27) — four cycles from one monthly price; migration `20261027_01_monthly_plan_pricing`
- [x] **Trial-ending reminder** (2026-10-27) — daily job, once per trial, 2 days before it ends
- [ ] **Enforce manager limits** — invites ignore `max_managers`; decide what happens to owners already over their plan's limit before enforcing
- [ ] **Plan changes mid-period** — a renewal on another plan starts after the current period (no proration)
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
- Plan upgrades/downgrades have no proration logic — workaround: cancel + create new
