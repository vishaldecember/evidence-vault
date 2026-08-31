# Evidence Lifecycle Audit

**Role:** CTO architectural review  
**Status:** Audit complete — prepare Sprint 6A  
**Date:** August 8, 2026  
**Scope:** Current Flutter codebase (read-only). No code changes in this document.  
**Sprint target:** 6A — Local-first Evidence Cache + Dual Queue Sync Architecture

---

## Executive summary

Evidence Vault today is **local-first for the capture interaction**, but **cloud-first for session durability**.

| Layer | What survives process death | What survives logout |
|---|---|---|
| In-memory `IncidentAggregate` / `IncidentStore` | No | No — wiped on sign-out |
| `LocalEvidenceCache` media binaries | Yes (app documents) | Yes (orphaned files possible) |
| `DurableUploadQueue` (SharedPreferences) | Yes | Partially (paths remain; no metadata host) |
| Firestore incident + evidence docs | Yes (if persist completed) | Yes (remote) |
| Firebase Storage objects | Yes (if upload completed) | Yes (remote) |

**Root cause of “evidence disappears after logout/login” and many blank Pending Workspaces:**  
there is **no durable local incident/evidence metadata store**. Session state lives in RAM. Logout calls `clearInvestigation()`. Login rehydrates only from Firestore. Anything not successfully written to Firestore (or written under a different incident / user race) is gone from the UI — even if media files still sit under `evidence_cache/`.

Sprint 6A must close that gap without rewriting CaptureEngine, CollectionEngine, or RelationshipEngine.

---

## Lifecycle map (current)

```
CAPTURE UI (ContinuousCaptureSession / Workspace)
        |
        v
preserveEvidenceWithMedia()
        |
        v
CaptureEngine.receive()
        |- createLocalEvidence()  -> InMemoryEvidenceRepository -> IncidentStore (RAM)
        |- attachCaptureThumbnail() -> filePath / thumbnail on CapturedEvidence
        |- scheduleCaptureMetadataPersist() -> debounced Firestore write-through
        |- unawaited _runPipeline()
                |- LocalEvidenceCache.durableize()   <- media only
                |- ThumbnailJob
                |- FirestoreJob  (schedules persist again — does not write itself)
                |- UploadJob -> EvidenceUploadCoordinator -> Firebase Storage
                |- SyncCompletionJob -> apply URLs + reclaimSynced()
                |- FirestoreJob
                |- AiPreparationJob (reserved)
```

```
LOGOUT                          LOGIN
  |                               |
  v                               v
onSignedOut()                   restoreForSignedInUser()
clearInvestigation()            restoreActiveIncident() [Firestore]
resetToEmpty()                    |
  |                               v
  v                             replaceAggregate(cloud)
RAM evidence gone               Workspace shows cloud snapshot
media cache files remain        orphaned cache not re-linked
```

---

## 1. Where photo / video / audio evidence is created

### UI entry points

| Surface | Path | Behavior |
|---|---|---|
| Continuous capture | `lib/screens/capture/continuous_capture_session.dart` | Photo (`camera` / picker fallback), video (pause/resume), voice (waveform). Accept calls `preserveEvidenceWithMedia`. Discard deletes provisional file only. |
| Workspace capture | `lib/screens/evidence_workspace_content.dart` | Opens continuous session or note/file paths; also calls `preserveEvidenceWithMedia`. |
| Home Capture Now | `lib/screens/home_screen.dart` | `beginNewCaptureIncident()` then opens Workspace with initial mode. |

### Media acquisition

| Mode | Service | Notes |
|---|---|---|
| Photo | `camera` `CameraController.takePicture` or `PhotoCaptureService` via `CaptureMediaService` | Provisional path → preview → accept |
| Video | `CameraController` record/pause/resume/stop or `VideoCaptureService` | Single logical clip |
| Voice | `AudioCaptureService` (`record` package) | Amplitude stream for waveform |
| File / note | `DocumentImportService` / text note | Note has no binary payload |

