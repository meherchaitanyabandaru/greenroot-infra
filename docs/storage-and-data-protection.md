# Storage (MinIO → S3) and data protection

Status as of 2026-10-23. What the code enforces, and what infra must set up before going live.

## 1. Buckets

| Bucket | Access | Written by |
|---|---|---|
| `profile-images` | public via CDN | server (`POST /users/me/avatar`) |
| `plant-images` | public via CDN | server |
| `market-ads` | public via CDN | app, direct upload |
| `nursery-logos` | public via CDN | app, direct upload |
| `attachments` | private (presigned GET, 1 h) | app/admin, direct upload — driver licence photos, admin attachments |
| `delivery-photos` | private | app, direct upload |
| `loading-photos` | private | (unused) |
| `quotation-pdfs`, `order-pdfs` | private | server |

**Direct uploads** (`POST /storage/presign`) are limited to the four "app" buckets. Each bucket takes only listed types:
- images (jpeg, png, webp, heic, heif, gif);
- `attachments` also takes pdf, doc(x), xls(x), csv, txt and octet-stream.

The object key is a random UUID with an extension taken from the type, never from the client's file name. The `Content-Type` is signed into the upload URL, so a file cannot be stored, and then served from a public bucket, as HTML or SVG.

**Upload size** is enforced. The client sends `size` with the presign request; the API refuses more than 10 MB for images and 20 MB for attachments (400 `file_too_large`), and signs `Content-Length` into the URL, so storage rejects any other size.

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
