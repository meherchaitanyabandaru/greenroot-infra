# Quotations Module

## Nursery Identity Rule

> **A quotation always represents the Nursery as the issuing business — not the individual Owner or Manager.**

- Every quotation PDF header shows the Nursery name, address, and contact details as the issuer.
- The Owner or Manager shown under **"Validated By"** is the person who officially downloaded or shared that PDF on behalf of the Nursery.
- "Validated By" is derived from the authenticated user at download time — the frontend never supplies the validator name.
- Every official PDF generation (download, WhatsApp share, share sheet) is recorded in `audit_logs` via `POST /quotations/:id/record-download`. The record captures the user, their role scope, and whether customer data was masked.

## Customer Privacy Rule

> **Customer identity belongs to the nursery owner. Managers may work on quotation content but must not receive real customer-identifying information.**

- `recipient_name` and `recipient_mobile` are **never returned** to manager-only actors (actors who have `MANAGER` role but not `NURSERY_OWNER`/`ADMIN`).
- Masking is enforced by the backend (`redactCustomerContact()` in `service.go`). The mobile and admin clients never need to re-mask API data.
- Admins (`ADMIN`/`SUPER_ADMIN`) receive full customer data (support access).
- PDF generation is client-side. Because the API already strips fields for managers, the PDF builder receives nil values and renders an explicit "🔒 Customer details protected" block in the "TO" section instead of blank.
- Privacy is **independent of assignment**: the owner always sees full customer data even when a manager is the exclusive editor, and a manager always sees masked data even if they are the assignee.

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
| `valid_until` | TIMESTAMP | Expiry date — set by owner on create/edit; falls back to 15 days after Approve if not set |
| `rejection_reason` | TEXT | Set by buyer on reject; stored separately, never appended to notes |
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

**Conversion lock**
- Once a quotation is converted to an order (`status = 'CONVERTED'`, `converted_order_id` set), it is permanently read-only.
- Blocked for all roles (including admin): `Update`, `Delete`, `AssignManager`, `UnassignManager`.
- These return **409 Conflict** (`already_converted`).
- Allowed actions on a CONVERTED quotation: view, download PDF, print, share, navigate to linked order.
- The linked order code (`converted_order_code`) and conversion timestamp (`converted_at`) are returned in the API response.

**Editing (exclusive-editor rule)**
- Quotations are editable (items, recipient, notes) until `approve` is called.
- Once `CUSTOMER_SENT`, the quotation is read-only.
- **When a quotation has an `assigned_manager_user_id`, only that assignee may edit its content (`PUT /quotations/:id`).** All other users, including the owner, are read-only.
- The owner regains edit access by first reassigning the quotation to themselves (`POST /quotations/:id/assign-manager` with their own `user_id`) or removing the assignment entirely (`DELETE /quotations/:id/assign-manager`).
- State transitions (Approve, Recall, Convert to Order) are NOT restricted by assignment — any authorized user may trigger them regardless of who is the assignee.

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

**Manager visibility (private-default model)**
- Quotations are private-default: a manager can only see quotations they **created** or are **assigned to** (`assigned_manager_user_id = manager's user_id`).
- Owners see all quotations in their nursery regardless of assignment.
- This applies to both `GET /quotations` (list) and `GET /quotations/:id` (detail). A manager cannot bypass the list scope by calling the detail endpoint directly.

**Manager assignment**
- Owner can **assign** a manager via `POST /quotations/:id/assign-manager`.
- Owner can **unassign** a manager via `DELETE /quotations/:id/assign-manager`.
- Owner can **pre-assign** on create by including `assigned_manager_user_id` in the `POST /quotations` body (validated against nursery membership).
- Managers cannot assign, unassign, or pre-assign managers.
- Once assigned, the manager becomes the **exclusive editor** of that quotation (see "Editing" section above).
- There is always at most one assignee at any time — reassigning replaces the previous assignee atomically.

**Expiry / valid_until**
- `valid_until` is set by the owner (or manager) on create or edit via `valid_until` in the request body.
- If the owner did not set it, `valid_until` is auto-set to `NOW() + 15 days` when `approve` is called.
- Once in `CUSTOMER_SENT`, an expired quotation (where `valid_until < NOW()`) cannot be accepted by the buyer.
- Mobile: create/edit screens show a "Valid Until" date picker below the Notes field.

