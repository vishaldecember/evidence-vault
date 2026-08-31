# Evidence Capture Validation Report — Sprint MVP-0.9.1

**Application:** Evidence Vault  
**Sprint:** MVP-0.9.1 — Complete Evidence Capture  
**Audit date:** August 3, 2026  
**Scope:** End-to-end evidence capture and persistence only — no investigation coaching, participants UI, or new investigation features  
**Method:** Code audit, navigation trace, and workflow verification against acceptance criteria

---

## Executive Summary

Evidence capture is **split across two disconnected implementations**. The **primary user path** (Home quick capture → Incident Workspace) creates **in-memory mock artifacts** instantly with no camera, microphone, file picker, or disk persistence. A **legacy capture pipeline** (Create Evidence → real capture screens → preview → `EvidenceStorageService`) persists files and metadata to device storage but is **orphaned** — not linked from Home — and its saved records **never appear** in the Vault tab or workspace journey.

A real user **cannot document an incident from start to finish** through a single coherent flow today. Journey thumbnails update immediately within an active session, but the **Vault tab is a placeholder**, evidence **cannot be deleted individually**, metadata in the record view is **hardcoded**, and **written notes have no composer** on the primary path.

| Dimension | Status |
|-----------|--------|
| Create (all 5 types) | **Partially Implemented** — mock primary path; real legacy path orphaned |
| Save to Vault | **Partially Implemented** — session RAM + orphaned file storage |
| Reopen | **Partially Implemented** — inspector + record screen; mock previews |
| Edit observation | **Partially Implemented** — add context only; no edit/delete of existing |
| Display metadata | **Partially Implemented** — UI exists; workspace uses placeholders |
| Delete | **Missing** — per-item delete not implemented |
| Vault listing | **Missing** — `VaultScreen` is stub |
| Recovery / retry | **Partially Implemented** — preview save retry message; document import retry only |
| Draft persistence | **Missing** — inspector drafts lost on close |

---

## Architecture Context

### Primary path (what users hit today)

```
HomeScreen._handleCaptureTap
  → AppNavigation.openEvidenceWorkspace(initialCaptureMode)
    → IncidentWorkspaceShell → EvidenceWorkspaceContent
      → WorkspaceEvidenceController.preserveEvidenceAndReturnId(mode)
        → InMemoryEvidenceRepository (mock artifact, no media files)
          → IncidentStore (in-memory only)
```

**Key files:** `home_screen.dart`, `evidence_workspace_content.dart`, `workspace_evidence_controller.dart`, `in_memory_evidence_repository.dart`

### Legacy path (real capture, unreachable from Home)

```
AppNavigation.openCreateEvidence  ← not linked from Home
  → CreateEvidenceScreen → PermissionService
    → PhotoCaptureScreen | VideoCaptureScreen | AudioRecordingScreen | DocumentImportLauncher
      → MetadataService.collect()
      → EvidencePreviewScreen → EvidenceStorageService.save()
        → evidence/ files + evidence_records.json
```

**Key files:** `create_evidence_screen.dart`, `screens/capture/*`, `evidence_preview_screen.dart`, `evidence_storage_service_io.dart`, `metadata_service.dart`

---

## Per-Type Validation Matrix

Legend: **Implemented** · **Partially Implemented** · **Missing**

### Photo

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create successfully | **Partially Implemented** | Primary: instant mock `CapturedEvidence` with icon placeholder (`preserveEvidence`). Legacy: real camera via `PhotoCaptureScreen` + `PhotoCaptureService` — orphaned. |
| Save to the Vault | **Partially Implemented** | Appears in Incident Journey strip immediately (`setState` after capture). Not in Vault tab. Legacy saves to disk but not surfaced in UI. Session lost on app restart. |
| Reopen correctly | **Partially Implemented** | Inspector modal + `EvidenceRecordScreen` open; preview uses kind icon, not `filePath` (`evidence_record_preview.dart`). |
| Edit observation | **Partially Implemented** | Add contextual note via inspector Save → `addContextTextNote`. Cannot edit existing observations. |
| Display metadata | **Partially Implemented** | `EvidenceRecordMetadataSection` renders rows; `EvidenceRecordMetadata.forItem()` uses hardcoded device/location/resolution (`evidence_record_model.dart`). |
| Delete successfully | **Missing** | No `deleteEvidence` in repository or UI. |

### Video

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create successfully | **Partially Implemented** | Same as Photo — mock primary; real `VideoCaptureScreen` in legacy path. |
| Save to the Vault | **Partially Implemented** | Same session/journey behaviour as Photo. |
| Reopen correctly | **Partially Implemented** | Same inspector/record flow; no real video playback from stored path in workspace path. |
| Edit observation | **Partially Implemented** | Add context only. |
| Display metadata | **Partially Implemented** | Placeholder duration/resolution for video kinds in `forItem()`. |
| Delete successfully | **Missing** | — |

