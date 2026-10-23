# Storage (MinIO → S3) and data protection

Status as of 2026-10-23. What the code enforces, and what infra must set up before going live.

## 1. Buckets

| Bucket | Access | Written by |
|---|---|---|
| `profile-images` | public read | server (`POST /users/me/avatar`) |
| `plant-images` | public read | server |
| `market-ads` | public read | app, direct upload |
| `nursery-logos` | public read | app, direct upload |
| `attachments` | private (presigned GET, 1 h) | app/admin, direct upload — driver licence photos, admin attachments |
| `delivery-photos` | private | app, direct upload |
| `loading-photos` | private | (unused) |
| `quotation-pdfs`, `order-pdfs` | private | server |

**Direct uploads** (`POST /storage/presign`) are limited to the four "app" buckets. Each bucket takes only listed types:
- images (jpeg, png, webp, heic, heif, gif);
- `attachments` also takes pdf, doc(x), xls(x), csv, txt and octet-stream.

The object key is a random UUID with an extension taken from the type, never from the client's file name. The `Content-Type` is signed into the upload URL, so a file cannot be stored, and then served from a public bucket, as HTML or SVG.

**Not enforced:**
- **Upload size.** Presigned PUT cannot limit it; that needs presigned POST, which means an app change.
- **Orphaned files.** Files that are replaced or deleted are not cleaned up.

## 2. Moving to AWS S3

S3 bucket names are global, so set a prefix. The code keeps using the plain names.

```
STORAGE_ENDPOINT=s3.ap-south-1.amazonaws.com
STORAGE_REGION=ap-south-1
STORAGE_USE_SSL=true                      # required in production
STORAGE_BUCKET_PREFIX=greenroot-prod-     # → greenroot-prod-attachments, ...
STORAGE_PUBLIC_URL=https://files.greenroot.in   # https required in production
STORAGE_ACCESS_KEY=… STORAGE_SECRET_KEY=…  # IAM user limited to the greenroot-prod-* buckets
```

Production does not create buckets at startup. Infra must:
- **Create the buckets:** all nine, with the prefix.
- **Make four of them public-read:** `profile-images`, `plant-images`, `market-ads` and `nursery-logos`. This needs S3 Block Public Access relaxed for those buckets only, or a CloudFront distribution in front of them.
- **Keep the rest private.**
- **Turn on default encryption.** SSE-S3 is on by default for new S3 buckets. MinIO needs KMS for encryption at rest.
- **Allow CORS for PUT from the admin origin.** The admin uploads attachments from the browser.

`STORAGE_PUBLIC_URL` must serve `/<bucket>/<key>`: path-style through a CDN or the S3 endpoint. Stored file URLs are absolute, so changing this later needs a one-off SQL rewrite of the URL columns. Old URLs then stop resolving through `Locate` (licence photo links).

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
