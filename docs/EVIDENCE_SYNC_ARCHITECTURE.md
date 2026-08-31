# Evidence Sync Architecture

**Status:** Active — Sprint 6B Task 3  
**Last Updated:** August 9, 2026  
**Principle:** Capture is local. Sync is background.

## Local-first approach

```
CAPTURE → LOCAL COMMIT → USER CONTINUES IMMEDIATELY → BACKGROUND SYNC
```

The user never waits for Firebase Storage, Firestore, AI, relationships,
transcription, or enrichment. The cloud is a synchronization destination.
`LocalEvidenceCache` remains the immediate source of truth.

```
EvidenceRepository
        ↓
EvidenceSyncManager
     /        \
FAST_SYNC   INTELLIGENCE
Upload workers   Processing workers
        ↓
Firebase Storage + Firestore
```

## EvidenceSyncManager

Single central coordinator — do not create competing sync managers.

Responsibilities:

- Register local captures into FAST_SYNC
- Schedule parallel upload workers
- Schedule intelligence independently
- Restart recovery from local cache
- Retry with exponential backoff
- Duplicate upload protection (`evidenceId` + in-flight set)

## Fast Sync Queue (HIGH)

Handles: photos, videos, voice, attachments, essential metadata, timestamps,
incident association, evidence hash, thumbnail references.

Does **not** run AI, relationships, reconstruction, transcription, or heavy
media analysis.

FIFO within the same priority. Priority model:

| Level | Use |
|---|---|
| HIGH | Fast evidence synchronization |
| NORMAL | Intelligence processing |
| LOW | Reserved (future deferrals) |

## Intelligence Queue (NORMAL)

Independently schedulable. Never blocks FAST_SYNC workers.

Designed for: AI enrichment, transcription, relationships, investigation graph,
quality analysis, reconstruction, pattern detection, metadata enrichment.

Current worker: no-op placeholder after READY.

## Worker pool

Configurable concurrency (default **2**):

```
maxConcurrentUploads = 2  → UploadWorker #1, UploadWorker #2
```

Future tuning (not auto-implemented yet):

| Network | Suggested concurrency |
|---|---|
| WiFi | 3–5 |
| Mobile data | 1–2 |
| Offline | 0 (queue holds; schedule resumes when online) |

Call `EvidenceSyncManager.setMaxConcurrentUploads(n)`.

Rules:

- Two workers never upload the same `evidenceId` (`_inFlightFast`)
- One worker failure does not stop other workers
- Failed items retry independently with backoff

## Lifecycle

```
LOCAL_CAPTURED → QUEUED_FOR_UPLOAD → UPLOADING → SYNCED → PROCESSING → READY
                                                      ↘ FAILED → (backoff) → QUEUED_FOR_UPLOAD
```

Lifecycle updates go through cache + optional workspace callbacks / repository —
UI widgets must not invent Firebase state.

## Retry strategy

Exponential backoff: **2s → 4s → 8s → … capped at 60s**.  
Max attempts: **8**. No tight spin loops. Backoff timer wakes the scheduler.

## Restart recovery

On `EvidenceSyncManager.start()`:

1. Restore durable queue
2. Inspect `LocalEvidenceCache.pendingSync` (`QUEUED`, `UPLOADING`, `FAILED`)
3. Re-queue missing items (`UPLOADING` → `QUEUED_FOR_UPLOAD`)
4. Log `[Sync] recovered evidence=<id> after restart`
5. Schedule workers

## Duplicate protection

- Stable `evidenceId` across local cache, Firestore, Storage
- Deterministic Storage path: `users/{userId}/incidents/{incidentId}/{folder}/{evidenceId}`
- Queue enqueue is idempotent per `evidenceId`
- In-flight set prevents concurrent double-upload
- Skip upload when cache already has `cloudPath` + `downloadUrl` or terminal READY

## Local cache policy

After **SYNCED**, retain local media + thumbnails for playback, offline access,
and resilience. Aggressive reclaim is a **future** concern — Task 3 does not
delete evidence merely because upload succeeded.

## Capture boundary

```
1. Create evidence ID
2. Persist evidence locally (repository)
3. Persist local file (evidence_cache)
4. Persist lifecycle (QUEUED_FOR_UPLOAD)
5. Enqueue FAST_SYNC
6. Return to user immediately
```

`CaptureEngine` runs thumbnail + Firestore metadata schedule only.
Uploads are owned by SyncManager workers.

## Observability

Debug logs (controllable via `enableDebugLogging`):

```
[Sync] queued evidence=<id>
[Sync] worker=1 uploading evidence=<id>
[Sync] synced evidence=<id>
[Sync] failed evidence=<id> retry=<count>
[Sync] recovered evidence=<id> after restart
```

## Workspace integration

```
Workspace → EvidenceRepository → LocalEvidenceCache → EvidenceSyncManager → Firebase
```
