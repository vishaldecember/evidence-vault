# Evidence Recovery Architecture

**Status:** Active — Sprint 6B Task 3.2 + Sprint 6C identity lock  
**Last Updated:** August 10, 2026  
**Principle:** Local persistence is the source of truth for recently captured evidence.  
**Identity principle:** Recovery must preserve the **same `incidentId`** — never replace a rich captured incident with an empty draft.

Related: [`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md) · [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) · [`DOMAIN_MODEL.md`](DOMAIN_MODEL.md)

## Local persistence boundary

Capture success is defined by **local commit**, not Firebase:

```
Create evidence ID
  → Persist in EvidenceRepository (RAM working set)
  → Durableize media / note text into LocalEvidenceCache
  → Persist lifecycle + incidentId + userId
  → Remember incident via LocalIncidentPointer(userId → incidentId)
  → Return control to the user
  → Background SyncManager uploads to Firebase
```

`CaptureEngine.receive` is `async` and **awaits** durableize + cache upsert before
returning. Upload / thumbnail / Firestore jobs continue in the background.

## Workspace reconstruction

```
openIncident(incidentId)
  → Load cloud aggregate when available (enrichment)
  → ALWAYS LocalEvidenceHydrator.hydrateIncident(incidentId)
  → Merge missing rows from LocalEvidenceCache into EvidenceRepository
  → Render chronological journey immediately
  → Start EvidenceSyncManager (background)
```

Same-incident early return **still hydrates** — empty RAM after auth wipe /
picker resume must not leave Workspace blank when cache has evidence.

Workspace never reconstructs from widget state, capture controllers, or
Firebase-only queries.

## Incident identity / recovery invariant

After any of:

- logout / login
- application restart
- crash / relaunch
- offline capture
- cache hydration

evidence must recover under the **SAME `incidentId`**.

| Must | Must not |
|---|---|
| Restore remembered / richest cached incident for the user | Seed an empty post-logout draft as the active incident when rich local evidence exists |
| Hydrate all local evidence rows for that `incidentId` | Replace a rich captured incident with an empty draft incident |
| Keep Capture Now → Cockpit → Workspace on one `incidentId` across relaunch mid-flow when local pointer + cache allow | Silently mint a second incident for the same capture journey |
| Keep Workspace sticky Cockpit captures on the Workspace’s `incidentId` | Treat Cockpit as a new-incident factory during recovery |

`LocalIncidentPointer(userId → incidentId)` (+ title) and `LocalEvidenceCache` rows keyed by `incidentId` are the recovery spine. Cockpit and Workspace are presentation surfaces over that identity — not alternate identity owners.

## Capture-lane presentation (Task 3.2 / 3.3)

Standalone text notes and file attachments are **first-class chronological
evidence**. They receive `EvidenceMaturity.capture` when `parentEvidenceId` is
null so the Evidence Maturity Captured lane renders their thumbnails alongside
photo/video/voice. Parent-linked context enrichment remains in Strengthening.

**Capture method is authoritative for semantic type (Task 3.3):**
- Photo capture → PHOTO tile (image bytes)
- Video capture → VIDEO tile + play overlay (thumbnail when available)
- Voice capture → VOICE audio treatment
- Text note → NOTE icon + snippet
- File capture → FILE/ATTACHMENT tile even when MIME is `image/*`

`LocalIncidentPointer` stores `userId → incidentId` **and title** so logout
recovery restores `"workplace incident"` instead of minting Untitled drafts.

## Incident / evidence relationship

Every cached row stores stable:

- `evidenceId`
- `incidentId`
- `userId`
- `evidenceType`
- `localFilePath` / `thumbnailPath` / `noteText` / `mimeType` / `fileName`
- `capturedAt` / `createdAt`
- `syncStatus` / `uploadProgress` / `retryCount`
- optional `parentEvidenceId` (context enrichment only)

Never key relationships by incident title or screen state.

**Invariant:** Cockpit-captured Photo / Video / Voice rows and Workspace Note / File rows for a journey share the incident’s `incidentId`. Recovery hydrates by that id — not by which screen was last visible.

## Capture types

| Type | Local commit |
|---|---|
| Photo / Video / Voice | Durable media + cache + lifecycle |
| Text Note | Editor sheet → dedicated supporting note (no auto-parent) + `noteText` |
| File | Picker → durable copy + cache + generic attachment thumbnail |

Text notes and file attachments from the capture bar are **standalone**
chronological evidence. They do not silently attach to the latest voice/photo
(that caused false “text on voice” indicators). Explicit inspector context
enrichment still uses parent links.

## Text note lifecycle

1. User taps Note → `TextNoteCaptureSheet`
2. Save → `preserveTextNote(text)` → dedicated evidence
3. Thumbnail: note icon + snippet via `LivingEvidencePreview`
4. Discard → no evidence created, no Home navigation

## File attachment lifecycle

1. User taps File → permissions → platform picker
2. `AuthGate` keeps `MainShellScreen` mounted during restore/picker resume
3. Local copy into `evidence_cache/` + repository row
4. Workspace updates; sync is background

File picker must never reset the incident or navigate Home.

## Authentication boundaries

- `LocalEvidenceCache` survives logout (scoped by `userId`)
- `LocalIncidentPointer` remembers `userId → incidentId` on each capture and
  before sign-out flush
- Sign-out clears RAM working set and restore flags — **never deletes** the
  durable cache
- Re-login must **not** seed an empty post-logout draft as cloud `activeIncident`
- When cloud active is empty, restore opens remembered / richest cached incident
- `LocalEvidenceHydrator` / `forIncident(..., userId:)` exclude foreign
  `userId` rows while still recovering legacy empty-user captures
- Home Pending prefers the in-progress library row with the highest evidence count
- `AuthGate` keeps `MainShellScreen` mounted after first paint through
  auth/plugin resume so file picker cannot bounce Capture → Home
- Recovery logs:
  - `[Recovery] authenticated user=…`
  - `[Recovery] opening incident=…`
  - `[Recovery] local evidence count=…`
  - `[Recovery] hydrated evidence count=…`

## Crash recovery

If the local commit barrier completed, force-kill after capture still leaves
cache rows. Restart → `openIncident` → hydrate → evidence returns offline.

## Chronological order

Journey sequence sorts by capture/created time across primary + supporting
kinds. Do not group notes/files into a separate “type silo” for the evidence
stream.

## Firebase role

Firebase Storage + Firestore remain the **synchronization destination**.
They must never be required for newly captured evidence to reappear in Workspace.