`CapturedMediaFile` (`lib/services/storage/capture_media_service.dart`) carries `localPath`, `fileName`, `fileSizeBytes`, optional `thumbnailPath`.

### Domain object creation

1. `WorkspaceEvidenceController.preserveEvidenceWithMedia`  
   → `CaptureEngine.receive`  
   → `createLocalEvidence` callback  
   → `_captureFromMode`  
   → `InMemoryEvidenceRepository.addCapturedFromCaptureMode` (or supporting path)

2. `CapturedEvidence` is constructed with:
   - new evidence id (`WorkspaceEvidenceFactory.nextEvidenceId`)
   - `incidentId: _store.incident.id`
   - type from capture mode
   - timeline anchor via `TimelineRepository.createAnchor`
   - inserted into `IncidentStore.capturedEvidence`

**Critical:** At creation time, evidence exists **only in RAM** (`IncidentStore`). Media may later be copied into `evidence_cache/`.

---

## 2. Where metadata is stored

### In-memory (authoritative for live Workspace)

| Location | Contents |
|---|---|
| `IncidentStore` | Incident root, captured + supporting lists, anchors, relationships, narrative, reconstructions |
| `CapturedEvidence` / `SupportingEvidence` | Identity, type, timestamps, verification, file/storage paths, upload/sync status, GPS/device, timelineOrder, collectionId, primary flag |
| `WorkspaceEvidenceItem` | Presentation projection (`EvidenceProjection`) |
| `CurrentIncident` | Read model via `CurrentIncidentProjection.fromAggregate` |

### On device (partial)

| Store | What | What is missing |
|---|---|---|
| `LocalEvidenceCache` (`documents/evidence_cache/{incidentId}/{evidenceId}.ext`) | Media binaries (+ thumbs) | **No JSON index of evidence metadata / incident aggregate** |
| `DurableUploadQueue` / SharedPreferences | Retry upload jobs (evidenceId, incidentId, local path, mode) | Not a source of truth for Workspace lists |
| SharedPreferences | Memory Recall / Risk Coach prefs only | Unrelated to evidence inventory |

### Cloud

| Store | Path helper | Contents |
|---|---|---|
| Firestore incident doc | `users/{uid}/incidents/{incidentId}` | Title, status, counters, health |
| Firestore evidence docs | `.../evidence/{evidenceId}` | Serialized captured/supporting metadata (`FirestoreSerializers`) |
| Firestore graph subcollections | timelineAnchors, relationships, relationshipGroups, narrativeEvents, … | Investigation graph |
| Firebase Storage | `users/{uid}/incidents/{incidentId}/{photos\|videos\|voice\|attachments\|thumbnails}/{evidenceId}` | Binaries + custom metadata map |

**Gap for 6A:** Metadata durability is Firestore-or-RAM. There is no local SQLite/Hive/JSON aggregate cache keyed by `incidentId`.

---

## 3. How incidents are created

| Trigger | API | Result |
|---|---|---|
| App start / empty session | `IncidentAggregate.empty()` → `InMemoryIncidentRepository.createDefaultStore` | New `incident-{millis}` draft in RAM |
| Home → Capture Now | `WorkspaceSession.beginNewCaptureIncident()` | Persist prior aggregate (best effort) → `resetToEmpty()` → new draft ID → `enterCapture()` |
| Cloud restore | `IncidentCloudSyncService.restoreActiveIncident` / `restoreIncident` | `IncidentAggregate.fromStore` with Firestore incident id |
| Pending open when cloud missing | `IncidentAggregate.shell(id:, title:)` | Empty local shell with **library’s** stable id (Capture Experience 2.1) |
| Firestore ensure | `FirebaseIncidentRepository.ensureIncident` / `upsertIncident` | Server-side incident document for signed-in user |

**Capture Now vs Pending (product contract):**

- Capture Now → **always new** incident id.  
- Pending / Vault card → **existing** id via `openIncident(incidentId)`.

