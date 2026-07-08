# Local Market Module

Private B2B marketplace for nursery owners and managers. Buyers and drivers have no access.

## Tables

| Table | Purpose |
|---|---|
| `market_listings` | Core listing entity (ad posted by a nursery) |
| `market_listing_saves` | Bookmarks — one per (listing, saving nursery) |
| `market_listing_views` | View tracking — one per (listing, viewing nursery) |
| `market_listing_reports` | Admin moderation reports |
| `market_enquiries` | Enquiry from one nursery to another about a listing |
| `market_enquiry_messages` | Message thread within an enquiry |

> Note: `market_listings` was originally named `market_ads` — renamed in migration `000007`.

### `market_listings` — key columns

| Column | Type | Notes |
|---|---|---|
| `listing_id` | BIGSERIAL PK | Internal ID |
| `listing_code` | VARCHAR | Public code, e.g. `MKT-000001` |
| `nursery_id` | BIGINT FK | Nursery that posted the listing |
| `created_by_user_id` | BIGINT FK | Owner or manager who created it |
| `plant_id` | BIGINT FK | Optional link to plant catalogue |
| `plant_name` | VARCHAR | Stored in full (survives catalogue changes) |
| `category_name` | VARCHAR | Denormalized category |
| `title` | VARCHAR | Listing headline |
| `description` | TEXT | Full description |
| `quantity` | INTEGER | Available quantity |
| `price_per_unit` | NUMERIC | Optional price |
| `price_unit` | VARCHAR | e.g. `per plant`, `per dozen` |
| `photos` | JSONB | Ordered array; index 0 = cover (max 10) |
| `status` | VARCHAR | See status machine below |
| `view_count` | INTEGER | Denormalized for cheap reads |
| `save_count` | INTEGER | Denormalized |
| `enquiry_count` | INTEGER | Denormalized |
| `expires_at` | TIMESTAMP | Auto-expire 30 days after publish |
| `published_at` | TIMESTAMP | |

### `market_enquiries` — key columns

| Column | Type | Notes |
|---|---|---|
| `enquiry_id` | BIGSERIAL PK | |
| `enquiry_code` | VARCHAR | Public code, e.g. `ENQ-000001` |
| `listing_id` | BIGINT FK | The listing being enquired about |
| `listing_nursery_id` | BIGINT FK | Nursery that owns the listing |
| `enquiring_nursery_id` | BIGINT FK | Nursery making the enquiry |
| `created_by_user_id` | BIGINT FK | |
| `message` | TEXT | Initial enquiry message |
| `quantity_needed` | INTEGER | Optional |
| `status` | VARCHAR | See status machine below |
| `quotation_id` | BIGINT FK | Set when enquiry leads to a quotation |

---

## Status Machines

**Listing status**
```
DRAFT → PUBLISHED → PAUSED → EXPIRED → ARCHIVED
```

| Status | Meaning |
|---|---|
| `DRAFT` | Created, not visible to others |
| `PUBLISHED` | Visible to all nurseries on the platform |
| `PAUSED` | Temporarily hidden by owner |
| `EXPIRED` | Auto-expired after 30 days or manually expired |
| `ARCHIVED` | Permanently closed |

**Enquiry status**
```
NEW → IN_PROGRESS → QUOTATION_CREATED → CLOSED
                                      ↘ CANCELLED
```

| Status | Meaning |
|---|---|
| `NEW` | Sent, not yet viewed by listing nursery |
| `IN_PROGRESS` | Listing nursery is engaging |
| `QUOTATION_CREATED` | A quotation was generated from this enquiry |
| `CLOSED` | Deal done or manually closed |
| `CANCELLED` | Cancelled by enquiring nursery |

---

## Business Rules

**Access**
- Only nursery owners and managers can access the Local Market.
- Buyers and drivers have no access (API returns 403).

**Listings**
- A nursery can post any number of listings.
- Photos: max 10 per listing; index 0 is the cover photo.
- Published listings auto-expire 30 days after `published_at`.
- Listings are soft-deleted via ARCHIVED status — never hard-deleted.
- A nursery cannot enquire on its own listing.

**Enquiries**
- One enquiry per (listing, enquiring nursery). Unique constraint enforced in DB.
- Both parties can send messages in the `market_enquiry_messages` thread.
- When an enquiry leads to a quotation, `quotation_id` is set and status → `QUOTATION_CREATED`.

**Moderation**
- Any nursery can report a listing (`market_listing_reports`).
- One report per (listing, reporting user).
- Reports have `PENDING` → `REVIEWED` / `DISMISSED` flow handled by Admin.

**Delete**
- Only the nursery that created the listing can delete/archive it.
- Managers can manage listings for their nursery (same as owner for non-delete actions).

---

## RBAC

| Action | Owner | Manager | Buyer | Driver | Admin |
|---|---|---|---|---|---|
| Browse listings | ✅ | ✅ | — | — | ✅ |
| Post listing | ✅ | ✅ | — | — | ✅ |
| Edit own listing | ✅ | ✅ | — | — | ✅ |
| Archive listing | ✅ | ✅ | — | — | ✅ |
| Save listing | ✅ | ✅ | — | — | — |
| Send enquiry | ✅ | ✅ | — | — | — |
| Reply to enquiry | ✅ | ✅ | — | — | — |
| Report listing | ✅ | ✅ | — | — | — |
| Review reports | — | — | — | — | ✅ |

---

## API Routes

All under `/api/v1`:

```
GET    /market/listings                       Browse listings (search, filter by status/plant)
POST   /market/listings                       Create listing
GET    /market/listings/:id                   Get detail
PUT    /market/listings/:id                   Edit listing
DELETE /market/listings/:id                   Archive listing
POST   /market/listings/:id/publish           DRAFT → PUBLISHED
POST   /market/listings/:id/pause             PUBLISHED → PAUSED
POST   /market/listings/:id/save              Save/bookmark
DELETE /market/listings/:id/save              Remove bookmark
POST   /market/listings/:id/report            Submit moderation report
GET    /market/listings/:id/enquiries         List enquiries on a listing
POST   /market/listings/:id/enquiries         Send enquiry
GET    /market/enquiries                      My nursery's enquiries (sent or received)
GET    /market/enquiries/:id                  Enquiry detail + messages
POST   /market/enquiries/:id/messages         Send message in thread
POST   /market/enquiries/:id/close            Close enquiry
POST   /market/enquiries/:id/cancel           Cancel enquiry
```
