# Data retention and deletion

> Status: **draft for approval (2026-10-31).** "Current" columns are verified against the code and the database on 2026-10-31. "Proposed" periods are **not enforced** until the product owner approves them and, where marked ⚖️, legal counsel confirms them. Until then the only automatic deletion is what the "Current" column says.

Related: [storage-and-data-protection.md](storage-and-data-protection.md) (files, hashing, encryption), [operations/database-operations.md](operations/database-operations.md) (backups, PITR), [mango-ai.md](mango-ai.md) (assistant privacy), `greenroot-docs/02-product/users-and-roles.md` (account lifecycle).

## 1. Kinds of removal

| Kind | Meaning in GreenRoot | Example |
|---|---|---|
| **Automatic deletion** | A scheduled job deletes rows past their period, in batches | Read notifications after 90 days |
| **Anonymisation** | The row stays (others depend on it); the personal fields are cleared or replaced | A deleted user becomes "Deleted", mobile `DEL<id>` |
| **Soft deletion** | A status/`deleted_at` marks the row; it is hidden but kept | Quotations, market ads, users |
| **Permanent deletion** | The row is removed at once, on request | Saved addresses and push tokens on account deletion |
| **Legal hold** | A row that would be deleted is kept because of an open dispute, report, investigation or legal duty | A trip with an open delivery issue keeps its GPS trail |

## 2. Retention matrix

Sensitivity: **High** = identifies a person or locates them (mobile, address, GPS, licence, IP); **Medium** = personal but limited (names in business records, message text); **Low** = no person, or counts only.

