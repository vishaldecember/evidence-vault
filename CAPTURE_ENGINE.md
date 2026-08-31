# Capture Engine

**Status:** Active — Capture Experience 2.1  
**Last Updated:** August 8, 2026

## Principle

**Capture is sacred.** The user model is:

`CAPTURE → PREVIEW OVERLAY → ACCEPT / DISCARD → CAPTURE AGAIN`

The capture mode (camera / video / voice) **stays alive** underneath the
preview. Network, Firebase Storage, Firestore, and media processing operate
**behind** the capture experience. The UI must never wait for uploads.

## Continuous capture UX (2.1)

| Mode | Interaction |
|---|---|
| Photo | Live camera → shutter → preview overlay (~70–80%) → ✓ / 🗑 / ✕ exit |
| Video | Record ↔ Pause/Play → ✓ finish → preview → Accept / Discard |
| Voice | Waveform + Pause/Play → ✓ → preview → Accept / Discard |

Accept adds evidence to the **same** Capture Now incident (local-first), then
returns to active capture mode. Discard never navigates Home.

## Pipeline

```
CAPTURE
  → Provisional local file
  → Preview overlay (mode remains active)
  → Accept → Instant local Evidence object + UI notify
  → Background:
      Durableize → app-documents LocalEvidenceCache
      ThumbnailJob
      FirestoreJob
      UploadJob (Firebase Storage)
      SyncCompletionJob (mark SYNCED + reclaim upload copy)
      FirestoreJob
      AiPreparationJob (reserved, no-op)
```

## Capture Now vs Pending

| Action | Incident |
|---|---|
| Home → **Capture Now** | **NEW** incident (`beginNewCaptureIncident`) |
| Home → **Pending / Continue** | Existing incident (`openIncident`) |
| Vault → Incident card | Existing incident (`openIncident`) |

`openIncident` resolves a stable `incidentId` and returns whether Workspace is
safe to open (local shell if cloud hydrate is unavailable).

## Local-first sync states (UI)

| State | User-facing |
|---|---|
| pending | Saved |
| uploading / processing | Syncing (tiny quiet dot) |
| uploaded | Synced |
| failed | Saved on device |

Upload **percentages are not shown**.

## Ownership

| Component | Path |
|---|---|
| `CaptureEngine` | `lib/services/capture/capture_engine.dart` |
| Jobs | `lib/services/capture/*_job.dart` |
| LocalEvidenceCache | `lib/services/storage/local_evidence_cache.dart` |
| Upload coordinator | `lib/services/storage/evidence_upload_coordinator.dart` |
| Continuous session | `lib/screens/capture/continuous_capture_session.dart` |
| Preview overlay | `lib/widgets/capture/capture_preview_overlay.dart` |
| Evidence Map readiness | `lib/widgets/home/evidence_map_readiness_sheet.dart` |

## Cache reclamation

Local upload copies are reclaimed **only after**:

1. Firebase Storage upload succeeded  
2. Local evidence marked SYNCED (`uploaded`)  
3. Path is inside `evidence_cache/`

Unsynced / failed evidence is never deleted.

## Compatibility

- Sprint 5B `CollectionEngine` and Sprint 5C `RelationshipEngine` **must not**
  introduce blocking work into Capture.
- Investigation / Memory Recall / Risk Coach consume evidence asynchronously.
- This is a **lightweight pipeline**, not a V2 queue manager.
