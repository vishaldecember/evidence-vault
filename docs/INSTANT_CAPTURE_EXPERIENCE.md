# Instant Capture Experience

**Sprint:** 6B  
**Status:** Active  
**Date:** August 8, 2026  
**Related:** [`EVIDENCE_STATE_MODEL.md`](EVIDENCE_STATE_MODEL.md), [`EVIDENCE_LIFECYCLE_AUDIT.md`](EVIDENCE_LIFECYCLE_AUDIT.md), [`CAPTURE_ENGINE.md`](../CAPTURE_ENGINE.md)

---

## Product principle

The investigator must never feel interrupted after capturing evidence.

```
Capture → Confirm → Continue
```

Not:

```
Capture → Wait → Process → Navigate away
```

---

## Capture flow

### Camera session persistence

1. User opens Camera from Workspace / Capture Now.  
2. Live preview stays the dominant surface.  
3. Shutter captures a provisional still.  
4. Confirmation overlay appears **on top** of the still-live camera.  
5. Accept or Delete closes the overlay only.  
6. Camera remains ready for the next shot.  

Session exits **only** when:

- Top **Done / X** is pressed (return to Workspace), or  
- Permission / camera init fails.

### Photo confirmation overlay

| Rule | Behaviour |
|---|---|
| Size | ~80% of available height |
| Style | Rounded premium card over dimmed camera |
| Actions | **Delete** (left, red bin) · **Accept** (right, check) |
| Removed | Top-right close, Cancel, Exit-from-overlay |
| Accept | Optimistic close → local preserve → background sync |
| Delete | Discard provisional file → camera active |

### Video

| Control | Role |
|---|---|
| Left | Delete / trash (active while recording) |
| Center | **Record** when idle · **Stop** when recording |
| Right | **Pause** ↔ **Play** (resume) |

After Stop → preview overlay (Delete / Accept only).  
Accept or Delete returns to Video Mode (ready for another clip).

### Voice (WhatsApp-inspired)

**Recording controls** (bottom):

- Live waveform + timer  
- Pause / Resume (recording)  
- Stop → finalize file  
- Discard cancels in-progress recording  

**Preview controls** (compact bottom panel — not a full-screen overlay):

- Play / Pause **preview** (separate from recording pause)  
- Waveform timeline + duration  
- Delete · Accept  

Recording pause ≠ preview play. They are intentionally separate.

---

## State transitions (Sprint 6A lifecycle)

On Accept:

```
LOCAL_CAPTURED  (local EvidenceRecord exists; Workspace can show it)
     →
QUEUED_FOR_UPLOAD  (CaptureEngine pipeline / attach media)
     →
UPLOADING → SYNCED → PROCESSING → READY   (background only)
```

UI **never waits** for:

- Firebase Storage  
- Firestore  
- Thumbnail generation  
- AI / enrichment  

Quiet sync badges may update later; capture remains interactive.

---

## UX decisions

1. **Optimistic confirm** — overlay closes before await returns so the next shutter is immediate.  
2. **No blocking dialogs** — voice no longer uses `AlertDialog`.  
3. **No accidental exit** — confirmation UI cannot close the capture session.  
4. **One incident per Capture Now session** — all accepted items share the session `incidentId`.  
5. **Premium dark-navy identity** — overlays and voice panel match Evidence Vault chrome.

---

## Camera lifecycle behaviour

```
init camera
  → ACTIVE (preview)
  → shutter → PREVIEW overlay (camera still initialized underneath)
  → accept | delete → ACTIVE
  → …repeat…
  → Done/X → dispose camera → Workspace
```

Video / voice follow the same “mode stays alive” rule with their own phase machines:

- Video: `ready ↔ recording ↔ paused → preview → ready`  
- Voice: `ready ↔ recording ↔ paused → preview panel → ready`

---

## Key files

| File | Role |
|---|---|
| `lib/screens/capture/continuous_capture_session.dart` | Instant Capture session |
| `lib/widgets/capture/capture_preview_overlay.dart` | Photo/video confirm overlay |
| `lib/widgets/capture/voice_preview_panel.dart` | Compact voice preview |
| `lib/domain/evidence/evidence_sync_status.dart` | Lifecycle states |
| `lib/services/capture/capture_engine.dart` | Background pipeline |

---

## Non-goals

- Redesigning Home / Vault / Investigation screens  
- Changing navigation architecture  
- Building Dual Queue Sync Manager (separate 6B track / follow-on)  
- Full AI processing workers
