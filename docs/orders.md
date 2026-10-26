# Orders Module

## Order PDF (2026-10-23)

- Rendered by the API (`GET /orders/:id/documents/render`, engine `internal/common/pdfdoc`) and archived as the official copy the QR verifies.
- **One document for every viewer** (seller side, buyer, admin): it never prints internal `notes` or the assigned manager. The API also hides those two from the buyer side (a nursery owner buying from another nursery is the buyer side).
- Shows the delivery snapshot (contact, phones, full address, landmark, delivery note).
- After loading completes, each row is billed on its loaded quantity (`COALESCE(loaded, ordered) × rate`), so rows add up to the order total; a short load shows "Ordered value / Not loaded / Total". Cancelled and partially fulfilled orders carry a callout.

## Tables

| Table | Purpose |
|---|---|
| `orders` | One row per order. Tracks buyer, nursery, status, totals, manager assignment. |
| `order_items` | Line items (plant, quantity, unit price, loaded quantity). |

### `orders` — key columns

| Column | Type | Notes |
|---|---|---|
| `order_id` | BIGSERIAL PK | Internal ID |
| `order_number` | VARCHAR | Public code, e.g. `ORD-20260622-0001` |
| `seller_nursery_id` | BIGINT FK | Selling nursery |
| `buyer_user_id` | BIGINT FK | Buyer (null for walk-in) |
| `assigned_manager_user_id` | BIGINT FK | Manager handling this order |
| `status` | VARCHAR | `PENDING` `CONFIRMED` `LOADING` `LOADED` `PARTIALLY_FULFILLED` `COMPLETED` `CANCELLED` |
| `total_amount` | NUMERIC | Recalculated at complete-loading if partially fulfilled |
| `ordered_at` | TIMESTAMPTZ | API field: `order_date` |
| `cancelled_at` | TIMESTAMPTZ | Set on cancel |
| `cancel_reason` | TEXT | Optional |
| `deleted_at` | TIMESTAMPTZ | Soft-delete (PENDING only) |

### `order_items` — key columns

| Column | Type | Notes |
|---|---|---|
| `order_item_id` | BIGSERIAL PK | |
| `order_id` | BIGINT FK | |
| `plant_id` | BIGINT FK | |
| `quantity` | NUMERIC | Ordered quantity |
| `loaded_quantity` | NUMERIC | Set during LOADING; null = not yet loaded |
| `unit_price` | NUMERIC | |
| `total_price` | NUMERIC | quantity × unit_price |

---

## Status Machine

```
PENDING → CONFIRMED → LOADING → LOADED → COMPLETED
                                       ↘ PARTIALLY_FULFILLED → COMPLETED
```

All cancel flows use `POST /orders/:id/cancel` — never a direct status update.

| Status | Meaning |
|---|---|
| `PENDING` | Created, awaiting nursery confirmation |
| `CONFIRMED` | Nursery confirmed, awaiting loading |
| `LOADING` | Loading in progress |
| `LOADED` | All quantities loaded as ordered |
| `PARTIALLY_FULFILLED` | Loading done, some quantities reduced |
| `COMPLETED` | Delivery confirmed |
| `CANCELLED` | Cancelled before dispatch |

---

## Business Rules

**Item editing window**
- Items can be added, edited, removed while status is `PENDING`, `CONFIRMED`, or `LOADING`.
- Items are locked once the order reaches `LOADED`, `PARTIALLY_FULFILLED`, or `COMPLETED`.

**Loaded quantities**
- `PUT /orders/:id/items/:itemId/loaded-quantity` sets the actual loaded amount during `LOADING`.
- At `complete-loading`: if any item has `loaded_quantity < quantity`, order moves to `PARTIALLY_FULFILLED` and total is recalculated.

**Cancel rules**

| From Status | Who Can Cancel |
|---|---|
| `PENDING` | Owner, Manager, or Buyer (own order only) |
| `CONFIRMED` | Owner or Manager only |
| `LOADING` | Owner or Manager only |
| `LOADED` | BLOCKED |
| `PARTIALLY_FULFILLED` | BLOCKED |
| `COMPLETED` | BLOCKED |

**Delete rules**
- Only `PENDING` orders can be hard-deleted (`DELETE /orders/:id`).
- All other statuses: cancel first.
- Orders are never physically deleted in production.

**Creation**
- Every order starts `PENDING`; `order_status` on create may only be empty or `PENDING` (400 otherwise).

**Assigned manager**
- Assignment does not grant access by itself: a manager who leaves the nursery loses its orders, even as the assignee.

**Partial fulfillment**
- `loaded_quantity` must be between 0 and the ordered quantity (400 otherwise).
- When `complete-loading` is called and any item has `loaded_quantity < quantity`, status → `PARTIALLY_FULFILLED`.
- Invoice totals recalculated based on loaded quantities only.

**Duplicate submits (2026-10-24)**
- `POST` with an `Idempotency-Key` header (8–64 chars) is tracked per user, method and path for 24 h (`internal/middleware/idempotency.go`, needs Redis). A retry with the same key gets the first response back (`Idempotent-Replayed: true`) instead of creating a second record. If the first request is still running, the retry gets 409 `request_in_progress`.
- Only successes are remembered: after a 4xx/5xx (or a crash) the key is released, so a corrected request runs.
- The app sends one key per create form: order (seller and buyer) and quotation. Requests without the header are unchanged.