Incident identity is stable once assigned; the failure mode is losing the **aggregate contents**, not renaming ids mid-session (when local session is intact).

---

## 4. How evidence is linked to incidents

Linkage is **by field**, not by a separate join table locally:

```
CapturedEvidence.incidentId == IncidentStore.incident.id
SupportingEvidence.incidentId == IncidentStore.incident.id
TimelineAnchor.incidentId + capturedEvidenceId
SupportingEvidence.parentEvidenceId → parent CapturedEvidence
EvidenceRelationship.sourceEvidenceId / targetEvidenceId
```

`CaptureEngine.receive` stamps pipeline context with `host.captureIncidentId` (`WorkspaceEvidenceController.captureIncidentId` → `currentIncident.id`).

All accepted captures in one Continuous Capture session share that session incident id — provided the session was not reset by `beginNewCaptureIncident` or `clearInvestigation`.

Firestore paths always nest evidence under `users/{uid}/incidents/{incidentId}/evidence/{evidenceId}`.

---

## 5. How Firebase Storage upload works

```
UploadJob.run
  → EvidenceUploadCoordinator.uploadCapturedMedia
       → require UserSessionService.account.userId
       → MediaPreprocessService.compressForUpload (+ thumbnail for photo)
       → StorageRepository upload to canonical path
       → progress announce (quiet UI — no percent snackbars)
       → on failure: enqueue QueuedEvidenceUpload (DurableUploadQueue)
       → connectivity listener → retryAll when online
  → SyncCompletionJob
       → completeCaptureUpload (URLs onto CapturedEvidence)
       → LocalEvidenceCache.reclaimSynced (delete durable upload copy after SYNCED)
```

**Properties:**

- Upload is **async** relative to capture UI (correct).
- Upload **requires sign-in**; unsigned attempts fail and queue.
- Reclaim deletes binaries from `evidence_cache` after successful sync — correct for space, dangerous if metadata never reached Firestore (file gone + metadata never remote = total loss).
- Coordinator is **not** a full dual-queue (metadata queue vs media queue). Metadata rides a separate debounced `persistAggregate`.

---

## 6. How Firestore records are created

### Write path

1. Any local mutation → `_invalidateDerivedCaches` → `_scheduleCloudPersist` (450 ms debounce).  
2. `IncidentCloudSyncService.persistAggregate`:
   - `upsertIncident` (counters, health)
   - foreach evidence in timeline order → `upsertCaptured` / `upsertSupporting`
   - `persistGraph` (investigation subcollections)
3. `FirestoreJob` in CaptureEngine **does not write Firestore itself** — it only calls `scheduleCaptureMetadataPersist()` again.

### Read path

- `restoreActiveIncident` / `restoreIncident` → load incident doc → `loadEvidence` → load graph → `IncidentAggregate.fromStore`.

### Failure modes

- Persist no-ops when `_enabled` is false (tests, Firebase unavailable, signed out).  
- Debounce can be **cancelled by logout** before flush.  
- `FirestoreJob` naming overstates responsibility — actual writes are centralized in `IncidentCloudSyncService`.

---

## 7. How Workspace retrieves evidence

Workspace **never queries Firestore on paint**.

```
WorkspaceSession.controller (WorkspaceEvidenceController)
  → IncidentAggregate (in RAM)
  → currentIncident = CurrentIncidentProjection.fromAggregate
  → evidence / journeyEvidence lists
WorkspaceBody / journey strip / Evidence Map section bind to these lists
```

Cloud hydrate happens only via:

- `restoreForSignedInUser` (AuthGate after login)
- `openIncident(incidentId)` (Pending / Vault / Library)

Local media paths on items drive thumbnails when present; remote `downloadUrl` / `thumbnailUrl` after sync.

**Implication:** If RAM aggregate is empty or wrong id, Workspace is blank — regardless of files on disk.

---

## 8. How Vault retrieves incidents

