# Trust & Security Audit — Sprint 6.3

**Scope:** Evidence Vault Flutter application  
**Lens:** User trust, data protection, honest messaging, and release readiness  
**Reference:** Motorola moto g35 5G (primary Android target), `docs/LANGUAGE_SYSTEM.md` voice principles

---

## Executive Summary

Evidence Vault presents a **trust-oriented UX** with strong language, verification/integrity concepts, and permission foundations — but **security implementation lags behind user-facing promises**. The app is a presentation-layer prototype: workspace evidence is in-memory mock data, authentication is simulated, integrity flags are hardcoded, and encryption is claimed in copy but not implemented in code.

| Dimension | Grade | Notes |
|-----------|-------|-------|
| **Honest messaging** | ⚠️ Needs work | Encryption/E2E claims exceed implementation |
| **Permissions** | 🟡 Partial | Good dialog UX; workspace bypasses flow; Android 13+ gap |
| **Local storage** | 🔴 High risk | Plaintext files + JSON; no encryption at rest |
| **Backup / restore** | 🔴 Not implemented | No export, import, or disaster recovery |
| **Error handling** | 🟡 Inconsistent | Auth good; capture/metadata often silent |
| **Sensitive data** | 🟡 Mixed | No secrets in code; GPS/device PII in plaintext |
| **Logging** | ✅ Clean | No debug logging of user data found |
| **Crash handling** | 🔴 Absent | No global error zone or crash reporting |
| **Verification flow** | 🟡 UI only | Model exists; no workflow to reach "Verified" |
| **Integrity flow** | 🔴 Cosmetic | `integrityVerified: true` without hashing |

**Bottom line:** Safe for internal UX testing. **Not ready for legal, insurance, or public trust claims** until messaging is aligned with reality and core security controls are built.

---

## Trust Architecture (Current State)

