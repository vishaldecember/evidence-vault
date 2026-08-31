**Version:** Sprint 4C  
**Status:** Backend Verification & Production Readiness Audit  
**Date:** August 5, 2026  
**Project:** Evidence Vault (`evidence-vault-dev`)

# Sprint 4C — Production Readiness Report

This is a **code + architecture audit** of the Sprint 4A/4B cloud backend.  
No new product features were built. UI was not redesigned.

**Verdict scale:** PASS · WARNING · FAIL

---

## Executive summary

| Area | Result |
|---|---|
| 1. Firebase Storage | **WARNING** |
| 2. Firestore | **WARNING** |
| 3. Data persistence | **WARNING** |
| 4. Screen synchronization | **WARNING** |
| 5. Repository architecture | **PASS** |
| 6. Security rules | **WARNING** |
| 7. Error handling | **WARNING** |
| 8. Performance | **PASS** |
| 9. Console verification | **PASS** (instructions) |
| 10. Documentation | **WARNING** → updated |

**Readiness score: 72 / 100**

**Sprint 5 (Intelligence Layer): CONDITIONAL GO**  
Proceed for intelligence features that only need **incident + evidence** cloud truth.  
Do **not** treat relationship / narrative / reconstruction cloud sync as done — that remains Phase 4.

---

## PART 1 — Firebase Storage Verification — WARNING

### Implemented (PASS aspects)

| Check | Status | Evidence |
|---|---|---|
| Photo / Video / Voice / Attachment upload | PASS | `EvidenceUploadCoordinator` → `StorageRepository` → `EvidenceStorageService` |
| Hierarchy `users/{uid}/incidents/{incidentId}/{photos\|videos\|voice\|attachments}/` | PASS | `evidence_storage_service.dart` |
| Filename `{evidenceId}.{ext}` | PASS | Same |
| MIME / contentType | PASS | `_contentTypeFor` + `SettableMetadata` |
| `downloadUrl` + `storagePath` returned | PASS | `StorageUploadResult` |
| Thumbnail under `photos/{id}_thumb.jpg` | PASS | Coordinator thumb upload |
| Notes skip Storage | PASS | By design |

### Gaps

| Issue | Severity |
|---|---|
| Legacy `EvidencePreviewScreen` uploads under `incidentId: 'standalone'` | **FAIL** (dual path) |
| Web uploads throw `UnsupportedError` | WARNING |
| No live Console proof in this audit (requires signed-in device) | WARNING |

**Manual Console check required** before calling Storage production-complete (see Part 9).

---

## PART 2 — Firestore Verification — WARNING

### Actual collection layout (PASS)

```
users/{uid}
users/{uid}/incidents/{incidentId}
users/{uid}/incidents/{incidentId}/evidence/{evidenceId}
```

### Incident document fields (implemented)

`incidentId`, `ownerId`, `title`, `status`, `manuallyComplete`, `createdAt`, `updatedAt`,  
`timelineCount`, `relationshipCount`, `narrativeCount`, `reconstructionHealth`, `activeIncident`

User doc: `activeIncidentId`, `updatedAt`

### Evidence document fields (implemented)

| Field | Present |
|---|---|
| `evidenceId` | ✅ |
| `incidentId` | ✅ |
| `type` / `kind` | ✅ |
| `storagePath` | ✅ (null until upload succeeds) |
| `downloadUrl` | ✅ |
| `thumbnailUrl` | ✅ |
| `filename` | ✅ |
| `mimeType` (content type) | ✅ |
| `fileSizeBytes` | ✅ |
| `capturedAt` (capture timestamp) | ✅ *name differs from `captureTimestamp`* |
| `device` | ✅ |
| `location.{latitude,longitude}` | ✅ when available |
| `notes` | ✅ (*context* not a separate field) |
| `timelineOrder` | ✅ |
| `parentEvidenceId` / `supportingEvidenceIds` / `relationshipType` / `linkedCapturedEvidenceIds` | ✅ (supporting) |
| `userId` | ❌ **MISSING** (path ownership only; incident uses `ownerId`) |
| `createdAt` / `updatedAt` on evidence | ❌ **MISSING** |
| `context` | ❌ **MISSING** (use `notes`) |
| `captureTimestamp` | ❌ use `capturedAt` |

### Missing metadata report

1. Explicit `userId` on evidence documents  
2. Evidence-level `createdAt` / `updatedAt`  
3. Dedicated `context` field (only `notes`)  
4. Checklist name `captureTimestamp` → implemented as `capturedAt`  
5. Relationship **groups**, narrative events, reconstruction notes — **not** Firestore collections yet  

---

## PART 3 — Data Persistence — WARNING

