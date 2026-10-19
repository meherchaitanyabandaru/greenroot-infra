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
| `expires_at` | TIMESTAMPTZ | Auto-expire 30 days after publish |
| `published_at` | TIMESTAMPTZ | |

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
| `agreed_price_per_unit`, `agreed_quantity`, `agreed_at` | NUMERIC / INTEGER / TIMESTAMPTZ | Set when an offer is accepted |

`market_enquiry_messages` also carries `message_type` (`TEXT`/`OFFER`/`SYSTEM`), `offer_price_per_unit`, `offer_quantity`, `offer_status` (`PENDING`/`ACCEPTED`/`DECLINED`/`WITHDRAWN`).

---

## Status Machines

**Ad status**
```
DRAFT → PUBLISHED → PAUSED → EXPIRED → ARCHIVED
PUBLISHED/PAUSED → SUSPENDED (serious report) → PUBLISHED (admin dismisses) or REMOVED (admin upholds)
```

| Status | Meaning |
|---|---|
| `DRAFT` | Created, not visible to others |
| `PUBLISHED` | Visible to all nurseries on the platform |
| `PAUSED` | Temporarily hidden by owner |
| `EXPIRED` | Auto-expired after 30 days or manually expired |
| `ARCHIVED` | Permanently closed by the seller |
| `SUSPENDED` | Hidden by a serious report until an admin decides |
| `REMOVED` | Taken down by GreenRoot (report upheld); counts as a strike |

**Enquiry status**
```
NEW → IN_PROGRESS → DEAL_AGREED → CLOSED (seller)
  ↘──────────↘─────────────↘──→ CANCELLED (buyer)
```

| Status | Meaning |
|---|---|
| `NEW` | Sent; the seller has not written yet |
| `IN_PROGRESS` | The seller has replied or offered |
| `DEAL_AGREED` | An offer was accepted; chat stays open for pickup |
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

**Chat (enquiry)**
- The enquiry *is* the chat: one per (ad, enquiring nursery), unique in the DB. The ad's `my_enquiry_id` tells the viewer to open their existing chat instead of starting a new one.
- Both nurseries' owners and managers write in `market_enquiry_messages`. A message is `TEXT`, `OFFER` or `SYSTEM`.
- **Bargaining:** either side posts an offer (`price_per_unit`, optional `quantity` ≤ the ad's quantity). A new offer marks the chat's pending one `WITHDRAWN` (at most one `PENDING` per chat, unique index). The other nursery accepts or declines; accepting sets `DEAL_AGREED` with `agreed_price_per_unit`, `agreed_quantity`, `agreed_at` and posts a SYSTEM "Deal agreed" note. No offers after a deal; text stays open to arrange pickup.
- **Read-only:** nobody can write (409 `conflict`, `capabilities.read_only_reason` says why) once the chat is CLOSED or CANCELLED, or while its ad is not PUBLISHED (paused, expired, archived). Resuming the ad reopens it.
- Only the seller closes; only the enquiring nursery cancels; both only while the chat is open.
- No quotation link: deals happen in the chat (the old `link-quotation` route and `quotation_id` were removed 2026-10-19).

**Trust: seller selfies**
- Posting or publishing an ad and starting a chat need a profile photo (`403 selfie_required` otherwise); browsing, replying in an existing chat and reporting do not. Admins are exempt.
- The app only takes the photo with the camera (front camera, no gallery). The server cannot prove a photo came from a camera; that is a client rule. It is not identity verification and no face recognition or biometric data is used.
- `PUT /users/me` never changes the photo; only `POST/DELETE /users/me/avatar` do, and both delete the old file from storage.
- Every ad carries `posted_by_name` and `posted_by_photo`. Tapping it opens `GET /market/nurseries/{id}`: nursery name, verified flag, city, owner name and selfie, member since, ads posted, live ads, deals agreed, and the live ads. No strikes or private data.

**Moderation** (no AI: reports + automatic hiding + admin review)
- Any nursery can report an ad (`market_ad_reports`), one report per (ad, reporting user). Reasons: `EXPLICIT_CONTENT`, `PROHIBITED`, `SCAM`, `FRAUD` (fake information), `WRONG_PLANT`, `SPAM`, `DUPLICATE`, `OTHER`.
- **Serious reports hide the ad at once.** One `EXPLICIT_CONTENT` or `PROHIBITED` report moves a live or paused ad to `SUSPENDED` with a `moderation_note` the seller sees. It leaves the market, its page 404s for others, its chats turn read-only, and the seller cannot edit, resume or archive it.
- **Admin decides** (`POST /market/reports/{id}/review`, `decision`): `DISMISS` closes the report and restores a suspended ad once no serious report is open; `REMOVE` sets the ad `REMOVED` (final), closes every open report on it, and gives the nursery a strike.
- **Strikes** = the nursery's `REMOVED` ads. Strike 1: warning. Strike 2: no new or re-published ads for 30 days (`nurseries.market_blocked_until`). Strike 3+: 90 days, and the admin is prompted to suspend the nursery.
- Known gap: a rival can hide a competitor's ad with a false serious report until an admin dismisses it; reporters are named in the queue, and repeated false reports need manual action.

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
POST   /market/enquiries/:id/offers                          Make an offer (either side)
POST   /market/enquiries/:id/offers/:messageId/accept        Accept the other side's pending offer
POST   /market/enquiries/:id/offers/:messageId/decline       Decline it
```