```
IncidentLibraryService.refresh()
  → FirebaseIncidentRepository.listIncidentSummaries(userId)
  → LibraryIncidentSummary / LibraryIncidentRecord caches
VaultScreen / Home Library of Truth / Memory Recall consume summaries
Tap → openIncident(id) → resumeWorkspace
```

Vault is **cloud list + local navigation**. It does not maintain a local incident catalog independent of Firestore (except whatever is currently in the signed-in session’s RAM aggregate).

Offline / signed-out: refresh no-ops; cached summaries may be stale or empty depending on last successful refresh.

---

## 9. Why evidence disappears after logout / login

### Logout sequence

`AuthGate` on `!isAuthenticated`:

```
WorkspaceSession.onSignedOut()
  → _restored = false
  → clearInvestigation()
       → controller.resetToEmpty()   // NEW empty incident id
       → reset in-memory repos
```

Effects:

1. **All evidence metadata in RAM is discarded.**  
2. **No flush guarantee** that the last debounce of `persistAggregate` completed.  
3. `LocalEvidenceCache` files are **not** deleted on logout — but nothing re-indexes them.  
4. `DurableUploadQueue` entries may still reference paths under the previous incident id — orphaned relative to the new empty session.

### Login sequence

```
restoreForSignedInUser()
  → IncidentCloudSyncService.restoreActiveIncident()
  → replaceAggregate(cloud)  (with local-richer guards)
```

Only evidence that **successfully reached Firestore** for the active incident returns. Unsynced captures from the previous session never reappear in Workspace.

### Additional loss vectors

| Vector | Effect |
|---|---|
| Persist before sign-in / during auth race | Writes skipped (`userId` null / `_enabled` false) |
| Reclaim after Storage success but Firestore metadata write failed | Binary gone locally; cloud metadata incomplete |
| Capture Now created new id; prior id never upserted | Pending card may show library entry only if an earlier persist wrote something |
| Active incident pointer on user doc ≠ last capture incident | Restore loads “wrong” or empty active incident |

**Verdict:** Disappearance is an **architecture gap** (no durable local metadata), not a random UI bug.

---

## 10. Why pending incidents sometimes open blank

### Historical causes (pre–Capture Experience 2.1)

1. Home Pending showed library `incidentId` A, but session still held draft B → resume without `openIncident(A)`.  
2. `openIncident` returned early while `_restoring` and callers still navigated.  
3. Cloud `restoreIncident` returned null → session unchanged (wrong/empty id) → blank Workspace.  
4. Cloud returned sparser snapshot and overwrote richer local (mitigated by richer-local guards).

### Current mitigations (2.1)

- `openIncident` → `Future<bool>`; Home/Vault navigate only on success.  
- Same-id short circuit keeps local evidence.  
- Cloud miss → `IncidentAggregate.shell(id)` so Workspace opens on **correct id** (may still be empty of evidence).  
- Evidence Map readiness sheet avoids fake map data.

### Remaining blank / empty cases

| Case | User experience |
|---|---|
| Shell open: correct id, zero local + zero cloud evidence | “Empty” Workspace — looks blank |
| Firestore list shows evidenceCount > 0 but loadEvidence fails / rules deny | Shell or empty hydrate |
| Race: restore still running past spin wait | `openIncident` returns false if ids differ — snackbar, no nav (better than wrong blank) |
| Library summary stale vs deleted incident | Shell with title, no evidence |
| Media on disk for id A, metadata never persisted | Shell cannot reconstruct list from cache alone |

**Verdict:** Navigation identity is largely fixed; **empty Workspace with correct id** remains when metadata never made it to a durable store (local or cloud).

---

## Durability matrix (Sprint 6A input)

| Artifact | Create | Local durable today | Cloud durable today | Survives logout |
|---|---|---|---|---|
| Incident metadata | RAM draft / shell | No | Firestore incident doc | Cloud only |
| Evidence metadata | RAM `CapturedEvidence` | No | Firestore evidence doc | Cloud only |
| Media binary | Temp / picker | `LocalEvidenceCache` | Firebase Storage | Files yes; link no |
| Upload retry | Coordinator queue | SharedPreferences | N/A | Paths yes; host no |
| Timeline / relationships | RAM | No | Firestore subcollections | Cloud only |
| Library list | — | In-memory cache of last refresh | Firestore summaries | Cache only until refresh |

