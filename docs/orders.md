# Orders Module

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
| `nursery_id` | BIGINT FK | Selling nursery |
| `buyer_user_id` | BIGINT FK | Buyer (null for walk-in) |
| `assigned_manager_user_id` | BIGINT FK | Manager handling this order |
| `status` | VARCHAR | `PENDING` `CONFIRMED` `LOADING` `LOADED` `PARTIALLY_FULFILLED` `COMPLETED` `CANCELLED` |
| `total_amount` | NUMERIC | Recalculated at complete-loading if partially fulfilled |
| `order_date` | TIMESTAMP | |
| `cancelled_at` | TIMESTAMP | Set on cancel |
| `cancel_reason` | TEXT | Optional |
| `deleted_at` | TIMESTAMP | Soft-delete (PENDING only) |

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

**Partial fulfillment**
- When `complete-loading` is called and any item has `loaded_quantity < quantity`, status → `PARTIALLY_FULFILLED`.
- Invoice totals recalculated based on loaded quantities only.

---

## RBAC

| Action | Owner | Manager | Buyer | Admin |
|---|---|---|---|---|
| Create order | ✅ | ✅ | ✅ (own) | ✅ |
| View order list | own nursery | own nursery | own orders | all |
| View order detail | own nursery | own nursery | own orders | all |
| Confirm / status change | ✅ | ✅ | — | ✅ |
| Start loading | ✅ | ✅ | — | ✅ |
| Complete loading | ✅ | ✅ | — | ✅ |
| Set loaded quantity | ✅ | ✅ | — | ✅ |
| Cancel order | ✅ | ✅ | own PENDING only | ✅ |
| Delete order | ✅ (PENDING only) | ✅ (PENDING only) | — | ✅ |
| Assign manager | ✅ | — | — | ✅ |

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