```
┌─────────────────────────────────────────────────────────────────┐
│  USER-FACING TRUST CLAIMS                                       │
│  "Encrypted" · "E2E" · "Integrity Verified" · "Secure vault"  │
└────────────────────────────┬────────────────────────────────────┘
                             │  ← GAP: claims exceed implementation
┌────────────────────────────▼────────────────────────────────────┐
│  PRIMARY PATH (Home → Workspace)                                │
│  WorkspaceEvidenceController → in-memory mock items              │
│  integrityVerified: true (hardcoded)                             │
│  verification: Not Verified (never progresses)                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  LEGACY CAPTURE PATH (CreateEvidence — not linked from Home)    │
│  PermissionService → Capture → Preview → EvidenceStorageService │
│  Plaintext files in app documents + evidence_records.json       │
│  getAll() defined but never called from UI                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  AUTH (simulated)                                               │
│  Any email/password succeeds · Google/Apple are timed delays    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Permissions

### What exists

| Component | Path | Behaviour |
|-----------|------|-----------|
| Permission orchestration | `lib/services/permission_service.dart` | Maps evidence type → camera, mic, storage, location |
| Denied-state dialog | `lib/widgets/evidence/permission_dialog.dart` | Calm copy; "Not now"; "Open settings" when permanently denied |
| Android manifest | `android/app/src/main/AndroidManifest.xml` | Camera, mic, location, legacy + Android 13+ media read |
| iOS plist | `ios/Runner/Info.plist` | Usage descriptions for camera, mic, photos, location |
| Metadata location | `lib/services/metadata_service.dart` | Independent Geolocator permission path |

### Permission messages (tone ✅)

Messages follow `LANGUAGE_SYSTEM.md`: clear purpose, no pressure, settings guidance.

| Permission | Title | Message quality |
|------------|-------|-----------------|
| Camera | "Camera access needed" | ✅ Explains why; mentions settings |
| Microphone | "Microphone access needed" | ✅ Same pattern |
| Storage | "Storage access needed" | ✅ Same pattern |
| Location | "Location access needed" | ✅ Links metadata to verification purpose |

Dialog actions — **"Not now"** (not "Cancel" or "Deny") — align with compassionate voice.

### Findings

| # | Finding | Risk | Detail |
|---|---------|------|--------|
| P-1 | **Workspace bypasses permissions** | High | Home quick capture → `preserveEvidence()` creates mock items with no camera/mic/storage checks |
| P-2 | **Android 13+ storage mismatch** | Medium | `_storagePermission()` returns `Permission.storage`; manifest declares `READ_MEDIA_*`. Modern Android may need `Permission.photos` / `videos` / `audio` by type |
| P-3 | **Dual location prompts** | Low | `PermissionService` and `MetadataService` both request location independently |
| P-4 | **Capture services lack denial handling** | Medium | Photo/video/audio capture screens have no user-facing error if device/picker fails |
| P-5 | **No pre-request rationale** | Low | System dialog appears without in-app explanation first (post-denial dialog only) |

### Recommended improvements

1. Route all capture through `PermissionService.ensureAll()` before opening camera/mic/picker.
2. Map Android storage permissions by evidence type and API level (33+).
3. Consolidate location permission into one code path.
4. Add calm error states to capture screens: *"We couldn't access the camera. You can try again or check your settings."*
5. Consider optional location — let users preserve evidence without GPS when denied.

---

## 2. Local Storage

### What exists

| Platform | Implementation | Persistence |
|----------|----------------|-------------|
| IO (Android/iOS/desktop) | `lib/services/evidence_storage_service_io.dart` | `{AppDocuments}/evidence/` + `evidence_records.json` |
| Web | `lib/services/evidence_storage_service_web.dart` | In-memory only — lost on refresh |
| Init | `lib/main.dart` | `EvidenceStorageService.init()` at startup |

### Stored data (IO)

Each `EvidenceRecord` JSON entry includes:

- Title, description, category, type, timestamps
- **GPS coordinates** (latitude, longitude, accuracy)
- **Device model name** and platform
- **Absolute file paths** to media and thumbnails
- Full metadata blob

Files are copied to app documents as **plaintext** — no encryption, no content hash.

### Findings

| # | Finding | Risk | Detail |
|---|---------|------|--------|
| S-1 | **No encryption at rest** | Critical | Media files and JSON index readable if device is compromised or backed up unencrypted |
| S-2 | **Storage ↔ UI disconnect** | High | `getAll()` never called; Vault tab is placeholder; workspace uses separate in-memory state |
| S-3 | **Non-atomic JSON writes** | Medium | Read-modify-write on `evidence_records.json` — corruption risk if app killed mid-save |
| S-4 | **No integrity hash stored** | Critical | Cannot detect tampering of stored files |
| S-5 | **Web data ephemeral** | Medium | No persistence; users may assume evidence is saved |
| S-6 | **No delete/update API** | Medium | Records can only be appended |
| S-7 | **Unprotected JSON parse** | High | `_readAll()` has no try/catch — corrupt index could crash app on launch |

### Recommended improvements

1. **Sprint 4 priority:** Wire workspace to `EvidenceStorageService`; unify capture paths.
2. Encrypt at rest: SQLCipher, `flutter_secure_storage` for keys, or AES-encrypted file wrapper.
3. Store SHA-256 content hash at capture; verify on read.
4. Atomic writes: write to temp file, then rename; or use SQLite with transactions.
5. Wrap `_readAll()` in error handling with user-recoverable message.
6. Document clearly on web: *"Evidence is not saved on this device until you use the mobile app."*

---

## 3. Backup & Restore

### Current state: **Not implemented**

| Capability | Status |
|------------|--------|
| Encrypted backup export | ❌ |
| Restore from backup | ❌ |
| Trust Package file export (PDF, ZIP) | ❌ (UI preview only) |
| Cloud sync | ❌ |
| Share sheet / export | ❌ |
| Document import | ✅ Picker only (`document_import_service.dart`) — no validation manifest |

Trust Package and Story screens are read-only previews with comments reserving PDF, court bundle, and secure sharing for future sprints.

### Findings

| # | Finding | Risk |
|---|---------|------|
| B-1 | No user-controlled backup | High — device loss = evidence loss |
| B-2 | No restore integrity check | High — future import could accept tampered files |
| B-3 | Document import has no size/type limits | Medium |
| B-4 | Android auto-backup may include app documents | Medium — plaintext evidence in device backups unless excluded |

### Recommended improvements

1. Design encrypted export format with integrity manifest (hashes + metadata).
2. Add `android:allowBackup="false"` or `backup_rules.xml` excluding evidence directory until encrypted.
3. Restore flow: validate hashes before accepting imported evidence.
4. Trust Package export: start with password-protected ZIP + JSON manifest.
5. User-facing copy when export unavailable: *"Export is coming soon. Your evidence stays on this device for now."*

---

## 4. Error Handling

### Patterns observed

| Area | Pattern | User feedback | Assessment |
|------|---------|---------------|------------|
| Auth | `AuthException` + typed errors | Snackbars with retry for network | ✅ Good |
| Evidence save | `catch (_)` | "Unable to save evidence. Please try again." | ✅ Calm, no leak |
| Document import | `catch (_)` | Inline error + retry | ✅ Good |
| Metadata/location | `catch (_)` | Silent — empty location | ⚠️ Misleading |
| Capture screens | try/finally, no catch | No user error on failure | ⚠️ Gap |
| Storage temp cleanup | `catch (_)` | Silent (best-effort) | ✅ Acceptable |
| JSON index read | No catch | Potential crash | 🔴 Risk |

### Auth error messages (tone ✅)

| Message | Source | Tone |
|---------|--------|------|
| "Incorrect email or password. Please try again." | `auth_service.dart` | ✅ Neutral, no blame |
| "Network unavailable. Check your connection and try again." | `auth_service.dart` | ✅ Clear action |
| "Something went wrong. Please try again later." | `auth_service.dart` | ✅ Generic, safe |

### Workspace snackbars (tone ✅)

| Message | Assessment |
|---------|------------|
| "Evidence preserved." | ✅ Calm, factual — matches "Preserved" vocabulary |
| "Evidence linked." | ✅ |
| "Relationship created. Context preserved." | ✅ |
| "Reflection Added" | ⚠️ Minor — prefer "Reflection preserved." per language system |

### Recommended improvements

1. Surface location unavailability: *"Location wasn't available. Evidence was still preserved."*
2. Add capture failure messages without alarm: *"We couldn't complete the capture. Please try again."*
3. Guard JSON index load with recovery path (reset or restore from backup).
4. Add `runZonedGuarded` for unhandled async errors (see Crash Handling).
5. Avoid exposing exception strings to users.

---

## 5. Sensitive Data Exposure

### Secrets & credentials

| Check | Result |
|-------|--------|
| API keys in source | ✅ None found |
| Firebase config | Not integrated (TODOs only) |
| `.env` / credentials files | Not in repo |
| Password persistence | ✅ No SharedPreferences — nothing stored locally |
| Auth tokens | N/A — simulated auth |

### PII collected and displayed

| Data | Where stored/shown | Protection |
|------|-------------------|------------|
| GPS coordinates | JSON index, metadata panel | ❌ Plaintext |
| Device model | JSON index, metadata panel | ❌ Plaintext |
| Evidence UUID | Preview screen | Display only |
| User email (auth forms) | In memory during session | Not persisted |
| Mock names (Library insights) | `home_dashboard_mock.dart` | Hardcoded fiction only |

### Critical: Overstated security claims

| UI claim | Location | Reality |
|----------|----------|---------|
| **"Encrypted" / "End-to-End Protection"** | `splash_screen.dart` feature card | No encryption code exists |
| **"Your information is encrypted and never shared."** | `login_screen.dart`, `create_account_screen.dart` | Plaintext local storage; no sharing controls built |
| **"encrypted end-to-end"** | `terms_checkbox.dart` | No E2E crypto |
| **"Signed in with Google/Apple"** | `splash_screen.dart` | Simulated delay — no OAuth |
| **"Integrity Verified"** | Workspace cards, Evidence Record, Trust Package | Hardcoded `integrityVerified: true` |
| **"Create your secure vault"** | `create_account_screen.dart` | No vault encryption |

**Legal/trust risk:** These claims violate `LANGUAGE_SYSTEM.md` principle — *"Never marketing driven"* — when the marketing claims security that does not exist.

### Recommended improvements

1. **P0 — Align copy with reality** before any external release (see Messaging section).
2. Classify data: evidence media = sensitive; metadata = PII; logs = never contain either.
3. When encryption ships, update copy only after implementation is verified.
4. Add privacy policy link (terms checkbox references T&C but no live policy URL observed).
5. Redaction option for location in future export flows.

---

## 6. Logging

### Current state: **Minimal — positive for privacy**

| Mechanism | Present? |
|-----------|----------|
| `print()` / `debugPrint()` in `lib/` | ❌ None found |
| `logger` / `logging` package | ❌ Not in dependencies |
| Firebase Analytics / Crashlytics | ❌ |
| Audit trail (chain of custody) | ❌ |

### Findings

| # | Finding | Assessment |
|---|---------|------------|
| L-1 | No accidental PII logging | ✅ Strong |
| L-2 | No structured audit log | ⚠️ Gap for trust product |
| L-3 | No crash reporting | ⚠️ See Crash Handling |

### Recommended improvements

1. Add structured audit events (capture, link, export attempt) — stored locally, never logged to console in release.
2. If crash reporting added (Sentry/Crashlytics), scrub file paths, GPS, and user content from reports.
3. Establish logging policy: debug-only, no evidence content, no coordinates in production builds.

---

## 7. Crash Handling

### Current state: **Absent**

`lib/main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EvidenceStorageService.init();
  runApp(const EvidenceVaultApp());
}
```

| Mechanism | Present? |
|-----------|----------|
| `FlutterError.onError` | ❌ |
| `PlatformDispatcher.instance.onError` | ❌ |
| `runZonedGuarded` | ❌ |
| Custom `ErrorWidget.builder` | ❌ |
| Crash reporting (Sentry, Crashlytics) | ❌ |

### Findings

| # | Finding | Risk |
|---|---------|------|
| C-1 | Unhandled async errors may crash silently or show red screen | Medium |
| C-2 | Corrupt storage index could crash on startup | High |
| C-3 | No crash telemetry for release monitoring | Medium |

### Recommended improvements

1. Wrap `main()` in `runZonedGuarded` with error handler.
2. Set `FlutterError.onError` to log to crash service (scrubbed) in release.
3. User-facing fallback: *"Something unexpected happened. Your preserved evidence is safe. Please reopen the app."* (once storage is wired).
4. Custom error widget for release builds — calm, branded, no stack traces.

---

## 8. Verification Flow

### Architecture (well-designed, not implemented)

| File | Role |
|------|------|
| `lib/models/verification_model.dart` | Status, method, notes, events |
| `lib/models/verification_status.dart` | `notVerified`, `verificationPending`, `verified` |
| `lib/models/verification_factory.dart` | Derives display state from artifacts |
| `lib/widgets/verification/verification_section.dart` | Evidence Record pillar |
| `lib/widgets/verification/verification_badge.dart` | Compact badge on cards |

**Design strength:** Verification is correctly separated from Integrity in model and UI comments.

### Current behaviour

- New evidence: `VerificationFactory.initial()` → **Not Verified** ✅ honest default
- **No workflow** transitions status to Pending or Verified
- Package-level aggregation: if all artifacts verified → shows "Verified" with method **"Not yet assigned"**
- Verified state is **unreachable** in normal user flow

### User-facing verification messages

| State | Label | Tone |
|-------|-------|------|
| Not verified | "Not Verified" | ✅ Honest |
| Pending | "Verification Pending" | ✅ |
| Verified | "Verified" + check | ⚠️ Unreachable today |
| Method | "Not yet assigned" | ✅ Honest placeholder |
| Notes | "No verification notes recorded." | ✅ |

### Findings

| # | Finding | Risk |
|---|---------|------|
| V-1 | Verification is presentation-only | High |
| V-2 | "Verified" badge logic exists but never triggered | Medium |
| V-3 | Future methods documented (hash, blockchain, witness) — none built | Info |

### Recommended improvements

1. Until verification workflow exists, keep badges subtle for Not Verified; hide or soften Verified affordances.
2. Implement minimum viable verification: manual "Mark as reviewed" with timestamp + optional note (user-initiated, not automated claim).
3. Long-term: hash verification, digital signatures, witness attestation — per model extension points.
4. Copy for unverified: *"This evidence has not been independently verified yet."*

---

## 9. Integrity Flow

### Current behaviour

```dart
// lib/models/workspace_evidence_factory.dart
integrityVerified: true,  // hardcoded for every captured item
verification: VerificationFactory.initial(),
```

Trust Package integrity:

```dart
// lib/trust_package/trust_package_builder.dart
final integrityVerified = artifacts.isNotEmpty &&
    artifacts.every((artifact) => artifact.integrityVerified);
