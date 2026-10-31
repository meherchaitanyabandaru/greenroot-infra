# Mango AI assistant

Status: built and tested 2026-10-30 / 31 in mock-free local runs against the real provider. **Not deployed.** Off by default (`AI_ENABLED=false` in the API).

Mango already existed as offline, step-by-step guides (the 🥭 button). This adds an AI assistant to the same button: **Ask Mango (voice or text)**. It is for **nursery owners, managers and customers only**: drivers and admin accounts are refused by the API (403) and do not see it in the app. Users ask in Telugu, English or a mix. Mango answers from the user's own GreenRoot data and can prepare one change (confirming a pending order), which runs only after the user taps Confirm.

## Request flow

```
Flutter app ──HTTPS, user JWT, X-Mango-Notice──▶ Go API /api/v1/assistant/*
   record AAC 16 kHz mono            │ 1. user signed in, not an admin account; notice version; kill switch;
   (silence never sent)              │    per-user and global limits; size, type and length of the audio
                                     │ 2. calls greenroot-ai (X-Internal-Token), no retries
                                     │ 3. tool loop: the model asks for a tool → the API calls its own endpoint
                                     │    in-process WITH THE USER'S TOKEN (same RBAC and nursery checks as the app)
                                     │    → only allowlisted fields go back to the model
                                     │ 4. records usage (units + estimated cost, no text)
                                     ▼
                          greenroot-ai (FastAPI, internal) ──▶ OpenAI
                          STT / LLM / TTS provider interfaces; holds the only key
```

- **Speech** (`POST /assistant/transcribe`): the app records up to 30 s, drops silent recordings, and uploads. The API checks the bytes (M4A `moov/mvhd` or WAV header: type and duration), not the declared type. The text comes back to the app's text box for the user to **check and correct**. Nothing is sent to the model until the user taps Send.
- **Answer** (`POST /assistant/chat`): up to 2 rounds of tool calls, then one answer without tools. The app sends the last 6 turns as history; the server stores none.
- **Read aloud** (`POST /assistant/speech`): MP3. Telugu text gets a Telugu voice instruction. The app plays it and deletes the file after playing or stopping.
- **Changes**: `propose_confirm_order` stores a proposal (`assistant_actions`, 10 minutes). `POST /assistant/actions/{id}/confirm` runs it once, for that user only, through `POST /orders/{id}/confirm`, which checks permission and state again. Cancelling, an expired proposal, or the order having changed meanwhile all change nothing.

## Who can use it

- **Allowed:** NURSERY_OWNER, MANAGER and BUYER roles.
- **Refused:**
  - A driver-only account gets 403 `assistant_role_not_allowed`.
  - ADMIN and SUPER_ADMIN get 403 `assistant_not_for_admins`.
- **Owner who also drives:** keeps access, but there is no "driving" trips view.
- **In the app:** the "Ask Mango" tile is hidden and `/mango` is route-guarded for drivers. The API check is the one that counts.

## Daily questions (migration `20261031_01`)

- **Default: 5 questions per person per day.** Admin → Messaging → Mango AI changes the limit (0–50) and switches Mango on or off. Both are stored in `platform_config` (`assistant_daily_questions`, `assistant_enabled`) and take effect at once. Each change is audit-logged (module ASSISTANT).
- The server env `AI_ENABLED` is a second, server-level switch: both must be on.
- **The day is India time (Asia/Kolkata):** the API computes the date, so neither the phone nor the DB session decides. It resets at midnight IST.
- **Counted (one question):**
  - a typed question that got an answer;
  - a spoken question when its transcript is sent and answered.
- **Not counted:**
  - transcription alone (a discarded or edited-away recording);
  - silence, which the phone never uploads;
  - microphone or permission errors;
  - requests refused before processing (notice, role, switches, cost limits, bad audio);
  - a failed answer (provider error or timeout) and an empty answer: the slot is given back;
  - reading an answer aloud, or replaying it;
  - Confirm or Cancel on a proposal.
