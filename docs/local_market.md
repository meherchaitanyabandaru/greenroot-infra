# Local Market Module

Private B2B marketplace for nursery owners and managers. Buyers and drivers have no access.

## Canonical Name

The domain is **`market`** across all layers:

| Layer | Name |
|---|---|
| DB tables | `market_ads`, `market_ad_saves`, `market_ad_views`, `market_ad_reports`, `market_enquiries`, `market_enquiry_messages` |
| Go package | `market` (`internal/modules/market`) |
| Go models | `Ad`, `Enquiry`, `Message` |
| API prefix | `/market` |
| Mobile feature | `lib/features/market/` |

## Tables

| Table | Purpose |
|---|---|
| `market_ads` | Core ad entity (plant listing posted by a nursery) |
| `market_ad_saves` | Bookmarks — one per (ad, saving nursery) |
| `market_ad_views` | View tracking — one per (ad, viewing nursery) |
| `market_ad_reports` | Admin moderation reports |
| `market_enquiries` | Enquiry from one nursery to another about an ad |
| `market_enquiry_messages` | Message thread within an enquiry |

### `market_ads` — key columns

| Column | Type | Notes |
|---|---|---|
| `ad_id` | BIGSERIAL PK | Internal ID |
| `ad_code` | VARCHAR | Public code, e.g. `MKT-000001` |
| `nursery_id` | BIGINT FK | Nursery that posted the ad |
| `created_by_user_id` | BIGINT FK | Owner or manager who created it |
| `plant_id` | BIGINT FK | Optional link to plant catalogue |
| `plant_name` | VARCHAR | Stored in full (survives catalogue changes) |
| `category_name` | VARCHAR | Denormalized category |
| `title` | VARCHAR | Ad headline |
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
| `ad_id` | BIGINT FK | The ad being enquired about |
| `ad_nursery_id` | BIGINT FK | Nursery that owns the ad |
| `enquiring_nursery_id` | BIGINT FK | Nursery making the enquiry |
| `created_by_user_id` | BIGINT FK | |
| `message` | TEXT | Initial enquiry message |
| `quantity_needed` | INTEGER | Optional |
| `status` | VARCHAR | See status machine below |
| `quotation_id` | BIGINT FK | Set when enquiry leads to a quotation |

---

## Status Machines

**Ad status**
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
| `NEW` | Sent, not yet viewed by ad nursery |
| `IN_PROGRESS` | Ad nursery is engaging |
| `QUOTATION_CREATED` | A quotation was generated from this enquiry |
| `CLOSED` | Deal done or manually closed |
| `CANCELLED` | Cancelled by enquiring nursery |

---

## Business Rules

**Access**
- Only nursery owners and managers can access the Local Market.
- Buyers and drivers have no access (API returns 403).

**Ads**
- A nursery can post any number of ads.
- Photos: max 10 per ad; index 0 is the cover photo.
- Published ads auto-expire 30 days after `published_at`.
- Ads are soft-deleted via ARCHIVED status — never hard-deleted.
- A nursery cannot enquire on its own ad.

**Enquiries**
- One enquiry per (ad, enquiring nursery). Unique constraint enforced in DB.
- Both parties can send messages in the `market_enquiry_messages` thread.
- When an enquiry leads to a quotation, `quotation_id` is set and status → `QUOTATION_CREATED`.

**Moderation**
- Any nursery can report an ad (`market_ad_reports`).
- One report per (ad, reporting user).
- Reports have `PENDING` → `REVIEWED` / `DISMISSED` flow handled by Admin.

**Delete**
- Only the nursery that created the ad can delete/archive it.
- Managers can manage ads for their nursery (same as owner for non-delete actions).

---

## RBAC

| Action | Owner | Manager | Buyer | Driver | Admin |
|---|---|---|---|---|---|
| Browse ads | ✅ | ✅ | — | — | ✅ |
| Post ad | ✅ | ✅ | — | — | ✅ |
| Edit own ad | ✅ | ✅ | — | — | ✅ |
| Archive ad | ✅ | ✅ | — | — | ✅ |
| Save ad | ✅ | ✅ | — | — | — |
| Send enquiry | ✅ | ✅ | — | — | — |
| Reply to enquiry | ✅ | ✅ | — | — | — |
| Report ad | ✅ | ✅ | — | — | — |
| Review reports | — | — | — | — | ✅ |

---

## API Routes

All under `/api/v1`:

```
GET    /market/ads                           Browse ads (search, filter by status/plant)
POST   /market/ads                           Create ad
GET    /market/ads/mine                      My nursery's ads
GET    /market/ads/saved                     Bookmarked ads
GET    /market/ads/:id                       Get ad detail
PATCH  /market/ads/:id                       Edit ad
POST   /market/ads/:id/publish               DRAFT → PUBLISHED
POST   /market/ads/:id/pause                 PUBLISHED → PAUSED
POST   /market/ads/:id/resume                PAUSED → PUBLISHED
POST   /market/ads/:id/renew                 Renew expired ad
POST   /market/ads/:id/archive               Archive ad
POST   /market/ads/:id/save                  Save/bookmark toggle
POST   /market/ads/:id/report                Submit moderation report
POST   /market/ads/:id/enquiries             Send enquiry
GET    /market/enquiries                     My nursery's enquiries (sent or received)
GET    /market/enquiries/:id                 Enquiry detail + messages
POST   /market/enquiries/:id/reply           Send message in thread
POST   /market/enquiries/:id/close           Close enquiry
POST   /market/enquiries/:id/cancel          Cancel enquiry
POST   /market/enquiries/:id/link-quotation  Link to quotation
```
