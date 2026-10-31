# Data retention and deletion

> Status (2026-10-31): the rules below are **configured in Admin → Data retention** (super admin; every change needs a reason and is audit-logged). Periods marked *provisional* were approved by the product owner as operational settings, **not** as legal confirmation. **Every new rule is switched off**; only the three cleanups that already ran before (read notifications, Mango usage, Mango proposals) are on, with their old periods. Rules marked ⚖️ **legal hold** cannot be switched on until legal review clears them (the API and the database both refuse). The uploaded-files rule only reports. Nothing below was run against production.

Related: [storage-and-data-protection.md](storage-and-data-protection.md) (files, hashing, encryption), [operations/database-operations.md](operations/database-operations.md) (backups, PITR), [mango-ai.md](mango-ai.md) (assistant privacy), `greenroot-docs/02-product/users-and-roles.md` (account lifecycle).

## 0. Rules in the admin UI (implemented 2026-10-31)

| Rule (code) | Data | Action | Period | State | Why |
|---|---|---|---|---|---|
| `NOTIFICATIONS_READ` | Read in-app notifications | Delete | 90 days after read | **On** (as before) | Unread ones are never deleted (product decision pending) |
| `MANGO_USAGE` | Mango cost/usage rows (no content) | Delete | 90 days | **On** (as before; replaces `AI_USAGE_RETENTION_DAYS`) | |
| `MANGO_PROPOSALS` | Mango proposals | Delete | 7 days | **On** (as before) | |
| `CRASH_REPORTS` | App crash reports | Delete | 90 days (provisional) | Off | Awaiting the go-ahead to enable |
| `SMS_LOG_MASK` | SMS log | Mask mobile to last 4 digits, remove text | 180 days (provisional) | Off | TRAI/DLT question (§4) |
| `EMAIL_LOG_MASK` | Email log | Mask address to domain, remove body | 180 days (provisional) | Off | |
| `MARKET_CHAT` | Market chat messages | Delete (enquiry row kept) | 1 year after the **enquiry** closed (provisional) | Off | Held by a pending report or a legal hold on the enquiry or its ad; the ad ending never starts the clock |
| `MARKET_AD_LOCATION` | Market ads: pickup address, landmark, GPS | Mask (clear) | 90 days after the ad ended (deleted / removed / archived / expired) | Off | Excluded while an enquiry is open; held by a pending report or legal hold. Plant, description, price and enquiries stay |
| `MARKET_AD_PHOTOS` | Market ad photos | **Report only** | 90 days after the ad ended (deleted / removed / archived) | Report only (can never delete) | Excluded while an enquiry is open or closed within the period, or the file is used by another record; held by a pending report or legal hold. Also counts market photos nothing points to (replaced uploads) |
| `OTP_REQUEST_LOG` | OTP request log (mobile, IP) | Delete | 30 days (proposed) | Off, ⚖️ **legal hold** | CERT-In 180-day logs (§4a) |
| `SESSIONS` | Login sessions (IP, user agent, device) | Delete (activities kept, unlinked) | 30 days idle (proposed) | Off, ⚖️ **legal hold** | CERT-In 180-day logs (§4a) |
| `GPS_TRAILS` | Trip GPS points, driver location points | Delete (trip record kept) | 90 days after the trip ended (proposed) | Off, ⚖️ **legal hold** | Dispute evidence; held per trip with a delivery issue or an open risk signal |
| `ORPHAN_FILES` | Stored files nothing points to | **Report only** | Older than 30 days | Report only (can never delete) | Dry run first; deletion needs a separate, approved change |

**Legal holds** (`retention_holds`, Admin → Data Retention → Legal holds): a super admin puts a market ad or enquiry (by its code) on hold with a reason; every rule skips it until a super admin releases it, again with a reason. A hold on an ad covers its location and photos; on an enquiry, its chat. Both actions are audit-logged.

**Ad ending vs enquiry closing vs clean-up (market):**
- *Ad ends* (seller archives, admin removes, seller deletes a draft or an ad without enquiries): it leaves search and takes no new enquiries. Nothing is deleted: the ad row stays, so its enquiries keep showing its title, price, quantity and first photo. Existing enquiries stay open and readable by both sides; enquiry views never include the pickup address or GPS.
- *Enquiry closes* (seller closes or buyer cancels): only this starts the chat retention clock.
- *Clean-up* (only when a rule is on): clears the ended ad's location, and later its photos, and later the closed enquiry's messages. Enquiry rows are never deleted.

