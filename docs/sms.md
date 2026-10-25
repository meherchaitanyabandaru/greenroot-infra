# SMS Module (TRAI DLT)

Outbound SMS for login/registration OTP and payment alerts, built to India's
TRAI rules (TCCCPR 2018 and later amendments). Every commercial SMS must carry a
registered **Principal Entity (PE) ID**, a registered **header** (sender ID) and a
registered **content template**. The operator scrubs each message against the
template before delivering it.

SMS is one channel of the shared messaging core; see [messaging.md](messaging.md)
for events, fan-out to email, and the shared OTP store.

Status: built and tested in **mock mode**. Production refuses to start with the mock provider (it would accept OTP 123456 for every account); staging may use it. The AWS End User Messaging SMS
gateway is built but off (`SMS_PROVIDER=aws`). Nothing reaches a handset until
DLT registration is done and it is switched on.

---

## Modes

| | Mock (`SMS_PROVIDER=mock`, default) | Live (a real provider) |
|---|---|---|
| Delivery | Logged in `sms_messages` as `MOCKED`; nothing sent | Sent through the gateway |
| Login OTP | Fixed `123456`, returned as `mock_otp` | Random 6 digits, never returned |
| `123456` fallback when no OTP is stored | Allowed (dev convenience) | **Never** |
| Template must be DLT-approved | No (drafts work) | Yes: PE, header and template must all be `APPROVED` |
| Consent and promo-hour rules | Enforced | Enforced |
| Per-number OTP throttle | Off (keeps e2e logins fast) | On |
| Redis | Optional | Required (OTP send fails closed without it) |

An unknown `SMS_PROVIDER` value stops the API at startup, so a typo can never
fall back to mock. Mock mode with `APP_ENV=production` logs a warning.

---

## TRAI / DLT rules this module follows

| Rule | How it is enforced |
|---|---|
| PE ID, header and template ID on every SMS | Live sends are blocked (`BLOCKED`) unless all three are approved; the IDs are passed to the gateway |
| Template text must match the registration | Approved templates are **locked**: content edits return `409 sms_locked` until the status goes back to DRAFT/SUBMITTED |
| Typed variables (`{#numeric#}`, `{#alphanumeric#}`, `{#url#}`, `{#urlott#}`, `{#cbn#}`, `{#email#}`) | Legacy `{#var#}` is rejected. Each value is validated against its tag at send time |
| `{#numeric#}` = digits only, `{#alphanumeric#}` = letters and digits only | Amounts are sent as `Rs.{#numeric#}.{#numeric#}`; codes like `ORD-20261016-0008` keep the prefix and hyphens as fixed text |
| URL / callback-number variables must be pre-registered | Values must match the template's whitelist (`whitelisted_urls`, `whitelisted_numbers`) |
| Header ↔ category pairing | SERVICE header → SERVICE_IMPLICIT/EXPLICIT; TRANSACTIONAL → TRANSACTIONAL; PROMOTIONAL → PROMOTIONAL |
| Header format | Service/transactional/government: 6 letters. Promotional: 6 digits |
| TRANSACTIONAL category is for banks | Warning in the editor; all GreenRoot system SMS are SERVICE_IMPLICIT |
| Promotional and service-explicit SMS need consent | Blocked unless the user opted in (`sms_preferences`) |
| Promotional SMS only 10:00–21:00 IST | Blocked outside the window |
| Promotional SMS must explain how to opt out | Warning in the editor |
| Header suffix (`-S`, `-T`, `-P`, `-G`), added by operators since May 2025 | Nothing to do; phones show e.g. `JM-GRROOT-S` |

Limits per tag (conservative, at or below every published figure): numeric 30,
alphanumeric 40, email 40, cbn 14, url/urlott 120 characters.