| Scenario | Code-path status | Notes |
|---|---|---|
| Capture → kill app → relaunch | **PASS** (designed) | Auth session + `WorkspaceSession.restoreForSignedInUser` loads incident + evidence |
| Logout → login | **PASS** (designed) | Same restore; sign-out clears local session then reloads from cloud |
| Evidence binaries survive | **PASS** | Firebase Storage |
| Evidence metadata survives | **PASS** | Firestore evidence subcollection |
| Relationship groups survive | **FAIL** | In-memory only — lost on restart |
| Narrative events / reconstruction notes | **FAIL** | In-memory only |
| Participants | **FAIL** | In-memory only |
| Upload retry queue survives kill | **FAIL** | In-memory queue |

**No data loss** applies to **workspace evidence + incident title/status** when the user is signed in and rules are deployed.  
Investigation graph beyond evidence is **not** durable yet.

---

## PART 4 — Screen Synchronization — WARNING

| Screen | Loads from shared cloud-backed aggregate? | Notes |
|---|---|---|
| Capture | PASS | `WorkspaceSession` / `CurrentIncident` |
| Organize | PASS | Same controller |
| Investigation | WARNING | Evidence yes; Connect/relationship/narrative state not cloud-restored |
| Trust Package | WARNING | Assembles from aggregate — evidence real; empty relationships after restart |
| Evidence Inspector | PASS | Reads controller evidence |
| Incident title everywhere | PASS | `updateIncidentName` → notify + Firestore persist |
| Home / Vault | FAIL | Still mock / placeholder (`HomeDashboardMock`, vault placeholder) |

---

## PART 5 — Repository Architecture — PASS

| Rule | Status |
|---|---|
| Screens/widgets do not import `cloud_firestore` / `firebase_storage` | PASS |
| Storage via `StorageRepository` / `EvidenceStorageService` | PASS |
| Firestore via `FirebaseIncidentRepository` / `FirebaseEvidenceRepository` | PASS |
| Auth via `AuthRepository` / `AuthenticationService` | PASS |
| Sync orchestration via `IncidentCloudSyncService` | PASS |
| Controllers call repositories/services — not SDKs | PASS |

Minor: auth layer types still reference `firebase_auth.User` on the repository interface (acceptable for now).

---

## PART 6 — Security Rules — WARNING

### Firestore (`firestore.rules`)

| Check | Status |
|---|---|
| Authenticated owner only (`auth.uid == userId`) | PASS |
| Anonymous denied | PASS |
| User A cannot read User B path | PASS (path-based) |
| Unmatched collections default-deny | PASS |
| Field validation / write-once originals | FAIL (not implemented) |
| Soft-delete / cascade policy | FAIL (owner `write` includes delete) |

### Storage (`storage.rules`)

| Check | Status |
|---|---|
| Owner-only under `users/{uid}/incidents/...` | PASS |
| Media type whitelist | PASS |
| Anonymous denied | PASS |
| Size / content-type enforcement | FAIL (not in rules) |
| Write-once immutability | FAIL |

### Recommendations

1. Split `write` into `create` / `update` / `delete` with stricter delete policy  
2. Require `request.resource.data.ownerId == request.auth.uid` on incident docs  
3. Add `userId` (or `ownerId`) on evidence docs and validate in rules  
4. Cap `request.resource.size` in Storage rules  
5. Add Firebase Rules unit tests + App Check (Phase 5)  
6. Deploy rules if not already:  
   `firebase deploy --only firestore:rules,storage --project evidence-vault-dev`

---

## PART 7 — Error Handling — WARNING

| Check | Status | Evidence |
|---|---|---|
| Local copy retained on upload failure | PASS | Local `filePath` + evidence kept; `markUploadFailed` |
| Upload queued | PASS | `EvidenceUploadQueue` |
| Manual retry UI | PASS | “Upload failed. Retry?” |
| Automatic retry when network returns | FAIL | No connectivity listener / `retryAll` auto-drain |
| Queue survives app kill | FAIL | Memory-only |
| Offline capture still creates evidence | PASS (workspace) | Create local first, upload async |

---

## PART 8 — Performance Audit — PASS

| Check | Status |
|---|---|
| Image compression before upload | PASS | `MediaPreprocessService` (max 1920px, JPEG q75) |
| Thumbnail generation | PASS | 512px edge + Storage upload |
| Async uploads (non-blocking) | PASS | `unawaited` + progress snackbars |
| UI freeze on capture | PASS (design) | Upload off critical path |
| Duplicate uploads | PASS (intended) | Same `evidenceId` path overwrites; queue dedupes by id |
| Orphan Storage risk | WARNING | Legacy `standalone/` path; failed Firestore after Storage success possible |
| Orphan Firestore risk | WARNING | Metadata can exist with null `downloadUrl` if upload never succeeds |

---

## PART 9 — Console Verification Instructions — PASS

### Prerequisites

1. Enable **Authentication**, **Firestore**, **Storage** on `evidence-vault-dev`  
2. Deploy rules (Part 6)  
3. Sign in on a **physical device / emulator** with network  
4. Capture Photo, Video, Voice, File from the **workspace** capture bar (not legacy Create Evidence)

### Storage Console

Path: Firebase Console → Storage → Files

Expected:

