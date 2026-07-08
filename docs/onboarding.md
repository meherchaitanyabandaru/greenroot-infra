# GreenRoot — User Onboarding Guide

> Covers: login flow, first-run activity selection, role-based routing, RBAC guards, invite flows, and admin review.

---

## 1. Complete Login Flow

```
Splash Screen
      ↓
  [returning user?]
  ├── yes + valid session → role routing (§2)
  └── no → /login

/login  (Enter mobile number)
      ↓
/otp  (Enter 6-digit code)
      ↓
  [new user? + no profile?]
  ├── yes → /create-profile → /select-activity → role routing
  └── no  → role routing (§2)
```

**Screen: `/login`** — "Welcome to GreenRoot". Handles first-time and returning users identically via OTP. No separate sign-up flow.

**Screen: `/create-profile`** — Name (required) + email (optional). Shows once for brand-new users. After saving, goes to `/select-activity`.

---

## 2. Activity Selection — First Run

**Screen: `/select-activity`** — "How would you like to use GreenRoot today?"

Task-oriented, not role-oriented. Four cards:

| Card | Action |
|---|---|
| 🌿 **I own a nursery** | → `/register/nursery` → submit details → `/nursery/pending` |
| 👤 **I work in a nursery** | → `/invite/accept` → enter code → `/home` with Work tab |
| 🛒 **I am a customer / buyer** | → `/home` with Buying tab |
| 🚚 **I am a driver** | → `/register/driver` → enter trip code → `/home` with Driver tab |

"Continue as Customer →" skip link takes straight to `/home` for users who don't know their role yet.

---

## 3. Role Routing After Login

`SplashScreen.routeAfterLogin` runs after every bootstrap (launch, OTP verify, invite accept). Checks in order:

```
hasPendingNursery?  → /nursery/pending
hasRejectedNursery? → /nursery/rejected
multipleWorkspaces + no active role? → /workspace-select
admin/super-admin + no mobile workspaces? → /home/admin
else → /home
```

---

## 4. Per-Role First Screen

### Nursery Owner — PENDING

**Screen**: `/nursery/pending`

| Element | Detail |
|---|---|
| Status | "Application Under Review" — hourglass icon |
| Submitted date | From nursery `created_at` via `/nurseries/owned` |
| Progress steps | Submitted ✓ → Under Review (active) → Decision ○ |
| Check Status | Re-bootstraps session; routes to `/home` if approved, `/nursery/rejected` if rejected |
| Sign Out | Clears session → `/login` |

No access to any other screen while pending.

---

### Nursery Owner — REJECTED

**Screen**: `/nursery/rejected`

| Element | Detail |
|---|---|
| Rejection banner | "Application Not Approved" — red cancel icon |
| Nursery + date | Nursery name + `rejected_at` date |
| Rejection reason | Shown in red card if admin entered `rejection_reason` |
| Resubmit | → `/register/nursery` to resubmit |

Resubmitting resets status to `PENDING`. Admin sees it in the queue again.

---

### Nursery Owner — APPROVED

**Screen**: `/home` — tabs: **Home · Buying · Selling · Profile**

| Tab | Key actions |
|---|---|
| Home | Dashboard: pending orders, pending quotes, quick create |
| Selling | Orders, Quotations, Loading queue, Dispatches |
| Buying | Buy-side quotations, inbound orders |
| Profile | Nursery info, team (invite managers/customers), addresses |

RBAC: can create quotations (INTERNAL + CUSTOMER), invite managers and customers, add inventory. Cannot be a manager or driver simultaneously.

---

### Manager (Gumastha)

**Joins via**: MANAGER_INVITE from nursery owner → `/invite/accept` → code entry → session refresh → Work tab appears.

**Screen**: `/home` — tabs: **Home · Buying · Work · Profile**

| Tab | Key actions |
|---|---|
| Work | Confirm orders, loading workflow, assist with quotations |
| Buying | Buy-side for the nursery they manage |

RBAC: cannot invite others, cannot add inventory. One nursery at a time (API enforces `409 conflicting_role`).

---

### Buyer (Customer)

**Joins via**: Direct OTP (auto PERSONAL workspace) or CUSTOMER_INVITE from owner.

**Screen**: `/home` — tabs: **Home · Buying · Profile**

| Tab | Key actions |
|---|---|
| Buying | Receive quotations, accept/reject, track orders |
| Home | Browse nurseries, plant catalog |

