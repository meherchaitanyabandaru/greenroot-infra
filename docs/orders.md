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
- `complete-loading` requires `{"declared_no_prohibited_items": true}`: the owner/manager declares the vehicle carries no drugs, illegal or unauthorised items. Without it → 400 `loading_declaration_required`. The declaration is kept in the audit log (who = `loading_completed_by_user_id`).
- Loading photos: up to 3 optional photos of the loaded vehicle, taken in the app's "Loading done" sheet, compressed like all photos, stored in the private `delivery-photos` bucket and attached with `entity_type = ORDER_LOADING`, `entity_id = order_id`.
- `GET /orders/:id/loading-proof` — for anyone who can see the order (buyer, seller owner/staff, admin): the photos as 1-hour signed links, the declaration, who completed loading and when, and the truck (vehicle, driver, mobile; null until a trip exists). In the app: photo/truck icon on the timeline's "Loading Complete" step (seller), "Loading photos & truck" tile (buyer).

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

A dispatch (trip) goes `PENDING → (ACCEPTED) → (DISPATCHED) → IN_TRANSIT → DELIVERED`; delivering it completes the order. Since 2026-10-28 the driver may start straight from `ACCEPTED` (`PUT status IN_TRANSIT`): trips exist only for loaded orders, so the app no longer offers the owner "Mark Dispatched" for app-driver trips (`can_mark_dispatched` only for outside lorries). Starting from `ACCEPTED` sends the customer the same "on the way" notification as `DISPATCHED`. A trip is `DELIVERED` only with the **customer's** confirmation. `PUT /dispatches/:id/status` never sets `DELIVERED` (422 `delivery_confirmation_required`).

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
- **The trip QR is the driver invitation (2026-10-28):** There are no dedicated drivers assigned to individual nurseries. When an owner or manager creates a dispatch, they can optionally specify the required lorry type (TRUCK, VAN, PICKUP, AUTO; empty = any). Any approved, active GreenRoot driver with the required vehicle type can preview and accept the trip directly by scanning its QR code or entering the trip code. The trip invitation itself is the driver invitation; no separate driver invitation or nursery membership is required. The trip QR expires after 72 hours (staff can renew with `POST /dispatches/:id/new-invite`). Acceptance is atomic; if multiple drivers attempt to accept, only the first succeeds (subsequent attempts receive 409 `trip_taken`). A driver already on an active trip is refused (409 `active_driver_trip`). If a trip is cancelled, further accepts return 409 `trip_cancelled`. Genuinely nonexistent codes return 404.
- **Status words (2026-10-28):** everyone sees the same words, from `lifecycle/display.go`: Pending → Confirmed → Loading → Loaded → *Waiting for Driver / Arranging Delivery* (trip PENDING) → **Driver Assigned** (ACCEPTED) → **On the Way** (DISPATCHED and IN_TRANSIT) → Delivered. Once a trip exists, the owner's and driver's order label follows it (the list no longer says "Loaded" while the truck is out). "Mark Dispatched" (`can_mark_dispatched`) is offered only for outside lorries.
- **GPS (2026-10-28):** the app sends a point every ~30 s from a location foreground service ("Delivery in progress") while the trip is IN_TRANSIT, also off the map screen and with the screen locked; it resumes when the app reopens mid-trip and stops on delivery, when the driver's Home no longer shows the trip in transit (e.g. cancelled), or on a 409 from the next point. Points that fail for lack of signal are held (up to 500) and sent later with `recorded_at` (`POST /tracking`, optional; within the last 12 h, not in the future, else 400).
- **Event times (2026-10-28):** each step records when it happened, and timelines show only recorded times ("Wed, 28 Oct · 10:42 AM"), never a guessed one. Order: `ordered_at`/`created_at`, `confirmed_at`, `loading_started_at`, `loading_completed_at`. Trip: `created_at`, `driver_accepted_at` (accept), `dispatched_at` (marked dispatched, or the driver started without a hand-over), `trip_started_at` + `trip_started_by_user_id` (IN_TRANSIT), `delivered_at` / `delivery_confirmed_at`. Trips from before this have no accept/start time and show those steps without one. Who confirmed or started loading is not recorded, so those steps read "By the nursery".
- **Delivery address after the order ends:** `PUT /orders/:id/delivery` is refused for COMPLETED or CANCELLED orders (409), including an emergency update; the address is the record of where the plants went.
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
GET    /orders/:id/loading-proof         Loading photos (signed), declaration, truck
POST   /orders/:id/complete-loading      Transition to LOADED or PARTIALLY_FULFILLED (needs declared_no_prohibited_items)
POST   /orders/:id/cancel                Cancel order
POST   /orders/:id/assign-manager        Assign manager to order
GET    /orders/:id/items                 List line items
POST   /orders/:id/items                 Add item
PUT    /orders/:id/items/:itemId         Edit item
DELETE /orders/:id/items/:itemId         Remove item
PUT    /orders/:id/items/:itemId/loaded-quantity   Set loaded qty
```