**Rejection reason**
- When the buyer rejects (`POST /quotations/:id/buyer-reject`), they supply an optional `reason` string.
- The reason is stored in the `rejection_reason` column — it is never appended to `notes`.
- Visible to owners, admins, and the buyer. Hidden from managers (via the standard customer-privacy masking).
- Mobile: shown as a red "Rejection Reason" card on the detail screen when `status = CUSTOMER_REJECTED`.
- Admin: shown as "Rejection Reason" section in the quotation detail panel.

**Push Notifications (IN_APP channel)**
| Event | Recipient |
|---|---|
| Owner assigns manager | Assigned manager |
| Owner approves (sends to buyer) | Buyer (if `customer_user_id` set) |
| Buyer accepts | Nursery owner |
| Buyer rejects | Nursery owner |

---

## RBAC

| Action | Owner | Manager | Buyer | Admin |
|---|---|---|---|---|
| Create quotation | ✅ | ✅ | — | ✅ |
| Pre-assign manager on create | ✅ only | — | — | ✅ |
| View quotation list (selling) | all in nursery | created by or assigned to them | — | all |
| View quotation list (buying) | ✅ (buying=true) | — | ✅ (own) | all |
| View quotation detail | ✅ | created by or assigned to them only | own (CUSTOMER_SENT+) | all |
| **See recipient_name / recipient_mobile** | **✅ full** | **❌ always nil (backend-masked)** | own only | **✅ full** |
| Edit quotation content | assignee only (or owner when unassigned) | assignee only | — | ✅ |
| Approve (send to buyer) | ✅ | ✅ (if can view) | — | ✅ |
| Delete quotation | ✅ only | — | — | ✅ |
| Assign manager | ✅ only | — | — | ✅ |
| Unassign manager | ✅ only | — | — | ✅ |
| Buyer accept | — | — | ✅ (own) | — |
| Buyer reject | — | — | ✅ (own) | — |
| Convert to order | ✅ | ✅ (if can view) | — | ✅ |

---

## API Routes

All under `/api/v1`:

```
GET    /quotations                        List (selling; ?buying=true for buyer view; ?unassigned=true for owner unassigned tab)
POST   /quotations                        Create quotation (body: assigned_manager_user_id optional, owner-only)
GET    /quotations/:id                    Get detail
PUT    /quotations/:id                    Edit (pre-approve only)
DELETE /quotations/:id                    Soft-delete (owner only)
POST   /quotations/:id/assign-manager     Assign or reassign manager (owner only)
DELETE /quotations/:id/assign-manager     Remove manager assignment (owner only)
POST   /quotations/:id/approve            Send to buyer (CUSTOMER_DRAFT → CUSTOMER_SENT)
POST   /quotations/:id/recall             Recall sent quotation (CUSTOMER_SENT → CUSTOMER_DRAFT)
POST   /quotations/:id/buyer-accept       Buyer accepts (CUSTOMER_SENT → CUSTOMER_ACCEPTED)
POST   /quotations/:id/buyer-reject       Buyer rejects (CUSTOMER_SENT → CUSTOMER_REJECTED); body: {reason?: string}
POST   /quotations/:id/convert-to-order   Link to order (CUSTOMER_ACCEPTED → CONVERTED)
POST   /quotations/:id/record-download    Record PDF generation/download audit event (any authorized viewer); body: {masked?: bool}
```

### List query params (selling view)

| Param | Values | Notes |
|---|---|---|
| `buying` | `true` | Switch to buyer-side view |
| `unassigned` | `true` | Owner tab: only unassigned quotations |
| `search` | string | Free-text search on recipient, code |
| `status` | status string | Filter by status |
| `date_from` | `YYYY-MM-DD` | Created on or after this date |
| `date_to` | `YYYY-MM-DD` | Created before the day after this date (inclusive) |
| `amount_min` | number | Minimum `total_amount` |
| `amount_max` | number | Maximum `total_amount` |
| `page`, `per_page` | int | Pagination |
| `sort_by`, `sort_order` | string | Sort field and `asc`/`desc` |

> Manager list is automatically scoped server-side; clients don't need to pass extra params.