### Orders, payments and quotations (implemented 2026-10-31, all OFF)

| Rule | Covers | Default period | Classification | Action when switched on | Excluded (kept, business reason) | Held |
|---|---|---|---|---|---|---|
| `ORDERS_COMPLETED` | Completed and partially fulfilled orders | 8 financial years | ⚖️ Legal review | Anonymise customer name, mobile, notes; delivery snapshot contact, address lines, GPS; trip customer details; tracking-link mobile. Amounts, items, status, city/state/PIN, audit history stay | Pending payment, open payment issue (refund case), trip delivery issue, open risk signal | Legal hold on the order |
| `ORDERS_CANCELLED` | Cancelled orders | 8 financial years | ⚖️ Legal review | Same | Same | Same |
| `PAYMENTS` | Order and subscription payments, incl. refunded | 8 financial years | ⚖️ Legal review | Remove provider raw payload, signature, notes. Amount, GST, status, references, dates stay | Pending; open payment issue for it | Hold on the payment or its order |
| `ORDER_DOCUMENTS` | Order PDFs (no separate GST invoices or credit notes exist) | 8 financial years | ⚖️ Legal review | **Report only** (counts, bytes) | As its order | As its order |
| `DELIVERY_PROOF` | Trip photos and points | 8 financial years | ⚖️ Legal review | **Report only** (size not stored) | As its order | As its order |
| `QUOTATIONS_ACCEPTED` | Accepted and converted (incl. internal ones converted) | Follows the order (8 FY; without an order, 8 FY after acceptance) | Recommendation | Anonymise recipient name, mobile, request note; the order link stays | Order not yet past its period or busy | Hold on the quotation or its order |
| `QUOTATIONS_CLOSED` | Rejected, declined, cancelled, expired | 730 days after last update | Recommendation | Same anonymisation | — | Legal hold |
| `QUOTATIONS_DRAFT` | Internal and customer drafts | 365 days after last update | Recommendation | Same anonymisation | — | Legal hold |

- **Financial years** are 1 April – 31 March, India time (`public.fy_start`, `public.fy_retained_until`). "N financial years" = kept through the end of the Nth financial year after the record's own: an order of FY 2026-27 with 8 years becomes eligible on 1 April 2035. 31 March 23:59 IST belongs to the earlier year; 1 April 00:00 IST to the next.
- **Never deleted:** these rules anonymise or report; no order, payment, quotation, invoice or audit row is removed, and an accepted quotation stays linked to its order.
- **Classification** (Legal requirement / GreenRoot recommendation / Legal review required) and **period** are set in Admin → Data Retention by a super admin, with a reason (old and new value, who and when are audit-logged). The period unit is fixed per rule. Rules marked ⚖️ start on legal review hold: after counsel confirms, a super admin ticks *Legal review is complete* (with who confirmed it), optionally sets classification to *Legal requirement*, and switches the rule on. The two report-only rules cannot be switched on (file deletion is a separate, reviewed change).
- **Legal holds** now also cover orders, quotations and payments (by code). A held record is skipped; when the hold is released its normal clock applies again (time on hold is not added).
- **Statutory vs recommended:** none of the periods above is confirmed as a statutory requirement yet. Counsel to confirm: GST Act s.36 (accounts for 72 months from the annual-return due date), Companies Act s.128 (books for 8 financial years), Income-tax books of account, RBI payment data storage. GreenRoot does not issue GST invoices or credit notes today; if it starts, they need their own record type and rule.

### Financial-year archive (implemented 2026-10-31)

Admin → **Archive (by FY)**: Orders and Quotations by financial year, searchable by code, customer or nursery, exported as CSV (opens in Excel) or PDF (first 1,000 rows; mobiles never printed). It reads the live records through the reports API (`GET /reports/{orders|quotations}?fy=2026-27&q=…&format=csv|pdf`): nothing is moved, copied or deleted, so every screen, report, API and reference keeps working. Owners and managers get the same financial-year filter on their own slice.

Not a rule: account-deletion clean-up (§3) runs daily for deleted accounts; resolved risk signals have **no** rule (purpose and legal requirement to be reviewed first).

