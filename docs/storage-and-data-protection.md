# Storage (MinIO → S3) and data protection

Status as of 2026-10-23. What the code enforces, and what infra must set up before going live.

## 1. Buckets

| Bucket | Access | Written by |
|---|---|---|
| `profile-images` | public via CDN | server (`POST /users/me/avatar`) |
| `plant-images` | public via CDN | server |
| `market-ads` | public via CDN | server (`POST /storage/images`, MARKET_AD) |
| `nursery-logos` | public via CDN | server (`POST /storage/images`, NURSERY_BRANDING) |
| `attachments` | private (presigned GET, 1 h) | documents: app/admin direct upload (presign); photos: server (`POST /storage/images`, DRIVER_LICENCE / ATTACHMENT) |
| `delivery-photos` | private | server (`POST /storage/images`, DELIVERY_PROOF / LOADING_PROOF) |
| `loading-photos` | private | (unused) |
| `quotation-pdfs`, `order-pdfs` | private | server |
| `retention-exports` | private; **no presigned URLs**, not addressable by file URL | server only: clean-up job exports (CSV, personal data), streamed to super admins through `GET /admin/retention/jobs/{id}/export` (audit-logged), removed 30 days after the job |

**Photos are never presigned (2026-10-30).** Every photo goes through the API, which checks it against its category's image policy (`public.image_policies`, admin page *Media → Image Policies*) before storing it:
- the type comes from the bytes (JPEG or PNG, as the category allows); WebP/HEIC/GIF are refused (the apps convert to JPEG);
- the image must decode completely (truncated or corrupt files are refused);
- the header's width × height is checked against a fixed 40 MP cap **before** decoding (decompression-bomb guard), then the longest side against `max_side` and the shortest against `min_side`; sides are compared longest/shortest so EXIF rotation does not matter;
- at most 4 full decodes run at once per API instance (each can take tens of MB);
- private categories get the key prefix `u<user_id>/`, so a record can only point at its own upload (licence photos are checked this way).

Defaults: selfie 800/200 px q85 1 MB; market ad 1600/400 q82 2 MB JPEG; nursery branding 800/200 q90 1 MB (PNG kept for transparency); delivery and loading proof 2048/480 q85 3 MB JPEG; driver licence 2048/600 q90 4 MB (floors: ≥1280 px, ≥480 px short side, quality ≥80, so licences stay readable); attachment photos 4096/200 q90 8 MB. Admins change values only within bounds (side 320–4096, quality 50–95, 50 KB–10 MB); format, decode and pixel checks cannot be turned off. A change is a new version with a reason (`image_policy_versions` + audit log), applies to new uploads only (stored photos are never changed), and reaches every API instance within a minute (per-instance cache). If the table cannot be read, the API uses the last good copy, else the built-in defaults.

The apps read `GET /image-policies` and prepare each photo once: turned upright, refused with a retake hint if too small, resized to `max_side`, EXIF (GPS, camera) removed and compressed at `quality`; a photo that already meets the policy (upright, no EXIF, within size) is sent unchanged, so nothing is compressed twice. Market ads are watermarked in the same single encode. Ad photos must be files the API stored in `market-ads` (`POST /market/ads` refuses other links).

**Documents** (`POST /storage/presign`, `attachments` only): pdf, doc(x), xls(x), csv, txt, octet-stream; any `image/*` type gets 400 `use_image_upload`. The object key is a random UUID with an extension taken from the type, never from the client's file name. The `Content-Type` and `Content-Length` (≤ 20 MB) are signed into the upload URL.

**Gap:** top-item photos (`POST /top-items`) still take any URL; no app uploads them yet.

**Not enforced:** orphaned files. Files that are replaced or deleted are not cleaned up.

## 2. On AWS (deploy/terraform)

Terraform creates all of this (`deploy/terraform/storage.tf`, `cdn.tf`):

- **Nine buckets** with the prefix `greenroot-<env>-` (`STORAGE_BUCKET_PREFIX`); the code keeps the plain names.
- **Block Public Access on every bucket.** The four image buckets are served by CloudFront at `files.<domain>` through Origin Access Control: `STORAGE_PUBLIC_URL=https://files.<domain>`, file URLs `/<prefix><bucket>/<key>`. A CloudFront function strips the bucket segment for those four and answers 404 for anything else, so private buckets are never reachable through the CDN.
- **Private buckets** (licences, delivery photos, PDFs) are reachable only through presigned links from the API; old object versions are kept 30 days.
- **No storage keys:** `STORAGE_USE_IAM_ROLE=true`; the EC2 instance role grants access to the `greenroot-<env>-*` buckets only.
- **SSE-S3 encryption** on every bucket; **CORS** for PUT from the admin origin on the upload buckets.

```
STORAGE_ENDPOINT=s3.ap-south-1.amazonaws.com
STORAGE_REGION=ap-south-1
STORAGE_USE_SSL=true
STORAGE_USE_IAM_ROLE=true
STORAGE_BUCKET_PREFIX=greenroot-production-
STORAGE_PUBLIC_URL=https://files.greenroot.in
```

Stored file URLs are absolute, so changing `STORAGE_PUBLIC_URL` later needs a one-off SQL rewrite of the URL columns. Old URLs then stop resolving through `Locate` (licence photo links).

## 3. Data protection

**Never stored:**
- **Card data.** No card number, CVV or expiry is stored. Razorpay Checkout collects cards, and we keep only Razorpay order, payment and refund ids. Keep it that way: storing CVV is never allowed (PCI DSS).
- **Passwords.** Login is OTP only.

**Stored hashed:**
- **OTPs** (SHA-256, in Redis). They are single-use, expire, and lock after too many wrong guesses.
- **Refresh tokens** (SHA-256 in `user_sessions.session_token`).

**Personal data** (names, mobiles, emails, addresses with GPS, driver licence numbers) is stored in plain columns on purpose:
- Mobile is the login key, and admins search by mobile, name and licence.
- Column encryption would break lookups, uniqueness and search. It would need blind indexes and key management, which isn't worth it at this size.

It is protected instead by the following:

| Control | Where |
|---|---|
| Encryption at rest | Managed Postgres with storage encryption on (RDS/Cloud SQL); encrypted backups and snapshots |
| Encryption in transit | Production refuses to start unless `DATABASE_URL` uses `sslmode=require`/`verify-ca`/`verify-full` (pgx's default `prefer` can fall back to plaintext); a Unix socket or localhost is exempt |
| Least privilege | `roles.sql`: the app role reads and writes rows only; the migrator owns the schema |
| Access rules | RBAC per module; private files only through short presigned links (licence photo: admin and the driver) |
| Logs | Mobile numbers masked (`******0568`); crash reports scrubbed of tokens, phones and emails |

**Production startup checks** (`internal/common/config/validate.go`) refuse:
- default JWT and MinIO credentials;
- storage without TLS or an https public URL;
- a database URL that may connect unencrypted.
