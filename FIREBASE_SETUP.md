**Version:** MVP-0.9.3.3A  
**Status:** Developer Onboarding — Firebase Setup  
**Last Updated:** August 4, 2026 (MVP-0.9.3.3A — Authentication Verification & Session Foundation)

# Firebase Setup — Evidence Vault

This guide documents how the Flutter app connects to Firebase. **Authentication + Storage + Firestore (Sprint 4B)** — investigation evidence persists and restores on launch.

Related: [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) · [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) · [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) · [`DATA_MODEL.md`](DATA_MODEL.md) · [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md)

### MVP-0.9.3.3A status: ✅ Complete

Email/Password auth, session restore, and sign-out verified against `evidence-vault-dev`. See [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

### Sprint 4A status: ✅ Storage uploads

Workspace Photo / Video / Voice / Attachment captures upload to:

`users/{uid}/incidents/{incidentId}/{photos|videos|voice|attachments}/{evidenceId}.{ext}`

Deploy rules: `firebase deploy --only storage --project evidence-vault-dev` (see [`storage.rules`](storage.rules)).

### Sprint 4D status: ✅ Production hardening

- Full investigation graph persisted (anchors, groups, relationships, narrative, notes)
- Home + Vault load real incidents from Firestore
- Durable offline upload queue with automatic retry
- Hardened rules: immutable fields, Storage create-only + size/MIME limits, `thumbnails/`
- Deploy: `firebase deploy --only firestore:rules,storage --project evidence-vault-dev`

See [`DATA_MODEL.md`](DATA_MODEL.md) and [`SPRINT_4D_PRODUCTION_READINESS_REPORT.md`](SPRINT_4D_PRODUCTION_READINESS_REPORT.md).

---

## Environment Strategy

Evidence Vault uses **separate Firebase projects per environment**. Never point MVP development at production.

| Environment | Display Name | Project ID | Status |
|---|---|---|---|
| **Development** | Evidence Vault Dev | `evidence-vault-dev` | **Active — all MVP development** |
| **Production** | Evidence Vault | `evidence-vault-f1b1e` | Reserved — not connected to this codebase |

**Do not connect to:**

- `evidence-vault-f1b1e` (Production) during MVP development  
- `fir-demo-project` (Firebase Demo Project)

### Development project (connected)

| Property | Value |
|---|---|
| Project Name | Evidence Vault Dev |
| Project ID | `evidence-vault-dev` |
| Project Number | `818342288871` |
| Storage Bucket | `evidence-vault-dev.firebasestorage.app` |
| Android App ID | `1:818342288871:android:66d17269bb2022b3f2f142` |
| iOS App ID | `1:818342288871:ios:d7ab2eaae9877d8bf2f142` |
| Package Name | `com.example.evidence_vault` |
| iOS Bundle ID | `com.example.evidenceVault` |

> **Storage bucket note:** New Firebase projects expose the default bucket as `{project-id}.firebasestorage.app`. The legacy `{project-id}.appspot.com` alias may still resolve, but generated SDK configs use the `.firebasestorage.app` form returned by Firebase.

---

## Enable Services (Development Console)

In [Firebase Console](https://console.firebase.google.com/project/evidence-vault-dev):

| Service | Status | Notes |
|---|---|---|
| **Authentication** | Required | Email/Password + Google |
| **Cloud Firestore** | **Required (Sprint 4B)** | Incident + evidence metadata via Firebase repos |
| **Firebase Storage** | **Required (Sprint 4A/4B)** | Capture binaries via `StorageRepository` |
| **App Check** | Prepare only | Enforcement deferred to Phase 5 |

---

## Package Versions

Pinned in `pubspec.yaml`:

| Package | Version |
|---|---|
| `firebase_core` | ^4.12.1 |
| `firebase_auth` | ^6.5.6 |
| `cloud_firestore` | ^6.7.1 |
| `firebase_storage` | ^13.4.5 |
| `google_sign_in` | ^7.2.0 |

CLI (global):

| Tool | Install |
|---|---|
| Firebase CLI | `npm install -g firebase-tools` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |

Ensure Node.js, npm, and `dart pub global` bin directories are on your `PATH`.

---

## Setup Commands

### 1. Install tools and authenticate

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

### 2. Configure FlutterFire (development project)

From the repository root:

```bash
dart pub global run flutterfire_cli:flutterfire configure \
  --project=evidence-vault-dev \
  --platforms=android,ios \
  --yes \
  --overwrite-firebase-options
```

This regenerates:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 3. Android Google Sign-In

Debug keystore fingerprints for `evidence-vault-dev` (registered MVP-0.9.3.4):

| Type | Hash |
|---|---|
| SHA-1 | `96:BA:58:25:0D:91:3B:A8:A0:A5:46:BD:CB:1A:54:4D:AE:4F:71:E9` |
| SHA-256 | `F5:3E:A5:38:C0:0F:50:79:BC:60:E0:4E:DA:38:EE:2D:70:DC:A0:C2:E8:11:DA:3B:AC:A7:8D:CE:2D:67:B6:75` |

**Required console step (one-time):**

1. Firebase Console → Authentication → Sign-in method → **Google** → Enable  
2. Save (Firebase creates OAuth client IDs automatically)  
3. Re-download `google-services.json` (or re-run FlutterFire configure)  
4. Confirm `oauth_client` is no longer empty in `android/app/google-services.json`

Until Google is enabled in the console, `oauth_client` remains `[]` and Google Sign-In cannot complete.

Verify fingerprints anytime:

```bash
# Android Studio JBR keytool
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 4. iOS Google Sign-In (prepare only)

After `flutterfire configure`, copy `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` (when present) into `ios/Runner/Info.plist` → `CFBundleURLSchemes`.

### 5. Run

```bash
flutter pub get
flutter run
```

---

## Development Auth Defaults (intentional)

### Password reset page

Firebase’s **default** password-reset hosted page uses a **single password field**. This is expected Firebase behaviour during development.

Do **not** build a custom password-reset page in MVP. Production branding of reset pages happens after custom domain deployment.

### Auth emails

Firebase default authentication emails (verification, password reset) send from / reference `*.firebaseapp.com` (e.g. `evidence-vault-dev.firebaseapp.com`) during development.

Custom email templates and branded domains are deferred until production domain deployment.

---

## Generated Configuration Files

| File | Purpose |
|---|---|
| `lib/firebase_options.dart` | Dart Firebase options (`DefaultFirebaseOptions`) |
| `android/app/google-services.json` | Android SDK config |
| `ios/Runner/GoogleService-Info.plist` | iOS SDK config |

Validate after reconfiguration:

```bash
# projectId must be evidence-vault-dev everywhere
grep -r "project_id\|projectId" lib/firebase_options.dart android/app/google-services.json ios/Runner/GoogleService-Info.plist

# must NOT reference production or demo projects
grep -r "evidence-vault-f1b1e\|fir-demo-project" lib/firebase_options.dart android/app/google-services.json ios/
```

---

## Application Architecture

Authentication is isolated from UI:

```
lib/
  services/auth/
    authentication_service.dart
    firebase_bootstrap.dart
    auth_error_mapper.dart
  repositories/auth/
    auth_repository.dart
    firebase_auth_repository.dart
  providers/
    authentication_state_provider.dart
  widgets/auth/
    auth_gate.dart
```

---

## App Check (Prepare Only)

1. Firebase Console → App Check → register Android/iOS apps  
2. Use **Debug provider** during development  
3. Do **not** enforce until Phase 5

---

## Security Notes

- Passwords are never stored locally — Firebase Auth only  
- Auth tokens are not exposed to UI or logs  
- Investigation data remains **local** until Firestore sync (Phase 2+)  
- Development builds must target `evidence-vault-dev` only

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| `Firebase CLI not found` | Install Node.js; run `npm install -g firebase-tools` |
| `flutterfire` not found | Add `%LOCALAPPDATA%\Pub\Cache\bin` to PATH |
| Wrong project connected | Re-run configure with `--project=evidence-vault-dev` |
| Google Sign-In fails on Android | Add SHA-1; verify package name matches Firebase app |
| App shows “Authentication temporarily unavailable” | Check network and `firebase_options.dart` values |

---

*MVP-0.9.3.2A — Flutter connected to Evidence Vault Dev (`evidence-vault-dev`).*