### Audio Recording (Voice)

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create successfully | **Partially Implemented** | Primary: mock captured voice with default `notePreview` text (`in_memory_evidence_repository.dart`). Legacy: `AudioRecordingScreen` + `AudioCaptureService` (record/pause/resume). |
| Save to the Vault | **Partially Implemented** | Journey immediate; no Vault tab; no disk in primary path. |
| Reopen correctly | **Partially Implemented** | Record/inspector UI; no audio playback from workspace evidence. |
| Edit observation | **Partially Implemented** | Voice item gets placeholder text at creation; add context notes supported. |
| Display metadata | **Partially Implemented** | Placeholder duration in metadata factory. |
| Delete successfully | **Missing** | — |

### Document Upload (File / Attachment)

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create successfully | **Partially Implemented** | Primary: mock supporting evidence with hardcoded `incident_report_draft.pdf`. Legacy: `DocumentImportLauncher` + file picker (pdf, doc, images). |
| Save to the Vault | **Partially Implemented** | Journey strip; legacy persists file copy. |
| Reopen correctly | **Partially Implemented** | Filename shown when set; no file viewer. |
| Edit observation | **Partially Implemented** | Add context only. |
| Display metadata | **Partially Implemented** | File size shown only when `fileName != null` (placeholder `248 KB`). |
| Delete successfully | **Missing** | — |

### Written Note

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Create successfully | **Partially Implemented** | Primary: instant mock note with hardcoded default observation — **no text composer** before preserve. Legacy path has no standalone note type in `EvidenceType` enum. |
| Save to the Vault | **Partially Implemented** | Journey only; note text is placeholder unless user adds context afterward. |
| Reopen correctly | **Partially Implemented** | `notePreview` displayed when present. |
| Edit observation | **Partially Implemented** | Add new context notes; cannot edit note body after creation. |
| Display metadata | **Partially Implemented** | Capture timestamp from `lastPreservedAt` only. |
| Delete successfully | **Missing** | — |

---

## Cross-Cutting Requirements

### Metadata

| Field | Status | Notes |
|-------|--------|-------|
| Created timestamp | **Implemented** | `capturedAt` / `createdAt` set to `DateTime.now()` on preserve; shown as "Capture date" in metadata section. |
| Capture timestamp | **Partially Implemented** | Legacy: `MetadataService.collect()` → `EvidenceMetadata.capturedAt`. Workspace: same as created; not distinguished. |
| File type | **Partially Implemented** | Domain `CapturedEvidenceType` / `SupportingEvidenceType`; workspace maps to `WorkspaceEvidenceKind`. MIME not stored on domain models. |
| File size | **Partially Implemented** | Legacy: collected on `PendingEvidence.fileSizeBytes` but **not persisted** in `EvidenceRecord` JSON. Workspace: not stored. |
| Device information | **Partially Implemented** | Legacy: `MetadataService` + `device_info_plus`. Workspace record view: **hardcoded** "Moto G35 5G". |
| Optional location | **Partially Implemented** | Legacy: Geolocator with permission flow in `MetadataService`. Workspace: hardcoded "Pokhara, Nepal" for photo/video. |

### Vault — immediate appearance

| Surface | Status | Notes |
|---------|--------|-------|
| Incident Journey (Capture stage) | **Implemented** | `preserveEvidenceAndReturnId` → `setState` → journey thumbnails refresh without manual reload. |
| Evidence stage / map | **Implemented** | Same controller state; list derived from `controller.state.items`. |
| Vault tab (`VaultScreen`) | **Missing** | Static placeholder: "Your permanent repository… will live here." `EvidenceStorageService.getAll()` unused by UI. |
| App restart | **Missing** | `WorkspaceSession` + `IncidentStore` are in-memory only; no serialization to disk. |

### Recovery

| Scenario | Status | Notes |
|----------|--------|-------|
| Upload/save fails | **Partially Implemented** | `EvidencePreviewScreen`: error snackbar "Unable to save… try again"; user can re-tap Save. No dedicated retry button. No upload queue. |
| Document import fails | **Implemented** | `DocumentImportLauncher` shows error + "Try again" button. |
| Camera/mic capture fails | **Missing** | Photo/video/audio screens fail silently (noted in `TRUST_AUDIT.md` P-4). |
| App closes unexpectedly | **Missing** | Unsaved inspector draft (`_pendingContext`) lost on Close without Save. No draft persistence (SharedPreferences/Hive). `PendingEvidence` lost if killed before preview save. Active incident evidence lost on restart. |

