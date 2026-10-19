# Messaging Core (SMS + Email)

One channel-agnostic core for every message the platform sends to users.
Business code raises an **event**. The core sends it on every **channel**
(SMS, email) that has an active template with the same code and a way to
reach the user. Channel-specific rules live inside each channel: TRAI DLT for
SMS ([sms.md](sms.md)), HTML escaping and sender identity for email (below).

Status: built and tested in **mock mode** for both channels. AWS gateways are
built but off: `SMS_PROVIDER=aws` (AWS End User Messaging SMS) and
`EMAIL_PROVIDER=ses` (Amazon SES). Nothing is delivered until one is switched on.

---

## How it fits together

```
payments / auth / users                          (business modules)
        │  messaging.Event{Code, UserID, Values}
        ▼
messaging.Notifier ── ExpandValues ── RecipientLookup (users: mobile, VERIFIED email)
        │
        ├─► sms.Service.Deliver    → DLT rules → platform/sms.Provider   → sms_messages
        └─► email.Service.Deliver  → escaping  → platform/email.Provider → email_messages
```

| Package (greenroot-api) | Role |
|---|---|
| `internal/modules/messaging` | `Event`, `Channel` interface, `Notifier` fan-out, `ExpandValues`, recipient lookup |
| `internal/common/otp` | Shared one-time-code store (hashed, single use, burns after wrong guesses, per-identity throttle). Used by SMS login OTP and email verification. |
| `internal/modules/sms` + `platform/sms` | SMS channel (DLT registry, typed variables) |
| `internal/modules/email` + `platform/email` | Email channel (sender, templates, shared HTML layout) |

### Events and values

Business code passes **semantic** values. `ExpandValues` derives the forms
that channels need, so payments doesn't have to know SMS rules:

| Given | Also provided |
|---|---|
| `amount` `"1250.50"` | `amount_rupees` `"1250"`, `amount_paise` `"50"` |
| `<x>_code` `"ORD-20261016-0008"` | `<x>_date` `"20261016"`, `<x>_seq` `"0008"` |
| `mobile` `"9876543210"` | `mobile_last4` `"3210"` |

SMS templates use the split forms (DLT `{#numeric#}` allows digits only).
Email templates use the originals.

### Fan-out rules

- **Shared codes:** a channel sends only if it has an **active template with the event's code**. Sharing a code (e.g. `PAYMENT_FAILED`) is how one event reaches both channels.
- **Verified email only:** email goes only to a **verified** address; SMS goes to the account mobile. If a channel has no address or no template, it skips silently (`ErrSkipped`) and logs nothing.
- **Failure isolation:** one channel failing never stops the others.
- **Never blocks the request:** events are sent in the background (`NotifyAsync`), so gateway latency or failure never affects the payment or login that raised them.

| Event | SMS | Email | Raised by |
|---|---|---|---|
| `ACCOUNT_WELCOME` | ✓ | — | auth, when OTP verification creates a user |
| `PAYMENT_RECEIVED_ORDER` | ✓ | ✓ | payments, on transition into SUCCESS |
| `PAYMENT_RECEIVED_SUBSCRIPTION` | ✓ | ✓ | payments, on transition into SUCCESS |
| `PAYMENT_FAILED` | ✓ | ✓ | payments, on transition into FAILED |
| `AUTH_LOGIN_OTP` / `AUTH_REGISTER_OTP` | ✓ | — | sent directly (the number may not be an account yet) |
| `EMAIL_VERIFY_OTP` | — | ✓ | sent directly (the address is not verified yet) |

**To add a new alert:** create templates with the same code in Admin → SMS / DLT and/or Admin → Email, then raise `messaging.Event{Code: ...}` from the business module. No channel code changes are needed.

---

## Email channel

### Modes

| | Mock (`EMAIL_PROVIDER=mock`, default) | Live |
|---|---|---|
| Delivery | Logged as `MOCKED` | Sent through the gateway |
| Verification code | Fixed `123456`, returned as `mock_code` | Random 6 digits, never returned |
| Requires From address + verified domain | No | Yes (otherwise `BLOCKED`) |
| Redis | Optional | Required (fails closed) |

An unknown `EMAIL_PROVIDER` value stops the API at startup.

### Templates