- **Atomic:** a slot is reserved by one `INSERT … ON CONFLICT DO UPDATE … WHERE questions_used < limit` before the model runs. Ten requests at the same moment with 5 left: exactly 5 are answered (tested). When none is left, chat and transcribe answer 429 `ai_daily_questions_used`, before any AI cost.
- **The app cannot change the count.** `DELETE /assistant/data` does not reset it (the count is what enforces the limit; it holds no content).
- `GET /assistant/status` and every chat answer carry `questions: {questions_used, questions_limit, questions_left, resets_at}`.
- The existing cost limits (per-minute calls, daily and monthly $) still apply on top.

## Greeting and goodbye (no AI)

- **On open:** Mango plays a greeting clip shipped in the app (`assets/audio/mango/greet_{morning,day,evening}_{te,en}.mp3`).
- **On close:** it plays `bye_{te,en}.mp3`, then the screen closes. A second tap closes at once.
- No API call and no cost. The menu switches the greeting between Telugu and English, or mutes it.
- The clips were made once with `greenroot-ai/scripts/make_greetings.py` (voice `coral`, a native-speaker style instruction).
- **Replace them with a native Telugu speaker's recordings** under the same file names for the most natural sound. The text lines are in `mango_voice.dart`.

## Telugu voice

- **Ten OpenAI voices compared** (samples in `greenroot-ai/test-audio/voices/te_<voice>.mp3`, gitignored): coral, sage, nova, shimmer, alloy, ash, ballad, verse, marin, cedar.
- **All are understandable:** played back through speech-to-text, 0–2.4% character error.
- **Naturalness needs a human listener.** Pick one and set `AI_TTS_VOICE` in greenroot-ai, then rerun `make_greetings.py` with it.
- Read-aloud now asks for "natural, warm Telugu like a native speaker from Andhra Pradesh".
- If no OpenAI voice is natural enough, add an Indian-language TTS provider behind the `TextToSpeech` interface (e.g. Sarvam AI, Google Cloud or Azure Telugu voices). That needs an account and key.

## Business tools (Go, `internal/modules/assistant/tools.go`)

| Tool | Endpoint called as the user | Offered to |
|---|---|---|
| `list_orders` (side, status, placed today, search) | `GET /orders` (`buying=true` for the buying side) | owners, managers (selling); buyers, owners (buying) |
| `get_order` | `GET /orders?search=` then `GET /orders/{id}` | same |
| `list_quotations`, `get_quotation` | `GET /quotations` | same |
| `list_trips` (selling, buying) | `GET /dispatches` | owners, managers, customers |
| `get_delivery_status` | `GET /orders/{id}/dispatches` | sellers, buyers |
| `propose_confirm_order` | stores a proposal; runs `POST /orders/{id}/confirm` after Confirm | owners, managers |

- The tool list and the `side` values are built per user. A tool the user is not offered is refused even if the model names it.
- Admin accounts get 403 `assistant_not_for_admins`, because an admin token sees every nursery.
- **What reaches the model:** order and quotation numbers, statuses, amounts, dates, plant names and quantities, nursery names, and the customer's or driver's name where the user can already see it. Never phone numbers, addresses, coordinates, delivery codes, payment details or tokens. The journeys check this.
- Not supported (Mango says which screen to use): cancel, create, send, edit, payments, trips, revenue.

## API endpoints