---

## Sprint 6A — architectural implications

### What already exists (reuse)

- `CaptureEngine` job pipeline (do not rewrite).  
- `LocalEvidenceCache.durableize` / `reclaimSynced` (media).  
- `EvidenceUploadCoordinator` + `DurableUploadQueue` (media retry).  
- Debounced `persistAggregate` (cloud metadata write-through).  
- Stable `incidentId` / `evidenceId` identity model.  
- Local-richer guards on restore / `openIncident`.

### What is missing (build in 6A)

1. **Local Evidence Metadata Cache**  
   Persist incident aggregate (or evidence index) to disk keyed by `incidentId`, updated on every local capture **before** UI confirmation returns. Survives logout.

2. **Dual queue**  
   - **Media queue** — extend current DurableUploadQueue.  
   - **Metadata queue** — durable pending Firestore upserts independent of RAM session and auth debounce races.

3. **Rehydrate on login**  
   Merge order: local metadata cache ∪ Firestore ∪ media cache index — never wipe richer local with empty cloud; never leave orphaned binaries without attempting relink.

4. **Logout policy**  
   Flush metadata queue / local cache **before** `clearInvestigation`, or stop treating RAM clear as destroying the source of truth.

5. **Reclaim policy**  
   Reclaim media only when **both** Storage upload **and** durable metadata sync (local + remote) are confirmed.

6. **Pending / Vault**  
   Resolve from local metadata cache first; open Workspace immediately; background dual-queue drain.

### Non-goals (preserve)

- Do not replace Firebase.  
- Do not introduce an oversized V2 queue manager if a focused dual-queue meets the need.  
- Do not rewrite CollectionEngine / RelationshipEngine / Investigation.  
- Do not change Capture UX contract from Capture Experience 2.1.

---

## Key files (reference index)

| Concern | Path |
|---|---|
| Capture orchestration | `lib/services/capture/capture_engine.dart` |
| Continuous capture UX | `lib/screens/capture/continuous_capture_session.dart` |
| Preserve API | `lib/controllers/workspace_evidence_controller.dart` |
| In-memory evidence | `lib/repositories/in_memory_evidence_repository.dart` |
| Incident store | `lib/repositories/incident_store.dart` |
| Session / open / logout | `lib/controllers/workspace_session.dart` |
| Auth restore gate | `lib/widgets/auth/auth_gate.dart` |
| Media cache | `lib/services/storage/local_evidence_cache.dart` |
| Upload | `lib/services/storage/evidence_upload_coordinator.dart` |
| Upload queue durability | `lib/services/storage/durable_upload_queue.dart` |
| Cloud persist / restore | `lib/services/persistence/incident_cloud_sync_service.dart` |
| Firestore evidence | `lib/repositories/firebase/firebase_evidence_repository.dart` |
| Paths | `lib/repositories/firebase/firestore_paths.dart` |
| Vault library | `lib/services/persistence/incident_library_service.dart` |
| Domain capture model | `lib/domain/evidence/captured_evidence.dart` |
| Projection | `lib/mappers/current_incident_projection.dart` |
| Capture product doc | `CAPTURE_ENGINE.md` |

---

## CTO conclusion

The capture path correctly prioritizes **instant local evidence + background sync**. The platform fails the **session boundary**: logout destroys the only complete metadata copy that was never guaranteed on disk.

Sprint 6A should treat **local metadata + dual queues** as the missing half of “local-first,” with Firestore/Storage remaining the sync plane — not the sole recovery plane.

**Next step after this audit:** Sprint 6A design/implementation plan (schema for local metadata cache, queue contracts, merge/rehydrate rules, reclaim gates) — still without a broad architecture rewrite.