RBAC: cannot access Selling or Work tabs. Route guards redirect to `/home`.

---

### Driver

**Joins via**: DRIVER_INVITE from nursery owner → `/register/driver`.

**Screen**: `/home` — tabs: **Home · Driver · Profile**

| Tab | Key actions |
|---|---|
| Driver | My Trips, trip map, delivery events, proof of delivery |

RBAC: confined to `/driver/*` routes only. All other routes redirect to `/home`.

---

### Admin / Super Admin

**Screen**: `/home/admin` — mobile shows "Use the web admin portal."

Full management at `localhost:5173` (web admin). Mobile is display-only for admins.

---

## 5. Dynamic Role Upgrade (No Logout Needed)

A user can gain new roles without logging out:

```
User is Customer
      ↓
Owner sends MANAGER_INVITE
      ↓
User accepts at /invite/accept
      ↓
Session re-bootstrapped (new MANAGER_NURSERY workspace)
      ↓
✨ Work tab appears automatically in MainShell
```

`MainShell` watches `sessionProvider` — capabilities are recomputed and tabs update on the same session. The user never sees a logout prompt.

Same pattern works for: buyer → manager, standalone user → nursery owner (after submit + approval).

---

## 6. Invite Flows

| Type | Sent by | Received by | Entry |
|---|---|---|---|
| `NURSERY_ONBOARDING_INVITE` | Admin | New nursery owner | `/invite/accept` → `/register/nursery` |
| `MANAGER_INVITE` | Owner | Employee | `/invite/accept` or deep-link `/invite/:uuid` |
| `CUSTOMER_INVITE` | Owner | Buyer | `/invite/accept` |
| `DRIVER_INVITE` | Owner | Driver | `/invite/accept` |

After accepting any invite, session is re-bootstrapped to pick up the new workspace.

---

## 7. Admin: Nursery Application Review

Admin UI → **Nurseries → Applications** tab.

| Status | Available actions |
|---|---|
| PENDING | Approve, Reject (reason required) |
| APPROVED | Suspend |
| REJECTED | — (owner resubmits) |
| SUSPENDED | Reactivate → APPROVED |

`rejection_reason` is stored on the nursery record and shown to the owner in their rejection screen. Admins must enter a reason to reject.

API: `PATCH /api/v1/nurseries/:id/status`  
Body: `{ "status": "APPROVED" | "REJECTED", "reason": "..." }`

---

## 8. RBAC Route Guards (Mobile)

| Guard | Requires | Blocks |
|---|---|---|
| `_driverGuard` | — | Driver-only users on all non-driver routes |
| `_canSellGuard` | Owner or Manager | Buyers, Drivers |
| `_ownerGuard` | Owner only | Managers, Buyers, Drivers |
| `_sellerReadGuard` | Owner or Manager | Buyers, Drivers |
| `_buyerGuard` | Pure buyer | Owners, Managers, Drivers |

All guards redirect blocked users to `/home`. Deep-linking to a blocked route lands at home silently.

---

## 9. Key API Contracts

| Endpoint | Used for |
|---|---|
| `POST /api/v1/auth/send-otp` | Send OTP |
| `POST /api/v1/auth/verify-otp` | Verify OTP → JWT pair |
| `GET /api/v1/me` | User profile |
| `GET /api/v1/me/workspaces` | All workspaces + `nursery_status` inline |
| `GET /api/v1/nurseries/owned` | Owned nursery: `created_at`, `rejection_reason`, `rejected_at` |
| `POST /api/v1/nurseries` | Register nursery (sends `status: 'PENDING'`) |
| `POST /api/v1/invites/accept` | Accept invite code |

`nursery_status` is included inline in the workspace response — no separate status call needed during bootstrap.

---

## 10. Dev Credentials (OTP `123456` for all)

| Mobile | Role | First Screen |
|---|---|---|
| `9000000000` | Admin + Super Admin | `/home/admin` |
| `9100000000` | Nursery Owner (ACTIVE) | `/home` — Selling tab |
| `9200000000` | Manager | `/home` — Work tab |
| `9300000000` | Buyer | `/home` — Buying tab |
| `9400000000` | Driver | `/home` — Driver tab |

---

*For order/quotation business rules: [orders.md](orders.md), [quotations.md](quotations.md). For API routes: [greenroot-api/API.md](../../greenroot-api/API.md).*