| # | Data (table / store) | Purpose | Sensitivity | Current (verified) | Proposed | Justification | Method | Depends on / FKs |
|---|---|---|---|---|---|---|---|---|
| 1 | Users (`users`) | Account, login by mobile | High | Kept; on account deletion anonymised in place | No change | Other records point to the user | Anonymise on deletion | ~80 FKs (orders, quotations, payments…) — row must stay |
| 2 | Saved addresses (`user_addresses`) | Delivery addresses | High (name, mobile, GPS) | Until the user deletes one. **Fixed:** removed on account deletion | Same | Orders copy the address into `order_delivery_snapshots`, so nothing needs the saved row | Permanent deletion | none reference it |
| 3 | Order delivery snapshots (`order_delivery_snapshots`) | Where an order went | High | Kept forever | ⚖️ With the order (see #13) | Proof of delivery address for disputes and tax | Keep; anonymise contact after the order period | `orders` |
| 4 | Push tokens (`user_notification_devices`) | Send pushes | High (device id) | Retired when FCM says dead or on logout. **Fixed:** deleted on account deletion | Inactive tokens deleted after 30 days | A dead token has no use | Permanent deletion | none reference it |
| 5 | Sessions (`user_sessions`) | Refresh tokens (hashed), device info | High (IP, user agent) | Kept forever; token cleared on logout. **Fixed:** device fields cleared on account deletion | ⚖️ Ended sessions: IP/user agent cleared after 180 days, row deleted after 1 year | CERT-In 2022 directions ask for ICT logs for 180 days | Anonymise, then delete (activities first: FK) | `user_activities.session_id` |
| 6 | Activity log (`user_activities`) | What a user did (login, profile, address changes) | High (copies mobile, names, address fields) | Kept forever. **Fixed:** deleted on account deletion | ⚖️ 180 days | Security investigation window (CERT-In) | Automatic deletion | → `user_sessions` |
| 7 | Live location (Redis `redisgeo`) | Driver on the map | High | Expires 90 s after the last update | No change | Live view only | Redis TTL | — |
| 8 | GPS trail (`vehicle_tracking`, `driver_locations`, `vehicle_locations`) | Trip route, delivery disputes | High | Kept forever | ⚖️ 90 days after the trip ends; kept while the trip has an open issue/risk signal (legal hold) | Delivery disputes are raised within 48 h; payment disputes later | Automatic deletion with hold | `drivers`, `vehicles`, `dispatches` |
| 9 | Trip events (`trip_events`: GPS point, photo) | Proof of loading/delivery | High | Kept forever | ⚖️ With the order (#13) | Proof of delivery | Keep with order | `dispatches` |
| 10 | SMS log (`sms_messages`: mobile, text) | Delivery status, DLT complaints | High | Kept forever | ⚖️ 180 days, then mobile masked; row deleted after 1 year | TRAI/DLT complaint handling; CERT-In logs | Anonymise, then delete | → `users` (SET NULL) |
| 11 | Email log (`email_messages`) | Delivery status | High | Kept forever | ⚖️ Same as SMS | Same | Same | → `users` (SET NULL) |
| 12 | OTP request log (`otp_requests`: mobile, IP) | Abuse detection | High | Kept forever (table unused today: OTPs live in Redis) | 180 days | Abuse window; CERT-In | Automatic deletion | — |
| 13 | Orders, quotations (`orders`, `quotations`, items, documents) | The trade | Medium (customer names, mobiles) | Kept forever; never deleted by account deletion | ⚖️ Statutory period (see §4), then anonymise customer fields | Tax and company law; disputes | Keep, then anonymise | many |
| 14 | Payments (`payments`, `payment_issues`) | Money | Medium | Kept forever | ⚖️ Statutory period (see §4); **never** auto-deleted before counsel signs off | Tax, company law, RBI data localisation | Keep | `orders`, `user_subscriptions` |
| 15 | Subscriptions (`user_subscriptions`) | Billing | Medium | Kept; status expires daily | ⚖️ Same as payments | Billing records | Keep | `payments` |
| 16 | Consent records (`consent_records`: IP, user agent) | Proof a party agreed | High | Kept forever | ⚖️ As long as the record it proves (#13) + limitation period | Evidence in disputes | Keep (legal evidence) | → `users`, orders/dispatches |
| 17 | Audit log (`audit_logs`: IP, user agent, changes) | Who changed what | High | Kept forever (append-only) | ⚖️ At least 180 days (CERT-In); propose 3 years for business changes | Security and dispute evidence | Automatic deletion or monthly partition archive | — |
| 18 | Security log (`security_audit_logs`: IP) | Logins, refusals | High | Kept forever | ⚖️ 1 year (not below 180 days) | CERT-In | Automatic deletion | — |
| 19 | Crash reports (`client_crash_reports`) | Fix app crashes | Medium (scrubbed of tokens/phones/emails) | Kept forever | 90 days | Only useful while the build is current | Automatic deletion | → `users` (SET NULL) |
| 20 | Risk signals (`risk_signals`, `risk_signal_notes`) | Fraud and abuse | Medium | Kept forever | ⚖️ Resolved: 2 years after resolution. Open or confirmed fraud: legal hold | Repeat-offender detection; investigations | Automatic deletion with hold | `risk_rules` |
| 21 | Market chat (`market_enquiries`, `market_enquiry_messages`) | Buyer–seller messages | Medium (free text) | Kept forever | 1 year after the enquiry closes; reported ones held | Both parties may need the history briefly | Automatic deletion with hold | `market_ads` |
| 22 | Market ads (`market_ads`: pickup address, GPS) | Listings | High (pickup point) | Soft-deleted / expired, kept forever | Pickup address and GPS cleared 90 days after an ad ends | Listing is over | Anonymise | `market_enquiries`, reports, saves, views |
| 23 | Notifications (`notifications`) | In-app inbox | Medium | **Read:** deleted 90 days after reading (daily job). **Unread:** kept. **Fixed:** deleted on account deletion | No change (unread are kept unless the product owner decides otherwise) | — | Automatic deletion | none reference it |
| 24 | Mango usage (`assistant_usage_events`) | Cost and limits; no content | Low | Deleted after 90 days (`AI_USAGE_RETENTION_DAYS`); unlinked on account deletion | No change | Budget | Automatic deletion | → `users` (SET NULL) |
| 25 | Mango proposals (`assistant_actions`) | Confirm-before-change | Low | Expire after 10 min; deleted after 7 days; deleted on account deletion | No change | — | Automatic deletion | → `users` (CASCADE) |
| 26 | Mango audio/text | Answering | High | Never stored by GreenRoot; OpenAI keeps abuse logs up to 30 days (chat/speech) | ⚖️ Ask OpenAI for zero data retention before launch | DPDP: processor terms | — | — |
| 27 | Uploaded files (MinIO/S3: selfies, licence photos, ad photos, PDFs, attachments) | Images and documents | High (selfie, licence) | Kept forever; profile photo removed when replaced. **Fixed:** removed on account deletion. Other replaced/orphaned files are **not** cleaned | Orphans removed after 30 days by a sweep that checks no row points to them | Storage of unused personal images | Permanent deletion (after DB) | URLs in `users`, `drivers`, `market_ads`, `trip_events`, `attachments`, `*_documents` |
| 28 | Driver licence (`drivers.licence_*`, licence photo) | Driver verification | High | Kept forever, also after account deletion | ⚖️ Needs a decision: keep for past trips' disputes vs. erase on deletion | DPDP purpose limitation vs. dispute evidence | Legal review | `dispatches.driver_id` |
| 29 | Lorry owners (`vehicle_owners`: name, mobile) | Lorry records | High | Kept forever | ⚖️ Same question as #28 | | Legal review | `vehicles` |
| 30 | Invites (`invites`: target mobile/name) | Join links | High | Kept forever. **Fixed:** pending invites a deleted user sent are cancelled | Pending: expire after 30 days; target fields cleared 90 days after use | | Anonymise | — |
| 31 | Redis short-lived keys | OTPs (5 min), email code (10 min), mobile change (5 min), rate limits, idempotency (24 h), locks (10 s), workspace cache (5 min) | High→Low | Expire on their own | No change | | Redis TTL | — |
| 32 | API log files | Operations | Medium (mobiles masked) | Deleted after 90 days (`LOG_RETENTION_DAYS`) at API start | ⚖️ Not below 180 days (CERT-In) | | Automatic deletion | — |
| 33 | Phone (on device) | Session tokens, recently viewed list | Medium | Tokens cleared on sign-out. **Fixed:** the recently viewed list is removed on account deletion | No change | | App | — |
| 34 | Database backups | Recovery | High (full copy) | Dumps pruned after `BACKUP_RETENTION_DAYS` (14 default, 35 in production docs); PITR window 35 days | 35 days, never shorter without a recovery plan | RPO/RTO targets | Rotation | see §5 |

## 3. Account deletion (implemented 2026-10-31)

`DELETE /api/v1/users/me` → `users.Service.DeleteAccount`:

1. Refused (409) while the user owns a nursery or has active orders or quotations.
2. **One transaction** (`users.PostgresRepository.SoftDeleteAccount`) — all of it happens or none:
   - user row anonymised (name "Deleted", mobile `DEL<id>`, email/photo/gender cleared, status `DELETED`)
   - sessions logged out; manager memberships and driver connections ended
   - **removed:** saved addresses, push tokens, inbox, SMS preferences, activity log, Mango proposals and daily counts
   - **cleared:** session IP, user agent, OS and token; tracking links sent to them (mobile cleared, expired)
   - **unlinked:** Mango cost rows (kept for the budget)
   - **cancelled:** pending invites they sent
3. After the commit: the profile photo file is removed from storage (best effort; a failure is logged without personal data and does not undo the deletion).
4. Access and refresh tokens stop working at once (in-memory revocation and the Redis token blocklist).
5. Audit-logged.

**Kept** (business, legal, dispute): orders, quotations, payments, subscriptions, dispatches, consent records, audit and security logs, risk signals, market messages, ratings. In them the person now shows as "Deleted".

**Older deletions:** accounts deleted before this change still had those rows. A daily job (`users.ScrubDeletedAccounts`, in the API's daily maintenance loop) applies the same removals to them, one account per transaction, up to 500 per run; it is idempotent and safe to run on several API instances at once. It cannot find their old profile photo files (the URL was already cleared) — see the orphan-file sweep (#27).

Tests: `greenroot-api/tests/api/account_deletion_test.go` (real database): personal rows removed, user anonymised, business-record counts unchanged, audit entry written, token refused; the sweep cleans an old-style deletion, runs twice in parallel without error, and leaves active accounts alone.

## 4. Indian law to confirm with counsel ⚖️

These are the laws that bear on the periods above. **The periods are for counsel to confirm; none is enforced on their basis yet.**

| Law / rule | What it means for GreenRoot | Affects |
|---|---|---|
| Digital Personal Data Protection Act 2023 and DPDP Rules | Erase personal data when the purpose is served or consent is withdrawn, unless another law requires keeping it; tell users what is kept and why | All personal data; account deletion |
| CERT-In Directions (28 Apr 2022) | Keep ICT system logs for a rolling 180 days, in India | Sessions, activity, audit/security logs, SMS/OTP logs, API logs |
| GST Act 2017, s.36 | Keep accounts and records for the period the Act sets after the annual return | Orders, invoices, payments, subscriptions |
| Income-tax Act 1961 (books of account rules) | Keep books for the period the Act sets | Same |
| Companies Act 2013, s.128 | Keep books of account for the period the Act sets | Same |
| RBI payment data storage (2018) | Payment data stored only in India | Payments, Razorpay data |
| TRAI TCCCPR 2018 (DLT) | Records needed to answer complaints about commercial SMS | SMS log |
| IT Act 2000 s.43A, SPDI Rules 2011 | Reasonable security for sensitive personal data | Licence data, all personal data |
| Limitation Act 1963 | How long a party can bring a claim (dispute evidence) | Orders, consents, trips, chats |

Open decisions for counsel: #3, #5, #6, #8–#18, #20, #26, #28, #29, #32.

## 5. Backups and deletion

- **Retention:** dumps by `scripts/db-backup.sh` are pruned after `BACKUP_RETENTION_DAYS` (default 14; production docs set 35). Managed-database backups and PITR: 35 days (`operations/database-operations.md`). Backups are never destroyed outside this rotation without an approved recovery and compliance decision.
- **Deleted data inside backups:** a backup taken before a deletion still holds the person's data until the backup expires (at most 35 days). That is the disclosure to make in the privacy notice.
- **Restore and deletion reconciliation:** restoring to an earlier point brings deleted accounts back. After any restore:
  1. List account deletions made after the restore point from the audit log export / API logs (`DELETE /users/me`, audit action `DELETE` on entity `user`).
  2. Re-apply each one: mark the user `DELETED` and anonymised as in §3 (an admin runbook step; the daily sweep then removes the rest).
  3. Record the reconciliation in the incident log.
  Without an external deletion ledger, step 1 depends on logs from after the restore point surviving — see "Remaining risks".

## 6. Remaining risks (2026-10-31)

- Most tables in the matrix have **no automatic deletion yet**; they wait for the approved periods (#5, #6, #8, #10–#12, #17–#22, #30).
- Orphaned files in storage are not swept (#27); old deleted accounts' photo files cannot be found by URL.
- Driver licence and lorry owner data after account deletion (#28, #29) need a legal decision.
- Restore reconciliation (§5) relies on logs; a small external deletion ledger would make it reliable.
- Unread notifications are kept indefinitely (by design, pending a product decision).