**Delivery and its confirmation (2026-10-24)**

A dispatch (trip) goes `PENDING → (ACCEPTED) → DISPATCHED → IN_TRANSIT → DELIVERED`; delivering it completes the order. A trip is `DELIVERED` only with the **customer's** confirmation. `PUT /dispatches/:id/status` never sets `DELIVERED` (422 `delivery_confirmation_required`).

| How | Who acts | `delivery_confirmation` |
|---|---|---|
| Customer reads their 4-digit **delivery code**; the driver or the nursery enters it (`POST /dispatches/:id/deliver {code}`) | driver, owner, manager | `CUSTOMER_CODE` |
| Customer taps "I received the plants" (`POST /dispatches/:id/receipt`) | customer | `CUSTOMER_APP` |
| Nursery marks it delivered without the code, giving a reason (min 10 chars) | owner, manager (never the driver) | `UNCONFIRMED` |

- **The code** is shown only to the order's customer (`delivery_code` in their own view of the trip), only while `DISPATCHED`/`IN_TRANSIT`. Never to the seller, the driver, admins or the public tracking link. It is derived (HMAC-SHA256) from the server secret and the trip id, so it is never stored.
- **Wrong codes:** each try is counted in one UPDATE before the code is compared (`delivery_code_attempts`, audited), so parallel guesses cannot exceed the limit. The 5th locks the code for that trip (409 `delivery_code_locked`; it is no longer shown). A guess therefore succeeds 1 time in 2,000. After a lock, the customer taps "received" or the nursery uses the override.
- **Delivery may be confirmed from `DISPATCHED`.** The lorry can arrive before the driver taps Start; the customer's confirmation is what counts.
- **Override (`UNCONFIRMED`):** the customer is notified with the reason: in-app, by push, and by SMS and email (`DELIVERY_UNCONFIRMED`), so the window below is not missed. For **48 hours** after delivery they can confirm it (→ `CUSTOMER_APP`) or report a problem. The override and its author are in the audit log.
- **Public tracking link** (`GET /api/v1/track/{trip_uuid}`, no login) shows only the trip's code, status, nursery name, vehicle number, dates and, while the trip is on its way, the lorry's positions. Never the customer's address or coordinates, phone numbers, people's names, notes or internal ids.
- **Problems:** within 48 hours of any delivery the customer can report one problem (`receipt {issue}`, ≤ 500 chars). The nursery owner is notified. After 48 hours: 409 `receipt_window_closed`.
- **Joining a trip (2026-10-26):** the driver needs the trip's QR code, `TRIP-<trip_uuid>`, which the nursery shares as the QR or as text. `GET /dispatches/code/{code}` (preview) matches only `trip_uuid`, and `POST /dispatches/:id/accept {trip_code}` needs it to match. Anything else, including the sequential dispatch code or a bare id, is 404, so open trips (and the customer's address) cannot be guessed. Once a driver accepts, the QR is no longer offered.
- **Outside lorry** (`is_outside_transport`, driver without the app): the vehicle number is required; the driver's name and mobile are optional. There is no QR join (accept → 409 `outside_transport`) and no GPS. The nursery marks it dispatched, then delivers it with the customer's code.
- **Customer snapshot:** `dispatches.customer_user_id` is the order's buyer, set at creation. It decides who sees the code and who can confirm.
- **Not yet:** the code by SMS for customers without the app (needs a TRAI DLT template), and an admin screen for overrides and disputes.

---

## RBAC

| Action | Owner | Manager | Buyer | Admin |
|---|---|---|---|---|
| Create order | ✅ | ✅ | ✅ (own) | — (admins do not trade) |
| View order list | own nursery | own nursery | own orders | all |
| View order detail | own nursery | own nursery | own orders | all |
| Confirm / status change | ✅ | ✅ | — | ✅ |
| Start loading | ✅ | ✅ | — | ✅ |
| Complete loading | ✅ | ✅ | — | ✅ |
| Set loaded quantity | ✅ | ✅ | — | ✅ |
| Cancel order | ✅ | ✅ | own PENDING only | ✅ |
| Delete order | ✅ (PENDING only) | ✅ (PENDING only) | — | ✅ |
| Assign manager | ✅ (assignee must be a nursery member; not on COMPLETED/CANCELLED) | — | — | ✅ |

---

## API Routes

All under `/api/v1`:

```
GET    /orders                           List orders (scoped by role)
POST   /orders                           Create order
GET    /orders/:id                       Get order detail
DELETE /orders/:id                       Delete (PENDING only)
PUT    /orders/:id/status                Update status
POST   /orders/:id/start-loading         Transition to LOADING
POST   /orders/:id/complete-loading      Transition to LOADED or PARTIALLY_FULFILLED
POST   /orders/:id/cancel                Cancel order
POST   /orders/:id/assign-manager        Assign manager to order
GET    /orders/:id/items                 List line items
POST   /orders/:id/items                 Add item
PUT    /orders/:id/items/:itemId         Edit item
DELETE /orders/:id/items/:itemId         Remove item
PUT    /orders/:id/items/:itemId/loaded-quantity   Set loaded qty
```