```

Since all artifacts are hardcoded `true` → **Integrity Verified** shown whenever any evidence exists.

### UI surfaces

| Surface | Message |
|---------|---------|
| Evidence Record | "Integrity Verified" + "Original evidence remains unchanged." |
| Artifact cards | Green "Integrity Verified" badge |
| Trust Package | Integrity section with explanation |
| Library tiles | Integrity indicator |

### Findings

| # | Finding | Risk |
|---|---------|------|
| I-1 | Integrity flag is cosmetic — no hash/checksum | **Critical** |
| I-2 | "Original evidence remains unchanged" is unverifiable | **Critical** |
| I-3 | No chain-of-custody event log | High |
| I-4 | Model comments reserve hash/custody — not built | Info |

### Recommended improvements

1. **P0:** Change default to `integrityVerified: false` until hash computed at capture.
2. Compute SHA-256 of file content at save; store hash in record; re-verify on open.
3. Integrity copy when unverified: *"Integrity check pending"* or *"Preserved — verification not yet run."*
4. When verified: *"Content hash matches original capture."* — only after actual check.
5. Append-only custody ledger: capture → link → export events with timestamps.

---

## 10. User-Facing Message Review

Audited against `docs/LANGUAGE_SYSTEM.md`: calm, trustworthy, objective, never marketing-driven, prefer "Preserved" over "Completed."

### ✅ Messages that meet the bar

| Category | Examples |
|----------|----------|
| **Home hero** | "Preserve your truth now." / "Protect what matters later." |
| **Library empty** | "Every library begins with one piece of truth." |
| **Evidence Map empty** | Guided preserve copy |
| **Reflection** | "Sometimes understanding comes with time." |
| **Permission dialogs** | Purpose-specific, settings guidance, "Not now" |
| **Trust Package empty** | "No preserved information is available to prepare a trust package yet." |
| **Errors (auth/save)** | Neutral, actionable, no blame |
| **Workspace actions** | "Evidence preserved." — factual, calm |

### ⚠️ Messages that need revision

| Current copy | Location | Issue | Suggested direction |
|--------------|----------|-------|---------------------|
| "Encrypted" / "End-to-End Protection" | `splash_screen.dart` | Overclaims | "Protected on your device" or remove until crypto ships |
| "Your information is encrypted and never shared." | Login, Create Account | False | "Your evidence stays on this device. You control what you share." |
| "encrypted end-to-end" | `terms_checkbox.dart` | False | "stored securely on your device" (once true) or remove |
| "Create your secure vault" | Create Account | Overclaims | "Create your vault" |
| "Integrity Verified" (always shown) | Cards, Record, Trust Package | Misleading | Show only after hash verification; else "Preserved" |
| "Evidence Map coming in Sprint 5" | `home_screen.dart` | Dev placeholder | Remove before release |
| "Profile details coming soon." | Profile | Dev placeholder | Remove or replace |
| "Reflection Added" | Workspace snackbar | Language system | "Reflection preserved." |
| "Signed in with Google/Apple" | Splash | Simulated auth | Only show after real OAuth |

### ❌ Messages to avoid adding

Per language system: "Congratulations!", "Great job!", "100% Complete", urgency/scarcity, gamification.

---

## Security Observations Summary

### Strengths

1. **No debug logging of PII** in application code.
2. **Permission dialog UX** — calm, clear, compassionate; aligns with language system.
3. **Verification vs Integrity separation** — sound domain model ready for real implementation.
4. **Auth error handling** — typed exceptions, network retry, generic fallback.
5. **Conditional storage** — clean IO/web split.
6. **Manifest/plist** — camera, mic, location, media permissions declared.
7. **Default verification state** — Not Verified is honest for new evidence.
8. **No hardcoded secrets** in repository.

### Weaknesses

1. **Trust copy exceeds implementation** — highest legal and reputational risk.
2. **Hardcoded integrity verified** — undermines core product promise.
3. **Simulated authentication** — any credentials succeed.
4. **Plaintext evidence storage** — device compromise = full exposure.
5. **Dual data paths** — workspace mock vs file storage creates confusion and false confidence.
6. **No backup, export, or restore** — single point of failure (device).
7. **No crash handling or reporting** — silent failures possible.
8. **Workspace bypasses permission model** — users may not understand what was actually captured.

---

## Recommended Improvements (Prioritized)

### P0 — Before any public or legal use

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | **Revise security/marketing copy** to match actual behaviour | Small | Critical trust |
| 2 | **Stop showing "Integrity Verified"** until hash verification exists; default `integrityVerified: false` | Small | Critical trust |
| 3 | **Integrate real authentication** (Firebase or equivalent) | Medium | Critical security |
| 4 | **Document prototype status** internally — no legal reliance on current build | Small | Risk management |

### P1 — Sprint 4+ foundation

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 5 | Unify workspace with `EvidenceStorageService` | Large | Data integrity |
| 6 | SHA-256 at capture; verify on read | Medium | Integrity |
| 7 | Encrypt evidence at rest | Large | Storage security |
| 8 | Atomic storage writes + corrupt index recovery | Medium | Reliability |
| 9 | Route all capture through permission flow | Medium | Privacy compliance |
| 10 | Fix Android 13+ storage permission mapping | Small | Android compliance |

### P2 — Release hardening

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 11 | Global error handling + crash reporting (scrubbed) | Medium | Reliability |
| 12 | Encrypted backup/export with integrity manifest | Large | User trust |
| 13 | Exclude evidence from Android auto-backup until encrypted | Small | Backup security |
| 14 | Location/capture failure surfaced in UI | Small | Honest UX |
| 15 | Minimum verification workflow (manual review) | Medium | Trust product fit |

### P3 — Future trust features

| # | Action |
|---|--------|
| 16 | Chain-of-custody audit log |
| 17 | Trust Package PDF/export with redaction options |
| 18 | Witness attestation, digital signatures |
| 19 | Optional cloud sync with E2E encryption (only then use "E2E" in copy) |
| 20 | Structured audit logging policy |

---

## Release Readiness — Trust Checklist

| Requirement | Status |
|-------------|--------|
| Copy matches implementation | ❌ |
| Auth protects user accounts | ❌ |
| Evidence encrypted at rest | ❌ |
| Integrity cryptographically verifiable | ❌ |
| Permissions enforced on all capture paths | ❌ |
| Errors communicated calmly and honestly | 🟡 Partial |
| No PII in logs | ✅ |
| Backup/restore available | ❌ |
| Crash handling in place | ❌ |
| Verification workflow functional | ❌ |
| Language system compliance | 🟡 Mostly (except security claims) |

---

## Manual QA — Trust Scenarios (Motorola reference device)

1. **Deny camera** on legacy capture path → confirm dialog copy and no silent success.
2. **Deny location** → confirm metadata panel shows empty coordinates; user should see explanation (currently silent).
3. **Capture via workspace** → confirm no real file created; understand mock vs real gap.
4. **Read splash/login copy** → confirm no encryption claims until implemented.
5. **Open Evidence Record** → confirm integrity badge honesty after P0 fix.
6. **Kill app during save** → test JSON index corruption behaviour.
7. **Background app, revoke permission, resume capture** → expect graceful handling.
8. **Review all snackbars** during capture/link/reflection flow for tone consistency.

---

## Conclusion

Evidence Vault has **excellent trust-oriented language and information architecture** — the separation of Integrity and Verification, compassionate permission dialogs, and calm workspace messaging demonstrate strong product thinking. The critical gap is **implementation fidelity**: users are told their data is encrypted and integrity-verified when it is not.

Sprint 6.3 recommends treating the current build as a **UX prototype for trust flows**, not a security product. Address P0 messaging and integrity honesty immediately; pursue P1 storage and crypto work in Sprint 4 before any release where users might rely on evidence for legal or personal protection purposes.

---

*Sprint 6.3 — Trust & Security Audit. Documentation only; no code changes in this sprint.*