---

## Capability Summary by Evidence Type

| Evidence Type | Overall Status |
|---------------|----------------|
| **Photo** | **Partially Implemented** |
| **Video** | **Partially Implemented** |
| **Audio Recording** | **Partially Implemented** |
| **Document Upload** | **Partially Implemented** |
| **Written Note** | **Partially Implemented** |

**No evidence type is fully Implemented** against all six criteria (create, save, reopen, edit, metadata, delete).

---

## Gap Analysis — Priority for MVP Completion

### P0 — Blocking end-to-end incident documentation

1. **Unify capture paths** — Route Home/Workspace capture through real capture screens + preview, then project into `IncidentStore` with real `filePath` and metadata.
2. **Implement Vault listing** — Replace `VaultScreen` stub; list persisted incidents/evidence (unify `EvidenceStorageService` with workspace or migrate to single store).
3. **Disk persistence for active incident** — Serialize `IncidentStore` so evidence survives app restart.
4. **Note composer** — Text entry before `WorkspaceCaptureMode.note` preserve; user-authored `notePreview`, not placeholder.

### P1 — Required for acceptance criteria completeness

5. **Per-item delete** — Repository method + file cleanup + timeline/relationship cascade; UI on record screen or inspector.
6. **Real metadata projection** — Replace `EvidenceRecordMetadata.forItem()` placeholders with values from capture/domain models.
7. **Media reopen** — Preview/play from `filePath` / `thumbnailPath` in inspector and record screen.
8. **Observation edit policy** — Either implement `updateSupportingTextNote` or document add-only as intentional.

### P2 — Recovery and polish

9. **Inspector draft warning** — Prompt when closing with unsaved observation text; optional local draft cache keyed by `evidenceId`.
10. **Capture error UX** — User-visible errors on camera/mic/picker failure.
11. **Explicit save retry** — Dedicated retry control on preview save failure.
12. **Permissions on workspace path** — Apply `PermissionService` before capture (currently bypassed).

---

## Files Referenced (audit scope)

### Capture entry and orchestration

- `lib/screens/home_screen.dart`
- `lib/widgets/home/quick_capture_button.dart`
- `lib/screens/evidence_workspace_content.dart`
- `lib/controllers/workspace_evidence_controller.dart`
- `lib/controllers/workspace_session.dart`
- `lib/repositories/in_memory_evidence_repository.dart`
- `lib/models/workspace_capture_mode.dart`

### Legacy real capture (orphaned)

- `lib/navigation/app_navigation.dart` (`openCreateEvidence`)
- `lib/screens/create_evidence_screen.dart`
- `lib/screens/capture/photo_capture_screen.dart`
- `lib/screens/capture/video_capture_screen.dart`
- `lib/screens/capture/audio_recording_screen.dart`
- `lib/screens/capture/document_import_screen.dart`
- `lib/screens/evidence_preview_screen.dart`
- `lib/services/photo_capture_service.dart`
- `lib/services/video_capture_service.dart`
- `lib/services/audio_capture_service.dart`
- `lib/services/document_import_service.dart`
- `lib/services/metadata_service.dart`
- `lib/services/evidence_storage_service_io.dart`

### Reopen, observation, metadata

- `lib/widgets/investigation/investigation_evidence_inspector_modal.dart`
- `lib/widgets/investigation/inspector_context_section.dart`
- `lib/screens/evidence_record_screen.dart`
- `lib/models/evidence_record_model.dart`
- `lib/widgets/evidence_record/evidence_record_metadata_section.dart`
- `lib/widgets/evidence_record/evidence_record_preview.dart`

### Vault

- `lib/screens/vault_screen.dart`
- `lib/screens/main_shell_screen.dart`

### Delete (bulk only)

- `lib/services/investigation_data_deletion_service.dart`
- `lib/services/vault_reset_service.dart`

---

## Modified Files (this sprint)

| File | Change |
|------|--------|
| `EVIDENCE_CAPTURE_VALIDATION_REPORT.md` | **Added** — this validation report |

No application code was modified. Investigation functionality was not changed.

---

## Conclusion

Sprint MVP-0.9.1 acceptance criteria are **not met** for a production-ready end-to-end capture workflow. The workspace shell delivers immediate journey feedback and observation **addition**, but capture is mock-only on the primary path, the Vault is unimplemented, metadata is simulated, delete is absent, and persistence does not survive app restart.

The highest-leverage next step is **merging the legacy capture pipeline into the workspace domain** and **implementing Vault listing with disk-backed incident storage** — without expanding investigation features.

---

*Sprint MVP-0.9.1 — Evidence Capture Validation. Read-only audit; no implementation changes.*
