# Quotations Module

## Tables

| Table | Purpose |
|---|---|
| `quotations` | One row per quotation. Tracks type, recipient, status, totals, manager assignment. |
| `quotation_items` | Line items (plant, quantity, unit price). |

### `quotations` — key columns

| Column | Type | Notes |
|---|---|---|
| `quotation_id` | BIGSERIAL PK | Internal ID |
| `quotation_code` | VARCHAR | Public code, e.g. `QUO-000001` |
| `quotation_type` | VARCHAR | `INTERNAL` or `CUSTOMER` |
| `nursery_id` | BIGINT FK | Issuing nursery |
| `created_by_user_id` | BIGINT FK | Owner or manager who created it |
| `assigned_manager_user_id` | BIGINT FK | Optional — manager responsible |
| `buyer_nursery_id` | BIGINT FK | Buyer's nursery (CUSTOMER type only) |
| `recipient_name` | VARCHAR | Customer name (walk-in or linked buyer) |
| `recipient_mobile` | VARCHAR | Customer mobile |
| `status` | VARCHAR | See status machine below |
| `total_amount` | NUMERIC | Sum of all item totals |
| `valid_until` | TIMESTAMP | Expiry date (optional) |
| `converted_order_id` | BIGINT FK | Set when converted to an order |
| `deleted_at` | TIMESTAMP | Soft-delete |
| `notes` | TEXT | Internal notes |
| `created_at` | TIMESTAMP | |

### `quotation_items` — key columns

| Column | Type | Notes |
|---|---|---|
| `quotation_item_id` | BIGSERIAL PK | |
| `quotation_id` | BIGINT FK | |
| `plant_id` | BIGINT FK | |
| `scientific_name` | VARCHAR | Denormalized from plant catalogue |
| `common_name` | VARCHAR | Denormalized |
| `description` | TEXT | Optional line-item note |
| `quantity` | NUMERIC | |
| `unit_price` | NUMERIC | |
| `total_price` | NUMERIC | quantity × unit_price |

---

## Status Machine

```
INTERNAL type:
  INTERNAL_DRAFT → (no further transitions — planning only)

CUSTOMER type:
  CUSTOMER_DRAFT → CUSTOMER_SENT → CUSTOMER_ACCEPTED → CONVERTED
                                 ↘ CUSTOMER_REJECTED
                                 ↘ (expired via valid_until)
```

| Status | Meaning |
|---|---|
| `INTERNAL_DRAFT` | Planning-only quotation, no buyer |
| `CUSTOMER_DRAFT` | Draft for a customer, not yet sent |
| `CUSTOMER_SENT` | Sent to buyer (via `approve`) |
| `CUSTOMER_ACCEPTED` | Buyer accepted |
| `CUSTOMER_REJECTED` | Buyer rejected |
| `CONVERTED` | Linked to an order via convert-to-order |

A quotation is **expired** when `valid_until < NOW()` and status is `CUSTOMER_SENT`. This is a computed state — not a DB status column. The mobile app shows an "Expired" badge; the API respects it during buyer-accept.

---

## Business Rules

**Types**
- `INTERNAL` — no buyer required. Used for planning and internal estimates.
- `CUSTOMER` — requires recipient info. Can be sent to a buyer for acceptance.

**Editing**
- Quotations are editable (items, recipient, notes) until `approve` is called.
- Once `CUSTOMER_SENT`, the quotation is read-only.

**Approve = send to buyer**
- `POST /quotations/:id/approve` transitions `CUSTOMER_DRAFT` → `CUSTOMER_SENT`.
- Only valid for CUSTOMER type quotations.

**Delete rules**
- Only nursery **owners** can delete quotations. Managers cannot.
- Soft-delete only (`deleted_at` set). Deleted quotations are hidden from lists.
- Deletable statuses: `INTERNAL_DRAFT`, `CUSTOMER_DRAFT`, `CUSTOMER_REJECTED`, expired `CUSTOMER_SENT`.
- Cannot delete `CUSTOMER_ACCEPTED` or `CONVERTED`.

**Convert to order**
- `POST /quotations/:id/convert-to-order` links an accepted quotation to an existing order (`order_id` required in body).
- Sets `converted_order_id` and status → `CONVERTED`.

**Manager assignment**
- Owner can assign or reassign a manager via `POST /quotations/:id/assign-manager`.
- Assigned manager can view and edit the quotation.
- Managers cannot delete quotations.

**Expiry**
- `valid_until` is optional. When set and past, the quotation is treated as expired.
- An expired `CUSTOMER_SENT` quotation cannot be accepted by the buyer.

---

## RBAC

| Action | Owner | Manager | Buyer | Admin |
|---|---|---|---|---|
| Create quotation | ✅ | ✅ | — | ✅ |
| View quotation list (selling) | own nursery | own nursery | — | all |
| View quotation list (buying) | ✅ (buying=true) | — | ✅ (own) | all |
| View quotation detail | ✅ | ✅ (assigned) | own (CUSTOMER_SENT+) | all |
| Edit quotation | ✅ | ✅ | — | ✅ |
| Approve (send to buyer) | ✅ | ✅ | — | ✅ |
| Delete quotation | ✅ only | — | — | ✅ |
| Assign manager | ✅ only | — | — | ✅ |
| Buyer accept | — | — | ✅ (own) | — |
| Buyer reject | — | — | ✅ (own) | — |
| Convert to order | ✅ | ✅ | — | ✅ |

---

## API Routes

All under `/api/v1`:

```
GET    /quotations                        List quotations (selling; ?buying=true for buyer view)
POST   /quotations                        Create quotation
GET    /quotations/:id                    Get detail
PUT    /quotations/:id                    Edit (pre-approve only)
DELETE /quotations/:id                    Soft-delete (owner only)
POST   /quotations/:id/assign-manager     Assign manager (owner only)
POST   /quotations/:id/approve            Send to buyer (CUSTOMER_DRAFT → CUSTOMER_SENT)
POST   /quotations/:id/buyer-accept       Buyer accepts (CUSTOMER_SENT → CUSTOMER_ACCEPTED)
POST   /quotations/:id/buyer-reject       Buyer rejects (CUSTOMER_SENT → CUSTOMER_REJECTED)
POST   /quotations/:id/convert-to-order   Link to order (CUSTOMER_ACCEPTED → CONVERTED)
```