Sources: [TRAI press release 11/2025](https://cms.trai.gov.in/sites/default/files/2025-02/PR_No.11of2025.pdf) ·
[MSG91 variable tagging](https://msg91.com/help/dlt-registration-in-india/variable-tagging-on-dlt-sms-templates) ·
[Infobip DLT templates](https://www.infobip.com/docs/essentials/asia-registration/dlt-templates) ·
[SMSAlert header suffixes](https://kb.smsalert.co.in/?p=2270).
Operators publish slightly different limits and dates. Check the chosen DLT
portal's current rules when registering.

---

## What to register on the DLT portal

**Principal Entity:** GreenRoot's legal entity. Put the PE ID in Admin → SMS / DLT → Principal Entity.

**Header:** `GRROOT` (SERVICE). This is a proposal; any 6-letter header that relates to the brand name works.

**Templates:** all are SERVICE_IMPLICIT on header GRROOT. Paste each body exactly as shown (the admin editor has a "Copy for DLT" button).

| Code | Body | Variables (in order) |
|---|---|---|
| `AUTH_LOGIN_OTP` | `{#numeric#} is your OTP to log in to GreenRoot. It is valid for {#numeric#} minutes. Do not share this OTP with anyone. - GreenRoot` | otp, valid_minutes |
| `AUTH_REGISTER_OTP` | `{#numeric#} is your OTP to create your GreenRoot account. It is valid for {#numeric#} minutes. Do not share this OTP with anyone. - GreenRoot` | otp, valid_minutes |
| `ACCOUNT_WELCOME` | `Welcome to GreenRoot. Your account for the mobile number ending {#numeric#} has been created successfully. - GreenRoot` | mobile_last4 |
| `PAYMENT_RECEIVED_ORDER` | `Payment of Rs.{#numeric#}.{#numeric#} received for GreenRoot order ORD-{#numeric#}-{#numeric#}. Payment ref PAY-{#numeric#}-{#numeric#}. - GreenRoot` | amount_rupees, amount_paise, order_date, order_seq, payment_date, payment_seq |
| `PAYMENT_RECEIVED_SUBSCRIPTION` | `Payment of Rs.{#numeric#}.{#numeric#} received for your GreenRoot subscription. Payment ref PAY-{#numeric#}-{#numeric#}. - GreenRoot` | amount_rupees, amount_paise, payment_date, payment_seq |
| `PAYMENT_FAILED` | `Your payment of Rs.{#numeric#}.{#numeric#} on GreenRoot (ref PAY-{#numeric#}-{#numeric#}) was not successful. Please try again. - GreenRoot` | amount_rupees, amount_paise, payment_date, payment_seq |
| `DELIVERY_UNCONFIRMED` | `GreenRoot delivery DSP-{#numeric#}-{#numeric#} was marked done by the nursery without your code. Not received? Report it in the app within 48 hours. - GreenRoot` | dispatch_date, dispatch_seq |

Each renders to a single 160-character SMS even with large values (checked by `TestSeedTemplatesFitOneSMS`).

---

## Tables

| Table | Purpose |
|---|---|
| `sms_dlt_entities` | The PE registration. A singleton, enforced by a unique index on `((true))`. |
| `sms_headers` | Sender IDs with type, DLT header ID and status. |
| `sms_templates` | Content templates exactly as registered, with ordered variable names, DLT template ID and status. |
| `sms_messages` | Every send attempt: rendered body (OTP masked as `******`), DLT IDs used, status, error. |
| `sms_preferences` | Per-user promotional opt-in, with consent and revocation timestamps and source. |

Registration statuses: `DRAFT → SUBMITTED → APPROVED` (or `REJECTED` / `INACTIVE`).
PE statuses: `NOT_REGISTERED`, `SUBMITTED`, `APPROVED`, `REJECTED`.
Message statuses: `SENT`, `MOCKED`, `BLOCKED`, `FAILED` (`DELIVERED` is reserved for delivery reports).

---

## Business rules

- **Login vs registration OTP:** `send-otp` uses `AUTH_LOGIN_OTP` when the number has an account, otherwise `AUTH_REGISTER_OTP`. The API response is the same either way.
- **OTP security (live):** 6 random digits from `crypto/rand`; stored in Redis as a SHA-256 hash with a 5-minute TTL; compared in constant time; single use; burned after 5 wrong guesses; one send per 30 s and at most 5 per hour per number (on top of the per-IP middleware limit). If the SMS send fails, the OTP is deleted and the API returns `503 otp_unavailable`.
- **Welcome SMS:** auth raises the `ACCOUNT_WELCOME` event once, when OTP verification creates a new user. It goes through the messaging notifier in the background and never delays login.
- **Payment SMS:** payments raises a `PAYMENT_*` event when a payment is created as, or moves into, `SUCCESS` or `FAILED`. The event carries `amount`, `order_code` and `payment_code`, and the core expands them into the split DLT values. Re-saving the same status does not send again. It runs in the background after the payment is saved, and the same event also reaches a verified email.
- **System templates** (the six above) cannot be renamed or deactivated, because the API sends them by code.
- **Every attempt is logged,** including blocked ones, with a machine-readable `error_code` (`template_not_approved`, `consent_required`, `outside_promotional_window`, `invalid_variables`, ...).

---

## RBAC

| Action | Who |
|---|---|
| Status, PE, headers, templates, preview, test send, message log | ADMIN / SUPER_ADMIN |
| Own SMS preferences | Any signed-in user |

---

## Routes (`/api/v1`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/sms/status` | Provider, live flag, go-live checklist |
| GET/PUT | `/sms/entity` | Principal Entity |
| GET/POST | `/sms/headers` | List / create header |
| PUT | `/sms/headers/{id}` | Update header |
| GET/POST | `/sms/templates` | List / create template |
| POST | `/sms/templates/preview` | Validate a draft and render it with sample values (encoding, characters, parts, errors, warnings) |
| GET/PUT | `/sms/templates/{id}` | Get / update template |
| POST | `/sms/templates/{id}/test` | Send a test SMS (real and billable when live) |
| GET | `/sms/messages` | Message log (`status`, `template_code`, `mobile`, paging) |
| GET/PUT | `/sms/preferences/me` | Own promotional consent |

New `send-otp` errors: `400 invalid_mobile`, `429 otp_cooldown`, `429 otp_rate_limited`, `503 otp_unavailable`.

---

## UI

- **Admin:** SMS / DLT under Communication, with Readiness checklist, Principal Entity, Headers, Templates (editor with live preview, variable naming, "Copy for DLT" and test send) and Message log.
- **Mobile:** Profile → SMS Preferences. OTP and payment SMS are always on; "Offers & updates" is an opt-in switch. The OTP screen shows resend errors and the 5-minute validity. The `123456` dev hint shows only in debug builds.

---

## Going live

1. Register the PE, header and templates (above). On DLT, bind AWS as your telemarketer (PE–TM chain). Fill in the IDs in the admin UI and set them to APPROVED. The Readiness tab turns all green.
2. In AWS End User Messaging SMS (region `ap-south-1`): register the sender ID `GRROOT` for India with your PE ID and template IDs, and request production access (new accounts are in the sandbox and can only text verified numbers). The header in the admin UI must equal the AWS sender ID.
3. Give the API an IAM role (or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) allowed `sms-voice:SendTextMessage`, and deploy with `SMS_PROVIDER=aws`, `AWS_REGION=ap-south-1` and Redis. The API refuses to start if the region is missing.

How it maps: each SMS goes to `+91<mobile>` as `TRANSACTIONAL`, from the header, with `IN_ENTITY_ID` = PE ID and `IN_TEMPLATE_ID` = template ID (`greenroot-api/platform/sms/aws.go`). Another gateway: implement `Provider` (`Name`, `Live() == true`, `Send`) and register it in `sms.New`.

## Known gaps

- **No delivery reports yet.** `DELIVERED` and `delivered_at` exist but no gateway webhook updates them.
- **No Android SMS auto-read.** It would need the app-signature hash as fixed text in the OTP template, which means re-registering that template.
- **No promotional sending feature.** The consent model and rules exist, but nothing sends promotional SMS.
- **Consent is not synced with DLT.** Explicit consent captured on DLT/operator consent templates is not mirrored here.
- **Mobile sender label.** Mobile copy does not name the header; add it once the header is approved.
