**Version:** Sprint 4D  
**Status:** Active — Production Hardening Complete  
**Last Updated:** August 5, 2026

# Evidence Vault Data Model (Sprint 4D)

Canonical persistence model. Related: [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) · [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md)

---

## Storage hierarchy (canonical)

```
users/{uid}/incidents/{incidentId}/
  photos/{evidenceId}.{ext}
  videos/{evidenceId}.{ext}
  voice/{evidenceId}.{ext}
  attachments/{evidenceId}.{ext}
  thumbnails/{evidenceId}.jpg
```

No `standalone/` path. No alternate folder conventions.

---

## Firestore schema

```
users/{uid}
  activeIncidentId, updatedAt

users/{uid}/incidents/{incidentId}
  incidentId, ownerId, title, status, manuallyComplete
  createdAt, updatedAt
  timelineCount, relationshipCount, narrativeCount
  reconstructionHealth, evidenceCount, activeIncident

users/{uid}/incidents/{incidentId}/evidence/{evidenceId}
  userId, incidentId, evidenceId, kind, type
  storagePath, downloadUrl, thumbnailUrl, filename
  fileSize, fileSizeBytes, mimeType
  context, captureTimestamp, createdAt, updatedAt
  timelineOrder, parentEvidenceId, supportingEvidenceIds
  device, location {latitude, longitude}
  uploadStatus, syncStatus, title, participantId, …

users/{uid}/incidents/{incidentId}/timelineAnchors/{id}
users/{uid}/incidents/{incidentId}/relationshipGroups/{id}
users/{uid}/incidents/{incidentId}/relationships/{id}
users/{uid}/incidents/{incidentId}/narrativeEvents/{id}
users/{uid}/incidents/{incidentId}/reconstructionNotes/{id}
```

Incomplete evidence writes are rejected (`validateEvidenceMap`).

---

## Repositories

| Repository | Responsibility |
|---|---|
| Domain in-memory repos | Working set inside `IncidentAggregate` |
| `FirebaseIncidentRepository` | Incidents + library summaries + active id |
| `FirebaseEvidenceRepository` | Evidence metadata CRUD + delete |
| `FirebaseInvestigationRepository` | Anchors, groups, relationships, narrative, notes |
| `StorageRepository` | Binary upload / thumbnail / delete |
| `IncidentCloudSyncService` | Persist + restore + delete cascade |
| `IncidentLibraryService` | Home / Vault incident lists |
| `DurableUploadQueue` | Offline upload retry persistence |

UI / widgets never import Firebase SDKs. Controllers call sync/library services only.

---

## Offline upload queue

1. Capture creates local evidence + file  
2. Upload attempt fails → enqueue durable JSON (`SharedPreferences`)  
3. `connectivity_plus` detects network → automatic `retryAll()`  
4. Success → `uploadStatus=uploaded`, `syncStatus=synchronized`  

---

## Restore flow

1. Auth restores session  
2. `WorkspaceSession.restoreForSignedInUser`  
3. Load active incident + evidence + full investigation graph  
4. Home / Vault refresh from `IncidentLibraryService`  

---

## Security

See [`firestore.rules`](firestore.rules) and [`storage.rules`](storage.rules):
- Owner-only read/write/delete  
- Immutable `createdAt`, `ownerId`/`userId`, `evidenceId`  
- Storage: create-only (no overwrite), size + MIME caps, `thumbnails/` allowed  

---

*Sprint 4D — backend production hardening.*