**How a rule runs** (`greenroot-api/internal/modules/retention`):
- The SQL each rule may run is fixed in code (`rules.go`); the database holds only its settings (`retention_rules`).
- Daily (whichever API server gets there first): a rule that is on executes; every other rule gets a **dry run** that only counts, so the admin page always shows what it would do.
- **Safe on several servers:** a Postgres advisory lock per rule (a second run is recorded as `SKIPPED already_running`) and a "ran in the last 20 hours" check, re-checked under the lock.
- **Batches** (default 1,000 rows per statement, short locks); every delete re-checks the period and holds, so a hold added mid-run still wins. A failed batch rolls back alone and is retried on the next run (the job is idempotent).
- **Time:** periods are compared with the database clock (`now()`, UTC); no app-side time-zone maths.
- **Run history** (`retention_runs`): eligible, held, changed, failed, skipped, bytes, error category. Never names, numbers or row contents. Logs carry counts and SQL error codes only.
- **Guards:** switching on is refused by the API and by a database constraint while a rule is on legal hold or report-only; periods have a per-rule minimum; a reason (10+ characters) is required and the old and new values go to the audit log. Clearing a legal hold needs a note saying who confirmed it and when.

**Production rollout:** [operations/retention-rollout.md](operations/retention-rollout.md) (migration `20261031_03_retention_rules`, checks, rollback).

**Turning a rule on (after approval):** Admin → Data retention → *Dry run* → check the counts → *Change* → switch on, with the reason. For a ⚖️ rule, first tick *Legal review is complete* with the note.

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
| 21 | Market chat (`market_enquiries`, `market_enquiry_messages`) | Buyer–seller messages | Medium (free text) | Kept forever (rule `MARKET_CHAT` off) | 1 year after the enquiry closes; reported or legally held ones kept | Both parties may need the history briefly | Automatic deletion with hold | `market_ads` |
| 22 | Market ads (`market_ads`: pickup address, GPS) | Listings | High (pickup point) | Never deleted (status only); location kept (rule `MARKET_AD_LOCATION` off) | Location cleared 90 days after the ad ended, unless an enquiry is open, a report is pending or a legal hold applies | Listing is over | Mask | `market_enquiries`, reports, saves, views |
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

## 4a. CERT-In logging obligations (review for counsel)

**Source:** CERT-In Directions under section 70B(6) of the IT Act, 28 April 2022 (and CERT-In's FAQs of May 2022). They require service providers, intermediaries, data centres and body corporates to "enable logs of all their ICT systems and maintain them securely for a rolling period of 180 days", within Indian jurisdiction, and to provide them to CERT-In when asked. Whether GreenRoot is in scope as a "body corporate" or "intermediary", and which of its logs count as ICT system logs, is for counsel to confirm. Read conservatively, these GreenRoot records would be covered:

| Record | Fields that make it an ICT log | Current | Conflict |
|---|---|---|---|
| `user_sessions` | `ip_address`, `user_agent`, `os_name`, login/activity times | Kept (rule off) | Proposed 30 days < 180 → **legal hold** |
| `otp_requests` | `mobile`, `ip_address`, time (authentication attempts) | Kept (rule off) | Proposed 30 days < 180 → **legal hold** |
| `security_audit_logs` | `ip_address`, event, time | Kept forever | None today (no rule) |
| `audit_logs` | `source_ip`, `user_agent`, change, time | Kept forever | None today (no rule) |
| `user_activities` | login entries (session, time) | Kept; deleted on account deletion | Account deletion vs 180 days: counsel to confirm which wins (DPDP erasure vs CERT-In) |
| API log files (`LOG_DIR`) | client IP, path, status, time (mobiles masked) | Deleted after 90 days (`LOG_RETENTION_DAYS`) | **Below 180 days** — raise to 180 if counsel confirms scope |
| `consent_records` | `ip_address`, `user_agent` | Kept forever | None |

Not ICT logs under this reading (business records): GPS trails, SMS/email delivery logs, chat messages, orders, payments. GPS trails are on hold for dispute evidence, not CERT-In.

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

- New rules are **built but off**; the three ⚖️ rules stay off until legal review (§0, §4a).
- Orphaned files are only reported (#27); deleting them needs a separate approved change. In development, dev, journey and test APIs share one MinIO, so "unreferenced" there includes files of other databases — the report is only meaningful per environment. Old deleted accounts' photo files cannot be found by URL.
- API log files are kept 90 days, below the 180 days CERT-In may require (§4a).
- Driver licence and lorry owner data after account deletion (#28, #29) need a legal decision.
- Restore reconciliation (§5) relies on logs; a small external deletion ledger would make it reliable.
- Unread notifications are kept indefinitely (by design, pending a product decision).
