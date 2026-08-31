**Version:** Sprint 4B  
**Status:** Active — Firebase Storage Architecture  
**Last Updated:** August 5, 2026 (Sprint 4B — persistence + thumbnails)

# Evidence Vault Storage Structure

This document defines the **Firebase Storage** layout for Evidence Vault evidence binaries.

Related: [`DATA_MODEL.md`](DATA_MODEL.md) · [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) · [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)

> **Sprint 4A/4B:** Capture binaries upload to Firebase Storage; metadata mirrors into Firestore. Rules: [`storage.rules`](storage.rules).

---

## Design Principles

1. **Ownership first** — every path begins with `users/{userId}/`
2. **Incident isolation** — evidence files live under `incidents/{incidentId}/`
3. **Type-segregated folders** — `photos`, `videos`, `voice`, `attachments`
4. **Never place files at bucket root**
5. **Reference by path** — local evidence objects store `storagePath` + `downloadUrl` after upload

---

## Sprint 4A hierarchy (implemented)

```
gs://{bucket}/
└── users/
    └── {userId}/
        └── incidents/
            └── {incidentId}/
                ├── photos/{evidenceId}.{ext}
                ├── videos/{evidenceId}.{ext}
                ├── voice/{evidenceId}.{ext}
                └── attachments/{evidenceId}.{ext}
```

### Examples

```
users/uid123/incidents/travelIncident/photos/photo001.jpg
users/uid123/incidents/travelIncident/videos/video001.mp4
users/uid123/incidents/travelIncident/voice/voice001.m4a
users/uid123/incidents/travelIncident/attachments/passport.pdf
```

| Capture mode | Folder | Default extension / content type |
|---|---|---|
| Photo | `photos/` | `.jpg` / `image/jpeg` |
| Video | `videos/` | `.mp4` / `video/mp4` |
| Voice | `voice/` | `.m4a` / `audio/mp4` |
| Attachment / File | `attachments/` | from file / `application/octet-stream` |
| Note | — | Text only — **not uploaded** |

---

## Client upload layer

| File | Role |
|---|---|
| `lib/services/storage/evidence_storage_service.dart` | `uploadPhoto` / `uploadVideo` / `uploadVoice` / `uploadAttachment` → `StorageUploadResult` |
| `lib/services/storage/evidence_upload_coordinator.dart` | Progress, metadata, retry orchestration |
| `lib/services/storage/evidence_upload_queue.dart` | Local queue for failed uploads (evidence retained) |
| `lib/services/storage/capture_media_service.dart` | Device capture → local file before upload |
| `lib/services/storage/evidence_upload_feedback.dart` | Non-blocking “Uploading… N%” + “Upload failed. Retry?” |

### `StorageUploadResult`

```
storagePath
downloadUrl
fileSize
contentType
```

After a successful upload these fields (plus `mimeType` / `fileSizeBytes` / `uploadStatus`) are written onto the **local** evidence object, then mirrored to Firestore by `IncidentCloudSyncService` (Sprint 4B).

### Custom object metadata (attached on upload)

| Key | Source |
|---|---|
| `incidentId` | Current incident |
| `userId` | Auth UID |
| `captureTime` | ISO-8601 |
| `deviceModel` | Device info (when available) |
| `latitude` / `longitude` | Location (when available) |
| `contentType` | Detected MIME |
| `evidenceId` | Local evidence id |

---

## Failure behaviour

1. Local evidence + local file are **never discarded** on upload failure  
2. Failed uploads are enqueued in `EvidenceUploadQueue`  
3. UI prompts: **Upload failed. Retry?**  
4. Progress snackbars: **Uploading… 0–100%** (non-blocking)

---

## Security (Sprint 4A)

See [`storage.rules`](storage.rules):

- Authenticated owner only (`request.auth.uid == userId`)
- Writes limited to `photos` / `videos` / `voice` / `attachments`
- Unmatched paths default-deny (no root uploads)

Deploy:

```bash
firebase deploy --only storage --project evidence-vault-dev
```

---

## Deferred (post–Sprint 4A)

| Firestore `evidence.storagePath` documents | ✅ Sprint 4B |
| Thumbnails / compress before upload | ✅ Sprint 4B (`MediaPreprocessService`) |
| Resumable `temp/` staging | Later |
| Nested `…/{evidenceId}/original.{ext}` layout | Deferred — flat `{evidenceId}.{ext}` per product spec |

---

*Sprint 4A/4B — Storage uploads + Firestore metadata write-through live.*
