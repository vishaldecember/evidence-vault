# Evidence State Model

**Sprint:** 6A Task 2  
**Status:** Active — architecture preparation for 6B  
**Date:** August 8, 2026  
**Related:** [`EVIDENCE_LIFECYCLE_AUDIT.md`](EVIDENCE_LIFECYCLE_AUDIT.md), [`CAPTURE_ENGINE.md`](../CAPTURE_ENGINE.md)

---

## Purpose

Introduce a **canonical evidence lifecycle state machine** so:

1. Workspace can show evidence immediately after local capture.  
2. UI never invents sync status from raw Firebase callbacks.  
3. Sprint 6B Dual Queue Sync Manager has a stable domain contract.  
4. Existing CaptureEngine / Firebase Storage / Firestore paths keep working.

---

## Lifecycle states (`EvidenceSyncStatus`)

| State | Meaning | User-visible |
|---|---|---|
| `localCaptured` | Exists only on device (RAM + optional media cache) | Saved |
| `queuedForUpload` | Waiting for Firebase sync | Saved |
| `uploading` | Storage upload in flight | Syncing |
| `synced` | File + metadata in cloud | Synced |
| `processing` | AI / enrichment / transcripts / relationships | Processing |
| `ready` | Fully available for investigation | Ready |
| `failed` | Upload or processing failed; retryable | Saved on device |

### Wire compatibility

Firestore may still store Sprint 4D tokens:

| Legacy | Canonical |
|---|---|
| `localOnly` | `localCaptured` |
| `pendingSync` | `queuedForUpload` |
| `syncing` | `uploading` |
| `synchronized` | `synced` |
| `syncFailed` | `failed` |

Always decode with `EvidenceSyncStatus.fromWire` and encode with `wireName`.

---

## State transitions

```
LOCAL_CAPTURED
    → QUEUED_FOR_UPLOAD
    → FAILED

QUEUED_FOR_UPLOAD
    → UPLOADING
    → FAILED
    → LOCAL_CAPTURED   (dequeue / cancel)

UPLOADING
    → SYNCED
    → FAILED
    → QUEUED_FOR_UPLOAD  (re-queue)

SYNCED
    → PROCESSING
    → READY              (skip AI when pipeline reserved)

PROCESSING
    → READY
    → FAILED
    → SYNCED

READY
    → PROCESSING         (re-enrich)

FAILED
    → QUEUED_FOR_UPLOAD
    → UPLOADING
    → LOCAL_CAPTURED
```

Illegal transitions are rejected by `EvidenceLifecycle.canTransition` unless
`updateLifecycleStatus(..., force: true)` is used for recovery / completion paths.

Validation lives in `lib/domain/evidence/evidence_lifecycle.dart`.

---

## Domain record (`EvidenceRecord`)

Unified projection over captured + supporting evidence:

| Field | Notes |
|---|---|
| `evidenceId` | Stable id |
| `incidentId` | Parent incident |
| `evidenceType` | `EvidenceRecordType` |
| `localPath` | Device media (`filePath`) |
| `cloudPath` | Storage path (`storagePath`) |
| `thumbnailPath` | Local or remote thumb |
| `createdAt` / `capturedAt` | Timestamps |
| `syncStatus` | Lifecycle enum |
| `uploadProgress` | 0.0–1.0 domain-owned |
| `retryCount` | Incremented on failure |
| `hash` | Content integrity (6B) |
| `metadata` | Extensible string map |

`CapturedEvidence` / `SupportingEvidence` remain the investigation aggregate entities and now carry the same lifecycle fields (`syncStatus`, `uploadProgress`, `retryCount`, `contentHash`, `metadata`) plus aliases `localPath` / `cloudPath`.

---

## Architecture decisions

### 1. Domain status ≠ Firebase progress

- **`EvidenceSyncStatus`** — domain lifecycle (this document).  
- **`EvidenceUploadStatus`** — Storage coordinator progress (`pending` / `uploading` / …).  
- Bridge: `EvidenceStatusBridge` maps between them for legacy UI badges.

Widgets must read lifecycle via repository / `EvidenceLifecycleService`, not by interpreting Storage SDK events.

### 2. Extend repository — do not replace Firebase

`EvidenceRepository` gained:

- `evidenceRecords` / `recordById`
- `updateLifecycleStatus`

Implemented by `InMemoryEvidenceRepository`. Firestore persist/restore continues through `IncidentCloudSyncService` + serializers (wire-compatible).

### 3. CaptureEngine owns transitions on the critical path

| Moment | Status |
|---|---|
| Local object created | `localCaptured` |
| Media attached / pipeline start | `queuedForUpload` |
| `UploadJob` start | `uploading` |
| Upload success | `synced` |
| `SyncCompletionJob` applied | `ready` (via `applyStorageUpload`) |
| `AiPreparationJob` | `processing` → `ready` (placeholder until AI workers) |
| Upload failure | `failed` |

### 4. Future dual queue (6B)

Lifecycle states map cleanly onto:

- **Metadata queue** — moves `localCaptured` → cloud metadata durable → supports `synced`/`ready`  
- **Media queue** — drives `queuedForUpload` → `uploading` → `synced`  
- **Workers** — multiple upload / AI workers update status through `EvidenceLifecycleService` / repository only

### 5. No UI redesign in this task

Quiet sync labels and journey thumbnails continue to use `EvidenceUploadStatus` bridged from domain. No Capture / Workspace visual redesign.

---

## Key files

| File | Role |
|---|---|
| `lib/domain/evidence/evidence_sync_status.dart` | Canonical lifecycle enum |
| `lib/domain/evidence/evidence_lifecycle.dart` | Transition rules |
| `lib/domain/evidence/evidence_record.dart` | Unified record |
| `lib/domain/evidence/evidence_record_type.dart` | Unified type |
| `lib/domain/evidence/evidence_record_mapper.dart` | Projection |
| `lib/domain/evidence/captured_evidence.dart` | Extended fields |
| `lib/domain/evidence/supporting_evidence.dart` | Extended fields |
| `lib/repositories/evidence_repository.dart` | Lifecycle API |
| `lib/repositories/in_memory_evidence_repository.dart` | Implementation |
| `lib/services/evidence/evidence_lifecycle_service.dart` | Observability façade |
| `lib/services/storage/evidence_status_bridge.dart` | Upload ↔ lifecycle |
| `lib/services/storage/evidence_upload_models.dart` | Legacy upload enum + export |
| `lib/services/capture/upload_job.dart` | Sets uploading / synced |
| `lib/services/capture/capture_job.dart` | Host + AiPreparationJob |
| `lib/controllers/workspace_evidence_controller.dart` | Host implementation |
| `lib/repositories/firebase/firestore_serializers.dart` | Wire compat |
| `test/evidence_lifecycle_status_test.dart` | Unit coverage |

---

## Non-goals (this task)

- Local durable metadata cache (6B)  
- Dual queue manager (6B)  
- UI redesign  
- Replacing Firebase  
- Rewriting CaptureEngine job architecture