- **Placeholders:** `{{snake_case}}` placeholders in the subject, HTML body and text body. The variable list is derived automatically.
- **Escaping:** values are **HTML-escaped** in the HTML body, raw in the text body, and must be single-line in the subject (blocks header injection).
- **No scripts:** `<script>` is rejected.
- **Shared layout:** `body_html` is content only. The API wraps it in the shared GreenRoot layout (`email/layout.go`), so branding lives in one place.
- **System templates:** the four below can't be renamed or deactivated.

| Code | Subject |
|---|---|
| `EMAIL_VERIFY_OTP` | Verify your email for GreenRoot |
| `PAYMENT_RECEIVED_ORDER` | Payment received for order {{order_code}} |
| `PAYMENT_RECEIVED_SUBSCRIPTION` | Payment received for your GreenRoot subscription |
| `PAYMENT_FAILED` | Your GreenRoot payment {{payment_code}} was not successful |

### Email verification

1. `POST /users/me/email/send-code {email}` sends a 6-digit code (valid 10 minutes).
2. `POST /users/me/email/verify {email, code}` saves the address with `users.is_email_verified = true`.

- **Binding:** the code works only for that user and that address.
- **Code security:** same protections as the login OTP — stored hashed, single use, burned after 5 wrong guesses, and limited to one send per 30 s and 5 per hour per user+address.
- **Address rules:** addresses are stored lower-case. An address already on another account returns `409 email_taken`.
- **Profile updates:** in `PUT /users/me`, omitting `email` (or sending null) leaves it unchanged, and `""` clears it. Changing the address resets `users.is_email_verified` to false. Before this change, saving a profile without an email wiped a verified address.

### Tables

| Table | Purpose |
|---|---|
| `email_senders` | Singleton: From name/address, Reply-To, "domain verified" flag (SPF/DKIM/DMARC) |
| `email_templates` | Code, name, subject, HTML content, text body, active |
| `email_messages` | Every attempt: to, subject/body with codes masked, status, error, reference |

Statuses: `SENT`, `MOCKED`, `BLOCKED`, `FAILED` (`DELIVERED` and `BOUNCED` are reserved for provider webhooks).

### Routes (`/api/v1`)

| Method | Path | Who |
|---|---|---|
| GET | `/email/status` | Admin |
| GET/PUT | `/email/sender` | Admin |
| GET/POST | `/email/templates` | Admin |
| POST | `/email/templates/preview` | Admin |
| GET/PUT | `/email/templates/{id}` | Admin |
| POST | `/email/templates/{id}/test` | Admin |
| GET | `/email/messages` | Admin |
| POST | `/users/me/email/send-code` | Any signed-in user |
| POST | `/users/me/email/verify` | Any signed-in user |

Errors: `409 email_taken`, `400 invalid_code`, `429 email_code_cooldown`, `429 email_code_rate_limited`, `503 email_unavailable`.

### UI

- **Admin → Email:** Readiness checklist, Sender, Templates (editor with a sandboxed live HTML/text preview and test send) and Message log. Shared pieces live in `greenroot-admin/src/features/messaging/shared.tsx`.
- **Mobile → Edit Profile:**
  - An unverified email shows "Not verified" with a **Verify** button.
  - A verified email is locked; **Change** runs the same code flow for the new address.
  - The old placeholder sheet that only accepted `123456` locally has been replaced with the real API.

### Going live

1. In Amazon SES (region `ap-south-1`), verify the sending domain, publish SPF, DKIM and DMARC, and request production access (new accounts are in the sandbox and can only mail verified addresses).
2. In Admin → Email → Sender, set the From address and tick "Domain verified". The Readiness tab turns all green.
3. Give the API an IAM role (or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) allowed `ses:SendEmail`, and deploy with `EMAIL_PROVIDER=ses`, `AWS_REGION=ap-south-1` and Redis. The API refuses to start if the region is missing.

Another provider: implement `Provider` (`Name`, `Live() == true`, `Send`) in `platform/email` and register it in `email.New` — see `ses.go`.

### Known gaps

- **No bounce or complaint handling yet.** It needs the provider's webhook. `DELIVERED`/`BOUNCED` and `delivered_at` exist but nothing sets them, and repeated bounces should eventually un-verify the address.
- **No unsubscribe link or footer.** Every current email is transactional. Marketing email would need `List-Unsubscribe` and consent.
- **Mobile-number change in Edit Profile is still a placeholder.** It doesn't call the API (it predates this work).