```
users/
  {yourUid}/
    incidents/
      {incidentId}/
        photos/
          {evidenceId}.jpg
          {evidenceId}_thumb.jpg
        videos/
          {evidenceId}.mp4
        voice/
          {evidenceId}.m4a
        attachments/
          {evidenceId}.{ext}
```

Verify object metadata: `contentType`, custom keys `userId`, `incidentId`, `evidenceId`, `captureTime`, GPS if granted.

### Firestore Console

Path: Firebase Console → Firestore

Expected documents:

```
users/{uid}
  → activeIncidentId

users/{uid}/incidents/{incidentId}
  → title, status, createdAt, updatedAt, timelineCount, …

users/{uid}/incidents/{incidentId}/evidence/{evidenceId}
  → type, downloadUrl, storagePath, timelineOrder, …
```

### Restart test

1. Note `incidentId` and one `evidenceId`  
2. Force-stop the app  
3. Relaunch → same evidence appears in Capture / Organize / Investigation  
4. Sign out → sign in → same data still present  

### Negative security spot-check (optional)

Using a second test account, confirm Console Rules Playground denies read of `users/{uidA}/...` when auth is uidB.

---

## PART 10 — Documentation — WARNING (updated this sprint)

| Document | Before audit | Action |
|---|---|---|
| `DATA_MODEL.md` | Overstated investigation restore | Updated — Phase 4 gaps explicit |
| `STORAGE_STRUCTURE.md` | Stale “Firestore not updated” | Updated |
| `FIRESTORE_DATA_MODEL.md` | Mixed blueprint vs implemented | Clarified pointer to implemented set |
| `FIREBASE_SETUP.md` | Mostly aligned | OK |
| `BACKEND_ROADMAP.md` | Aligned (Phase 4 deferred) | OK |
| `PLATFORM_ARCHITECTURE.md` | High-level OK | Storage row already cloud-backed |

---

## Remaining risks

1. **Dual capture path** — legacy Create Evidence → `standalone` Storage, not active incident Firestore  
2. **Incomplete investigation persistence** — relationships / narrative / notes lost on restart  
3. **Non-durable upload queue** — offline failures lost if app killed before retry  
4. **Rules soft on delete / no size caps**  
5. **No emulator E2E tests** — serializers/unit only  
6. **Home/Vault still mock** — Library of Truth not cloud-backed  
7. **Schema naming drift** vs Sprint 4C checklist (`userId`, `createdAt` on evidence)

---

## Technical debt

| Item | Priority |
|---|---|
| Retire or wire legacy `EvidencePreviewScreen` / `CreateEvidenceScreen` into `WorkspaceSession` | P0 |
| Persist relationship groups + narrative + reconstruction notes (Phase 4) | P0 for full Investigation durability |
| Add `userId`, `createdAt`, `updatedAt` on evidence docs | P1 |
| Persist upload retry queue to disk + connectivity auto-retry | P1 |
| Firestore/Storage rules hardening + rules tests | P1 |
| Emulator integration tests for persist/restore | P1 |
| Replace Home/Vault mocks with Firestore incident list | P2 |
| Content hash / write-once Storage policy | P2 |

---

## Recommended fixes (before calling backend “production complete”)

1. Disable or redirect legacy Create Evidence into workspace capture  
2. Add evidence `userId` + timestamps in `FirestoreSerializers`  
3. Durable failed-upload queue  
4. Deploy + playground-test security rules  
5. Phase 4: sync relationship / narrative / reconstruction subcollections  
6. Add Firebase Emulator CI tests for upload + restore  

---

## Readiness score breakdown

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Storage pipeline | 15 | 12 | 12 |
| Firestore metadata | 15 | 10 | 10 |
| Restart / auth restore | 15 | 11 | 11 |
| Screen sync | 10 | 7 | 7 |
| Repository boundary | 10 | 10 | 10 |
| Security rules | 10 | 6 | 6 |
| Offline / retry | 10 | 6 | 6 |
| Performance | 5 | 5 | 5 |
| Tests / Console proof | 5 | 2 | 2 |
| Docs accuracy | 5 | 3 | 3 |
| **Total** | **100** | | **72** |

---

## Sprint 5 — Intelligence Layer readiness

| Question | Answer |
|---|---|
| Is Evidence Vault a true cloud-backed app for **evidence**? | **Yes** (workspace path, signed-in) |
| Is the full Investigation graph cloud-backed? | **No** |
| Safe to begin Sprint 5 Intelligence on evidence + health signals? | **Yes — CONDITIONAL** |
| Blockers for Intelligence that needs relationships/narrative history? | Persist those objects first (Phase 4) or keep intelligence scoped to restored evidence |

**Decision: CONDITIONAL GO for Sprint 5**, provided intelligence features consume `CurrentIncident` evidence / health projections and do not assume durable Connect Mode or narrative after restart.

---

*Sprint 4C audit complete. Report based on repository inspection; device Console verification (Part 9) must still be executed by the team for final sign-off.*