| Method | Path | Notes |
|---|---|---|
| GET | `/assistant/status` | `{enabled, notice_version, max_audio_seconds, max_text_chars, calls_left_today}` |
| POST | `/assistant/transcribe` | multipart `audio` (M4A/AAC or WAV, ≤1 MB, 0.3–30 s), `language` auto\|te\|en |
| POST | `/assistant/chat` | `{message ≤500 chars, history ≤6}` → `{reply, used_tools, proposal?, request_id}` |
| POST | `/assistant/speech` | `{text ≤600}` → MP3 |
| POST | `/assistant/actions/{id}/confirm`, `/cancel` | 404 `action_not_found`; 409 `action_expired`, `action_already_decided`, `action_failed` (with the endpoint's reason) |
| DELETE | `/assistant/data` | deletes the user's proposals; unlinks their usage rows (totals kept for the budget) |
| GET | `/admin/assistant/usage` | admin: calls and estimated USD by kind, today and this month, plus the limits (Admin → Messaging → Mango AI) |
| GET/PUT | `/admin/assistant/settings` | admin: `{enabled, daily_question_limit}` (0–50), audit-logged |

Errors (`{"error": {"code", "message"}}`, message shown to the user):

| Status | Codes |
|---|---|
| 401 | missing or invalid token |
| 403 | `assistant_not_for_admins`, `assistant_role_not_allowed` |
| 428 | `ai_notice_required` |
| 503 | `ai_disabled`, `ai_budget_reached` |
| 429 | `ai_daily_questions_used`, `ai_daily_limit`, `ai_slow_down`, `ai_rate_limited` |
| 413 | `audio_too_large`, `audio_too_long` |
| 415 | `unsupported_audio` |
| 422 | `empty_audio`, `corrupt_audio`, `audio_too_short`, `invalid_language`, `message_too_long`, `empty_text`, `text_too_long`, `ai_bad_input` |
| 504 | `ai_timeout` |
| 502 | `ai_unavailable`, `ai_provider_error` |

Every response carries a request id, which is also in both services' logs.

## Models and APIs (checked 2026-10-30 against the account's `/v1/models` and the published price list)

| Use | API | Model | Price (USD) |
|---|---|---|---|
| Speech to text | `/v1/audio/transcriptions` | `gpt-4o-mini-transcribe` | $1.25 / $5.00 per 1M in/out tokens (≈ $0.003 per minute) |
| Answers + tools | `/v1/chat/completions` (`store=false`, `temperature=0.2`, ≤350 output tokens) | `gpt-4.1-mini` | $0.40 in, $0.10 cached, $1.60 out per 1M tokens |
| Read aloud | `/v1/audio/speech` (MP3) | `gpt-4o-mini-tts`, voice `coral` | $0.60 per 1M text tokens in, $12 per 1M audio tokens out. The endpoint reports no usage, so the budget estimates $0.015 per minute of audio returned. |

All are configurable (`AI_*_MODEL`, `AI_PRICE_*`). Cheaper text models exist (`gpt-5-nano`, `gpt-4.1-nano`) but were not evaluated for Telugu tool use.

## Privacy and retention

- The app shows a notice before first use. It says that words go to GreenRoot and then to OpenAI, that GreenRoot keeps no audio or conversation text, what OpenAI keeps, and not to share bank or card details. The API refuses AI calls without the notice header (428). The notice can be reread from the menu.
- **Audio:** never written to disk by the API (the multipart form is held in memory and its temp parts removed). In greenroot-ai it is held in memory, and the upload spool is closed after the call. On the phone, the recording is deleted after upload, on discard, and when the screen closes. The spoken answer is deleted after playing.
- **Stored by GreenRoot:** `assistant_usage_events` (user, kind, model, tokens, seconds, characters, estimated cost, request id; no content), deleted after `AI_USAGE_RETENTION_DAYS` (90). `assistant_actions` (the proposal summary, e.g. "Confirm order ORD-… from Ravi (₹6000)"), deleted after 7 days. The user can delete both from Mango's menu (`DELETE /assistant/data`).
- **Logs:** path, status, time, request id, tool names. Never audio, transcripts, prompts, replies, tokens or keys. Checked by scanning 20,000+ API log lines and the AI service log after the journeys.
- **OpenAI (per its "Your data" page, 2026-10-30):** API data is not used for training unless the account opts in. Abuse-monitoring logs are kept up to 30 days for chat and speech; transcription lists none. `store=false` is sent on chat. **Zero data retention is not enabled.** It needs OpenAI's approval for the account; do not claim it until approved.
- The OpenAI key is only in greenroot-ai's environment. The APK was scanned: no provider address, key name or key prefix.

## Cost control (the initial budget is $5; that is enough for testing, not for production use)

| Setting (API env) | Default | Effect |
|---|---|---|
| `AI_ENABLED` | false | API kill switch (greenroot-ai also has `AI_ENABLED`) |
| `AI_USER_MINUTE_CALLS` | 15 | Burst limit per user (429 `ai_slow_down`); one spoken question is up to 5 calls |
| `AI_USER_DAILY_CALLS` / `AI_USER_DAILY_USD` | 150 / $0.05 | 429 `ai_daily_limit` |
| `AI_GLOBAL_DAILY_USD` / `AI_GLOBAL_MONTHLY_USD` | $0.50 / $4.00 | 503 `ai_budget_reached` for everyone |
| `AI_MAX_AUDIO_SECONDS` / `AI_MAX_AUDIO_BYTES` | 30 / 1 MB | Checked from the file header before any AI call |
| `AI_MAX_TEXT_CHARS` / `AI_MAX_SPEECH_CHARS` | 500 / 600 | |

- No automatic retries anywhere (`max_retries=0`). The app retries only when the user taps Try again.
- Silence is caught on the phone.
- An Idempotency-Key replay returns the cached answer instead of a second charge.
- Limits are checked when a request starts, so requests already running can go a few calls over. They are set well below the budget for that reason.
- Estimates come from configured prices; **the OpenAI dashboard is the bill.**

Observed cost:
- A full live end-to-end run (16 questions, 25 model calls, one spoken question and one spoken answer) was about **$0.014**.
- A full speech run (16 transcriptions and 3 read-alouds) was about **$0.004**, plus TTS.
- A typical spoken question with a spoken answer is about **$0.001–0.002**.

## Languages and known limitations

- **Telugu (real speakers, FLEURS read speech):** character error rate 0–5% on 3 clips. One clip with English place names came back fully in Telugu script, which reads correctly but can't be scored against the reference.
- **English:** 0–3%.
- **Synthetic Telugu nursery phrases** (macOS voice; "మామిడి మొక్కలు యాభై…"): exact.
- **Code-mixed speech:** English words are written in Telugu script ("క్వోటేషన్"), and "quotation" was sometimes misheard ("లాటిషన్") on a synthetic voice. The default "Mixed" (auto) did better than forcing Telugu. **Needs testing with real nursery staff on real phones.**
- **Noisy audio (5 dB SNR):** unusable. The user sees the transcript and corrects it.
- **Silence:** a vocabulary prompt made the model return the prompt itself. No prompt is sent, and silent recordings are not uploaded.
- **Read aloud:** Telugu and English sound clear. Listened back through STT, nursery vocabulary was exact; one "మీకు" came back as "నీకు".
- **Model behaviour seen and fixed:**
  - It replied in Telugu to English questions. The API now decides the reply language from the script.
  - It said "tap Confirm" to a buyer, who has no Confirm button. The change rule is now written per user.
  - The final no-tools round sent `tools: null`, which the service rejected. It now always sends a list.
- **Still open:**
  - Asked about revenue, Mango offers to help with "sales" although no revenue tool exists. No amount was invented.
  - Answers about "today's trips" may filter by one status.
  - Each question is limited to 2 tool rounds.

## Tests and results (2026-10-31)

| Suite | Command | Result |
|---|---|---|
| greenroot-ai unit | `.venv/bin/pytest -q` | 23 passed |
| greenroot-ai live (real OpenAI) | `scripts/live_check.py test-audio` | 23 passed (5 of them reported without grading: mixed script, noise, silence) |
| API unit (assistant) | `go test ./internal/modules/assistant/` | 14 passed; all 58 packages pass |
| API sqlcheck | `go run ./cmd/sqlcheck ./internal/...` | 602 statements, 0 rejected |
| API integration | `go test ./tests/...` | pass |
| Journeys (fake greenroot-ai, in CI) | `journeys.py --only assistant` | 102 passed; full suite 2198 passed, 0 failed (see note) |
| Live end-to-end (real OpenAI, test DB) | `tests/journeys/mango_live.py --audio …` | 51 passed |
| Mobile | `flutter test` | 439 passed (20 for Mango); analyze clean; profile APK builds |
| Admin | `npx vitest run` | 50 passed; lint, tsc and build clean |

Note: the journeys and a second API share Redis's notification queue. A local API on another database (for example the dev API on :8080) takes queue items, and "…is told" checks then fail at random. Give the test API its own `REDIS_DB` (and pass the same `REDIS_DB` to the journeys).

Not tested yet:
- On a real phone: microphone permission dialogs, recording, playback, Bluetooth audio, and app-switch during recording.
- Real nursery staff speaking Telugu in a noisy yard.
- Real insufficient-credit and real rate-limit responses (covered with mocked provider responses only).
- Load.

## Local setup

1. greenroot-ai: see its README (`./run.sh`, port 8090, `.env` with the key and `AI_SERVICE_TOKEN`).
2. API: `go run ./cmd/migrate up` (migration `20261030_06_assistant`), then start with `AI_ENABLED=true AI_SERVICE_URL=http://127.0.0.1:8090 AI_SERVICE_TOKEN=<same>`.
3. App: open the 🥭 button, then **Ask Mango (voice or text)**.

## Before production

- Deploy greenroot-ai privately (no public ingress), with TLS between hosts, the key from the secret manager, and `AI_SERVICE_TOKEN` of 32+ random bytes (validated at API start).
- Set a hard monthly budget limit in the OpenAI dashboard as well as the API limits. Top up beyond $5.
- Request zero data retention from OpenAI if required, and update the notice to match.
- Have a lawyer review the notice wording (DPDP Act 2023: notice, purpose, deletion). Add Mango to the privacy policy.
- Field-test Telugu with real users. Watch Admin → Mango AI. Consider streaming for latency (answers take 1–3 s, plus 1–2 s each for speech and read-aloud).

## Redesign (2026-10-31): voice assistant screen

- **Screen:** the chat screen became a full-screen voice assistant (light theme).
- **The orb:** an original animated mango orb (`mango_orb.dart`), with live sound bars at the sides. It has one look per state:

| State | Look |
|---|---|
| Idle | Breathing |
| Listening | Follows the voice |
| Thinking | Swirling |
| Speaking | Pulsing |
| Error | Amber |
| Limit | Grey and asleep |
| Mic not allowed | Grey |

- It stands still when the phone asks for reduced motion.
- **Layout, top to bottom:**
  - GreenRoot, a menu (greeting language, mute, privacy, delete data) and close.
  - "Mango AI".
  - The "3/5 questions left today" pill.
  - The orb, then a status line.
  - A transcript card: sent by itself after 2 s; tapping the words stops that for editing.
  - Or an answer card: the answer text, Read aloud / Stop, and Confirm / Cancel for proposals.
  - Type, the big mic/stop button, Cancel.
  - The privacy row.
- **Spoken questions** get a spoken answer. Typed ones do not (Read aloud is there).
- **Not done:** before/after screenshots from the OnePlus. The phone was locked during the session.

### Test results (2026-10-31)

| Suite | Result |
|---|---|
| API unit | 53 packages pass, 16 Mango tests (role gate, India-time day boundary, quota arithmetic) |
| sqlcheck | 607 statements, 0 rejected |
| `tests/api` | pass, including roles per account, next-day reset, refusal before AI when used up, and delete-data not resetting |
| Journeys | 2239 passed, 0 failed (Mango: 143 checks, including 5-then-6th refused, voice and text sharing the count, failed or empty answers and read-aloud not counted, 10 concurrent → 5 answered, admin limit and switch, audit) |
| Mobile | 455 passed: every orb state, greeting and goodbye clips, auto-send, limit state, mic denied, error/retry, driver tile hidden, 360×640 at 130% on Android and iOS, reduced motion |
| Admin | 51 passed |
| greenroot-ai | 23 passed |
