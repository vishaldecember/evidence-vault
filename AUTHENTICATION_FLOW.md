**Version:** MVP-0.9.3.1  
**Status:** Active — Authentication Architecture  
**Last Updated:** August 3, 2026 (MVP-0.9.3.1 — Backend Architecture Foundation)

# Evidence Vault Authentication Flow

This document defines the **authentication architecture** for Evidence Vault using Firebase Authentication.

Related: [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) · [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md)

> **Not implemented in MVP-0.9.3.1.** The Flutter client currently uses simulated authentication. No Auth screens or Firebase SDK wiring in this sprint.

---

## Design Principles

1. **No anonymous users** — every investigation belongs to an identifiable account
2. **Accountability** — trust and integrity require a persistent user identity
3. **Minimal friction** — email and social sign-in; no anonymous-to-registered upgrade path
4. **Provider parity** — same Firestore user document regardless of sign-in method
5. **Session security** — Firebase handles token refresh; client stores no passwords locally

---

## Supported Providers

| Provider | MVP phase | Notes |
|---|---|---|
| **Email / Password** | Phase 1 (first integration) | Primary; email verification recommended before sensitive export |
| **Google** | Phase 1 | OAuth via Firebase; link to same UID if email matches (account linking policy TBD) |
| **Apple** | Phase 2 (iOS App Store) | Required when Google offered on iOS; Sign in with Apple |
| **Anonymous** | **Not supported** | Explicit product decision — investigations require ownership |

---

## Authentication Lifecycle

### 1. App launch — session restore

```
App Start
    ↓
Firebase Auth: currentUser
    ↓
┌─────────────────┬──────────────────────┐
│ User exists     │ No user              │
│ (valid session) │                      │
└────────┬────────┴──────────┬───────────┘
         ↓                   ↓
Load user profile      Show Auth Gate
from Firestore         (Login / Create Account)
         ↓                   ↓
Enter Library          User authenticates
of Truth               ↓
                       Create/load users/{uid}
                       ↓
                       Enter Library of Truth
```

- Auth state listener drives navigation — not manual route flags
- Token refresh is automatic via Firebase SDK
- Expired/revoked session → Auth Gate

### 2. Registration (email)

```
Create Account screen
    ↓
Firebase Auth: createUserWithEmailAndPassword
    ↓
Send email verification (recommended)
    ↓
Create Firestore users/{uid} profile document
    ↓
Navigate to Library / first capture
```

**Firestore bootstrap:** On first successful auth, client (or Cloud Function trigger) creates `users/{uid}` with `email`, `authProviders: ["password"]`, `createdAt`.

### 3. Sign in (email)

```
Login screen
    ↓
Firebase Auth: signInWithEmailAndPassword
    ↓
Fetch users/{uid} — create if missing (recovery edge case)
    ↓
Navigate to Library of Truth
```

### 4. Sign in (Google)

```
User taps Continue with Google
    ↓
Firebase Auth: signInWithCredential(Google)
    ↓
If new user → create users/{uid} with authProviders: ["google.com"]
If existing → merge provider into authProviders array
    ↓
Navigate to Library of Truth
```

### 5. Sign in (Apple) — future

```
User taps Continue with Apple
    ↓
Firebase Auth: signInWithCredential(Apple)
    ↓
Handle Apple private relay email
    ↓
Create/update users/{uid}
    ↓
Navigate to Library of Truth
```

Apple may hide email — store provider UID; display name from Apple credential.

### 6. Password reset

```
Forgot Password screen
    ↓
Firebase Auth: sendPasswordResetEmail
    ↓
User completes reset via email link
    ↓
Return to Login
```

No password reset for Google/Apple-only accounts — provider handles recovery.

### 7. Sign out

```
Profile → Sign Out
    ↓
Firebase Auth: signOut
    ↓
Clear local Firestore cache (optional policy — may retain for same-user re-login)
    ↓
Navigate to Auth Gate
```

Investigation data remains on server — local cache cleared to prevent cross-account leakage on shared devices.

### 8. Account deletion

```
Profile → Delete Account → confirm
    ↓
Mark users/{uid}.accountStatus = deletion_pending
    ↓
Cloud Function: cascade delete (Firestore + Storage)
    ↓
Firebase Auth: deleteUser
    ↓
Sign out → Auth Gate
```

See [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) delete strategy. Client-initiated deletion must not rely on client-only Firestore deletes.

---

## User Profile vs Auth Record

| Concern | Firebase Auth | Firestore `users/{uid}` |
|---|---|---|
| Password hash | Auth | — |
| OAuth tokens | Auth | — |
| Email | Auth | Denormalized copy |
| Display name | Auth (optional) | Canonical for app UI |
| Preferences | — | Firestore |
| Investigation data | — | Subcollections |

Auth is **identity**; Firestore user doc is **profile + ownership root**.

---

## Account Linking (future policy)

When a user signs in with Google using an email that matches an existing email/password account:

| Option | Recommendation |
|---|---|
| Auto-link | Firebase `linkWithCredential` after explicit user confirmation |
| Block duplicate | Reject with "account exists — sign in with email" |

**Recommendation:** Require explicit user confirmation before linking providers to prevent account takeover.

---

## Security Considerations

| Topic | Design |
|---|---|
| **Email verification** | Gate Trust Package export until verified (future policy) |
| **Brute force** | Firebase Auth rate limiting; App Check on auth endpoints (future) |
| **Token storage** | Firebase SDK secure storage — no custom JWT persistence |
| **Shared devices** | Sign out clears sensitive local cache |
| **No anonymous** | Prevents untraceable evidence creation |

---

## Client Integration Points (future — not implemented)

| Current (prototype) | Future (Firebase) |
|---|---|
| [`lib/services/auth_service.dart`](lib/services/auth_service.dart) mock | `FirebaseAuth` implementation |
| `create_account_screen.dart` | Wire to `createUserWithEmailAndPassword` |
| `login_screen.dart` | Wire to `signInWithEmailAndPassword` / OAuth |
| `forgot_password_screen.dart` | Wire to `sendPasswordResetEmail` |
| Any credentials succeed | Real Auth rejection handling |

UI screens exist — **wiring deferred** to backend integration sprint per MVP-0.9.3.1 scope.

---

## App Check Preparation

When authentication is integrated:

1. Enable App Check in Firebase console
2. Register iOS (App Attest), Android (Play Integrity), Web (reCAPTCHA) providers
3. Start in **monitoring mode** — log unattested requests without blocking
4. Enforce on Firestore, Storage, and Functions before production launch

Not implemented in MVP-0.9.3.1.

---

*MVP-0.9.3.1 — Authentication flow blueprint. No Firebase integration.*
