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
DRAFT, or PUBLISHED/PAUSED with no chats → DELETED (owner)
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
| `DELETED` | Soft-deleted by the owner: hidden everywhere (404 even for the owner), kept with `deleted_at` / `deleted_by_user_id`; admin sees it under *All ads* |

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
- Ads are never hard-deleted. The owner can **delete** (`DELETE /market/ads/{id}` → status `DELETED`) a draft, or a live/paused ad with no chats and no pending report (`capabilities.can_delete`). Anything with history (a chat, a report, expired, archived, removed) is **archived** instead, so the other side's chat and the moderation record stay intact; delete then returns 409. The check is repeated in the UPDATE, so a chat arriving mid-delete still blocks it.
- **The market is local.** Browse (and the home lists) only return ads within `radius_km` of the viewer: 60 km by default, capped at 100 km, so a nursery in Delhi never sees Andhra ads. The viewer's position is the phone's GPS (`near_lat`/`near_lon`), else their nursery's address coordinates; with neither the API answers 422 `location_required`. Ads carry `distance_km`; `sort=nearest` orders by it. A GiST index (`idx_market_ads_live_location`) serves the distance filter. Admins browse without a limit.
- **Every live ad has a location.** Posting sends the phone's GPS when allowed; otherwise the ad takes the nursery's coordinates. Publishing an ad with neither is refused, since nobody could find it. Ads published before this without a location stay live but do not appear in nearby lists until edited.
- **The app** shows "Showing ads within N km of you · Change" on the market home and an "N km" button on Browse; both open the Filters side panel (distance 10-100 km, saved per account on the phone; category; price). Location permission is asked when the Market tab is first opened.
- **Photos:** at most 3 per ad (`ck_market_ads_photos_max`); the app shrinks them when picked and uploads 1200px JPEGs. Wanted posts have none.
- **Pickup & road access (Plants I Have only):** `road_accessible` and `truck_accessible` are separate answers (a road may be too narrow for a truck; DB `is_road_accessible` / `is_truck_accessible`, NULL = not stated). A truck needs a road (`ck_market_ads_truck_needs_road`). With no road the seller must give a pickup point (`pickup_landmark`, shown as "Pickup point"; `ck_market_ads_no_road_pickup`). `access_instructions` holds directions. Wanted posts cannot carry them. The app asks both questions before Preview and shows buyers a *Pickup & access* block with a "Limited access" flag when either answer is No.
- Lists page on the server (`page`, `per_page` ≤ 50, `total`). Browse sorts: `newest` (default), `oldest`, `name` (plant name A→Z), `price_asc`, `price_desc`, `popular`. The app scrolls Browse and Saved continuously; My Ads loads every page because its tabs count on the device.
- A nursery cannot enquire on its own ad.

**Wanted posts** (`ad_type`)
- An ad is `SELL` (a nursery offers plants; the default) or `WANT` (a nursery asks for plants). Browse with `GET /market/ads?type=SELL|WANT`.
- A WANT names a catalog plant (`plant_id` required) and a size; quantity, `needed_by` (a date, not in the past) and a note are optional. It never has a price, price unit or photos (DB CHECK `ck_market_ads_want`); nurseries that have the plant tap "I have this", which opens the usual chat, and offer a price there.
- In a WANT chat the ad's nursery is the buyer. Everything else (publish, pause, 30-day expiry, chats read-only when not live, reports, strikes) works as for SELL. The app publishes a want at once (no draft step).

**Chat (enquiry)**
- The enquiry *is* the chat: one per (ad, enquiring nursery), unique in the DB. The ad's `my_enquiry_id` tells the viewer to open their existing chat instead of starting a new one.
- Both nurseries' owners and managers write in `market_enquiry_messages`. A message is `TEXT`, `OFFER` or `SYSTEM`.
- **Bargaining:** either side posts an offer (`price_per_unit`, optional `quantity` ≤ the ad's quantity). A new offer marks the chat's pending one `WITHDRAWN` (at most one `PENDING` per chat, unique index). The other nursery accepts or declines; accepting sets `DEAL_AGREED` with `agreed_price_per_unit`, `agreed_quantity`, `agreed_at` and posts a SYSTEM "Deal agreed" note. No offers after a deal; text stays open to arrange pickup.
- **Read-only:** nobody can write (409 `conflict`, `capabilities.read_only_reason` says why) once the chat is CLOSED or CANCELLED, or while its ad is not PUBLISHED (paused, expired, archived). Resuming the ad reopens it.
- Only the seller closes; only the enquiring nursery cancels; both only while the chat is open.
- No quotation link: deals happen in the chat (the old `link-quotation` route and `quotation_id` were removed 2026-10-19).

**Trust: seller photos**
- The poster's profile photo is shown on every ad and chat; it is not required to post, publish or chat (a required selfie was tried on 2026-10-19 and dropped as needless friction).
- The app only takes the photo with the camera (front camera, no gallery). The server cannot prove a photo came from a camera; that is a client rule. It is not identity verification and no face recognition or biometric data is used.
- `PUT /users/me` never changes the photo; only `POST/DELETE /users/me/avatar` do, and both delete the old file from storage.
- Every ad carries `posted_by_name` and `posted_by_photo`. Tapping it opens `GET /market/nurseries/{id}`: nursery name, verified flag, city, owner name and selfie, member since, ads posted, live ads, deals agreed, and the live ads. No strikes or private data.

**Moderation** (no AI: reports + automatic hiding + admin review)
- Any nursery can report an ad (`market_ad_reports`), one report per (ad, reporting user). Reasons: `EXPLICIT_CONTENT`, `PROHIBITED`, `SCAM`, `FRAUD` (fake information), `WRONG_PLANT`, `SPAM`, `DUPLICATE`, `OTHER`.
- **Serious reports hide the ad at once.** One `EXPLICIT_CONTENT` or `PROHIBITED` report moves a live or paused ad to `SUSPENDED` with a `moderation_note` the seller sees. It leaves the market, its page 404s for others, its chats turn read-only, and the seller cannot edit, resume or archive it.
- **Admin decides** (`POST /market/reports/{id}/review`, `decision`): `DISMISS` closes the report and restores a suspended ad once no serious report is open; `REMOVE` sets the ad `REMOVED` (final), closes every open report on it, and gives the nursery a strike.
- **Strikes** = the nursery's `REMOVED` ads. Strike 1: warning. Strike 2: no new or re-published ads for 30 days (`nurseries.market_blocked_until`). Strike 3+: 90 days, and the admin is prompted to suspend the nursery.
- **Admin → Local Market** has two tabs. *Reports*: the queue (open count on the tab), Restore/Dismiss or Remove. *All ads*: every ad in any status (`GET /market/admin/ads?status=&search=`), under-review and reported ads first, with photos, poster selfie, open reports and the nursery's strikes. From an ad the admin can **Hide for review** (live/paused → SUSPENDED, note required), **Restore** (SUSPENDED → PUBLISHED, open reports dismissed), **Remove** (→ REMOVED with a note and a strike, as an upheld report) via `POST /market/admin/ads/{id}/moderate`, and **Unblock** the nursery early (`POST /market/admin/nurseries/{id}/unblock`).
- Not enforced yet: the plan feature `market_posts_per_day` (Free 0, Trial 3, Growth 5) is editable in Admin → Subscriptions but the API ignores it; it belongs with plan-limit enforcement in the subscriptions work (`max_managers` is not enforced either).
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
DELETE /market/ads/:id                       Delete own ad (soft; drafts or no-chat live/paused ads)
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
