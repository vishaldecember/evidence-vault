**Version:** MVP-0.9.3.4  
**Status:** Authentication Production Polish  
**Last Updated:** August 4, 2026

# Firebase Setup — Session Foundation

This document covers **authentication verification, session restoration, and production polish** for Evidence Vault.

Project configuration (FlutterFire, packages, environments) lives in the root guide:

→ [`../FIREBASE_SETUP.md`](../FIREBASE_SETUP.md)

---

## MVP-0.9.3.4 — Authentication Production Polish

| Item | Status |
|---|---|
| Premium auth Material banners | ✅ |
| Account exists → Go to Sign In | ✅ |
| Email login → MainShell (AuthGate clears stacked routes) | ✅ |
| Returning users skip name gate | ✅ |
| Debug SHA-1 / SHA-256 registered on Android app | ✅ |
| Google provider enabled in Firebase Console | ⏳ Enable once in console, then refresh `google-services.json` |
| Session restoration | ✅ Unchanged |
| Firestore | ❌ Not in this sprint |

### Development defaults (documented intentionally)

- Firebase **default password-reset page** uses a **single password field** — expected; no custom reset UI in MVP.
- Firebase **default auth emails** use `*.firebaseapp.com` during development — production branding after domain deployment.

---

## MVP-0.9.3.3A — Complete

Firebase Authentication is operational on **Evidence Vault Dev** (`evidence-vault-dev`).  
No Firestore persistence. No investigation data writes.

| Check | Status |
|---|---|
| Email/Password register | ✅ Verified against Firebase Auth API |
| Email/Password sign-in | ✅ Verified |
| Session restore on restart | ✅ Firebase Auth persistence + `AuthGate` |
| Sign-out → authentication entry | ✅ Profile → Sign Out → Splash |
| Users visible in Firebase Console | ✅ Project `evidence-vault-dev` |
| Firestore / Incident collections | ❌ Not in this sprint |

---

## Environment

| Environment | Project ID | Usage |
|---|---|---|
| Development | `evidence-vault-dev` | All MVP auth development |
| Production | `evidence-vault-f1b1e` | Reserved — not connected |

---

## AuthService Contract

`lib/services/auth_service.dart` (facade) → `AuthenticationService` → `FirebaseAuthRepository`

| API | Responsibility |
|---|---|
| `register(name, email, password)` | Create email/password account |
| `signIn(email, password)` | Sign in |
| `signOut()` | Clear Firebase + local session |
| `currentUser` | Current Firebase `User?` |
| `authStateChanges()` | Stream for session restore |

UI screens use this facade. Investigation logic must not call Firebase Auth directly.

---

## Session Flow

```
Launch
  → FirebaseBootstrap.initialize()
  → AuthenticationStateProvider listens to authStateChanges()
  → AuthGate
       ├─ Authenticated (fresh registration, no displayName)
       │     → WelcomeNameScreen
       ├─ Authenticated (returning / named)
       │     → MainShellScreen
       │     (pops Login / Create Account off the stack)
       └─ Unauthenticated → SplashScreen → Sign In / Create Account
```

- Firebase Auth persists the session on device.
- Cold start restores `currentUser` without re-entering credentials.
- Sign Out clears Firebase Auth and `UserSessionService`, returning to Splash.

---

## Manual Validation

1. `flutter run` (Android) against `evidence-vault-dev`
2. Duplicate email → premium banner with **Go to Sign In**
3. Email Sign In → **MainShell** immediately (Login route cleared)
4. Kill app → relaunch → still signed in
5. Profile → Sign Out → Splash
6. After enabling Google in Firebase Console → Google Sign-In completes

---

## Isolation Rules

- Do **not** write Incidents, Evidence, or other investigation data to Firestore.
- Auth failures must not crash the app.
- Passwords are never stored locally.
- Do **not** redesign onboarding (permanent freeze) except auth polish / correctness.

---

*MVP-0.9.3.4 — Authentication production polish.*
