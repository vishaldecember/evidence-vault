**Version:** Sprint 4B  
**Status:** Active — Firestore Persistence Implemented  
**Last Updated:** August 5, 2026 (Sprint 4B — Firebase Persistence Layer)

# Evidence Vault Firestore Data Model

This document defines **Cloud Firestore collections**, field schemas, ownership, and relationships for Evidence Vault.

Related: [`DATA_MODEL.md`](DATA_MODEL.md) · [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) · [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) · [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md)

> **Sprint 4B implemented:** Incident + evidence metadata persist under `users/{uid}/incidents/...`.  
> Security rules: [`firestore.rules`](firestore.rules). Client access only via repositories (`FirebaseIncidentRepository`, `FirebaseEvidenceRepository`, `IncidentCloudSyncService`).  
> See [`DATA_MODEL.md`](DATA_MODEL.md) for the **implemented** field set. Sections below retain the fuller blueprint; fields marked *aspirational* are not yet written by serializers.

---

## Design Principles

1. **User root ownership** — all investigation data lives under `users/{userId}/...`
2. **Incident scope** — every investigation object belongs to exactly one incident
3. **No orphans** — `userId` and `incidentId` on every investigation document
4. **Immutable capture** — protected fields on captured evidence are write-once
5. **References not duplication** — narrative and trust package documents reference evidence IDs; binaries live in Storage
6. **Derived state not stored** — coaching, health scores, journey stage, confidence are computed client-side or via Functions — not authoritative Firestore fields
7. **Scalable lists** — subcollections over large arrays; paginate evidence queries

---

## Collection Hierarchy

```
users/{userId}
users/{userId}/incidents/{incidentId}
users/{userId}/incidents/{incidentId}/evidence/{evidenceId}
users/{userId}/incidents/{incidentId}/participants/{participantId}
users/{userId}/incidents/{incidentId}/relationshipGroups/{groupId}
users/{userId}/incidents/{incidentId}/relationships/{relationshipId}
users/{userId}/incidents/{incidentId}/timelineAnchors/{anchorId}
users/{userId}/incidents/{incidentId}/narrativeEvents/{eventId}
users/{userId}/incidents/{incidentId}/reconstructionNotes/{noteId}
users/{userId}/incidents/{incidentId}/trustPackages/{trustPackageId}
```

---

## users

**Path:** `users/{userId}`  
**Ownership:** Document ID `{userId}` **must equal** Firebase Auth UID.

### Purpose

User profile and account metadata. Not an investigation container — incidents are subcollections.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `email` | string | yes | From Auth provider; normalized lowercase |
| `displayName` | string | no | User-facing name |
| `photoUrl` | string | no | Avatar URL (Storage or provider) |
| `authProviders` | array\<string\> | yes | e.g. `["password", "google.com"]` |
| `createdAt` | timestamp | yes | Account creation |
| `updatedAt` | timestamp | yes | Last profile change |
| `lastActiveAt` | timestamp | no | Client heartbeat — optional |
| `preferences` | map | no | Notification, privacy prefs (future) |
| `accountStatus` | string | yes | `active` · `deletion_pending` · `deleted` |

### Relationships

- **Owns** → `users/{userId}/incidents/*` (all investigation data)
- **Linked to** → Firebase Auth user record (1:1)

### Scalability

- One document per user — no hot-spot risk
- Account deletion removes this document after cascade (see [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md))

### Security intent (not implemented)

- Read/write: `request.auth.uid == userId`
- No read access for other users

---

## incidents

**Path:** `users/{userId}/incidents/{incidentId}`  
**Ownership:** Parent path `{userId}`; document includes redundant `ownerId` for rule clarity and future indexing.

### Purpose

Aggregate root for one truth record — one reconstruction of what happened.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | Same as `{userId}` |
| `title` | string | yes | Progressive name; default until user names incident |
| `status` | string | yes | `draft` · `active` · `paused` · `finalized` · `archived` |
| `manuallyComplete` | boolean | yes | User-declared completion flag |
| `createdAt` | timestamp | yes | First capture bootstrap time |
| `updatedAt` | timestamp | yes | Any mutation under incident |
| `firstCapturedAt` | timestamp | no | Denormalized from first evidence — list sorting |
| `evidenceCount` | number | no | Denormalized counter — maintained by Functions or client batch |
| `members` | map | no | **Future collaboration** — `{ uid: role }`; empty/absent in MVP |

### Relationships

- **Parent** → `users/{userId}`
- **Children** → all investigation subcollections
- **Aligns with** → [`Incident`](lib/domain/incident/incident.dart) domain object

### Business rules (persistence)

- Created when first evidence is captured — not as empty container
- Never automatically merged with another incident
- Journey Stage is **not stored** — derived from evidence maturity client-side

### Scalability

- Library of Truth = query `users/{userId}/incidents` ordered by `updatedAt desc`
- Pagination via `startAfter` cursor
- Denormalized counts avoid collection count queries on every list render

---

## evidence

**Path:** `users/{userId}/incidents/{incidentId}/evidence/{evidenceId}`  
**Ownership:** `{userId}` + `{incidentId}` on document.

Unified collection for **captured** and **supporting** evidence — discriminated by `kind`.

### Purpose

All preserved artifacts: photos, video, voice, files, witness records, notes, attachments, context.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | Redundant owner for rules |
| `incidentId` | string | yes | Redundant incident scope |
| `kind` | string | yes | `captured` · `supporting` |
| `type` | string | yes | `photo` · `video` · `voice` · `file` · `witness` · `note` · `attachment` · `document` · `context` |
| `title` | string | yes | Display title |
| `capturedAt` | timestamp | yes | **Immutable** for captured; createdAt for supporting |
| `timelineAnchorId` | string | conditional | Required when `kind == captured` |
| `parentCapturedEvidenceIds` | array\<string\> | no | Supporting evidence links |
| `participantId` | string | no | Optional related person ([Sprint 2.2](lib/domain/participant/participant.dart)) |
| `integrityVerified` | boolean | yes | Verification dimension |
| `verification` | map | yes | `{ completeness, authenticity, ... }` — mirrors frontend model |
| `notePreview` | string | no | Short text preview for notes |
| `storagePath` | string | conditional | Firebase Storage path when binary exists |
| `thumbnailStoragePath` | string | no | Thumbnail in Storage |
| `contentHash` | string | no | SHA-256 for integrity — **immutable after capture** |
| `fileName` | string | no | Original filename |
| `mimeType` | string | no | MIME type |
| `byteSize` | number | no | File size bytes |
| `durationMs` | number | no | Audio/video duration |
| `captureMetadata` | map | no | Device, location (if permitted), resolution |
| `createdAt` | timestamp | yes | Document creation |
| `updatedAt` | timestamp | yes | Enrichment updates only |

### Immutable fields (after initial capture write)

`kind`, `type`, `capturedAt`, `timelineAnchorId`, `contentHash`, `storagePath` (for captured evidence)

### Relationships

- **Belongs to** → incident
- **References** → `participants/{participantId}` (optional)
- **Referenced by** → `timelineAnchors`, `relationshipGroups.memberEvidenceIds`, `narrativeEvents`, `trustPackages`
- **Binary content** → [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md)

### Scalability

- Paginate: `orderBy(capturedAt).limit(50)`
- Filter by `kind` or `type` using composite indexes
- Large incidents: avoid loading all evidence in one snapshot

---

## participants

**Path:** `users/{userId}/incidents/{incidentId}/participants/{participantId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

People involved in the investigation — related to evidence, not evidence themselves.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `displayName` | string | yes | |
| `role` | string | yes | `witness` · `subject` · `friend` · `colleague` · `family` · `other` · … |
| `contactInformation` | string | no | |
| `organisation` | string | no | |
| `notes` | string | no | Internal notes — not shown on evidence cards |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

### Relationships

- **Referenced by** → `evidence.participantId`
- **Graph node** → investigation engine internal graph (not stored separately in MVP)

### Scalability

- Typically small cardinality per incident (< 100)
- Inline creation from Evidence Inspector — no separate management screen

### Delete rules

- Cannot delete participant while evidence references `participantId` (matches frontend repository behaviour)

---

## relationshipGroups

**Path:** `users/{userId}/incidents/{incidentId}/relationshipGroups/{groupId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

Investigative structures — which evidence belongs together. Persisted domain entities, not UI state.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `memberEvidenceIds` | array\<string\> | yes | Evidence IDs in group |
| `colorIndex` | number | yes | **Immutable** after creation |
| `displayName` | string | no | Optional label |
| `description` | string | no | Optional reasoning |
| `relationshipType` | string | no | Internal classification — not user-facing |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

### Relationships

- **References** → `evidence/{evidenceId}` IDs in `memberEvidenceIds`
- **Referenced by** → `narrativeEvents.relationshipGroupIds`, Trust Package assembly

### Scalability

- `memberEvidenceIds` capped in practice (platform UI requires ≥ 2 members)
- For very large groups, future: subcollection `members/{evidenceId}` — not MVP

---

## relationships

**Path:** `users/{userId}/incidents/{incidentId}/relationships/{relationshipId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

Pairwise or directed links between evidence items — distinct from group membership.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `sourceEvidenceId` | string | yes | |
| `targetEvidenceId` | string | yes | |
| `relationshipType` | string | no | Internal / inferred |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

### Relationships

- **References** → two `evidence` documents
- **Aligns with** → [`EvidenceRelationship`](lib/models/evidence_relationship.dart)

### Scalability

- Query by `sourceEvidenceId` or `targetEvidenceId` with composite indexes
- Avoid storing adjacency matrix on incident document

---

## timelineAnchors

**Path:** `users/{userId}/incidents/{incidentId}/timelineAnchors/{anchorId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

Canonical capture chronology — one anchor per captured evidence item.

> **Note:** Sprint spec listed core collections; timeline anchors are required for platform chronology integrity and are included as first-class documents.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `capturedEvidenceId` | string | yes | 1:1 with captured evidence |
| `anchoredAt` | timestamp | yes | **Immutable** — capture time |
| `sequenceOrder` | number | yes | **Immutable** — append order |
| `createdAt` | timestamp | yes | |

### Relationships

- **1:1** → captured `evidence` document
- **Referenced by** → `narrativeEvents.timelineAnchorEvidenceId`

### Business rules

- Created at capture — never reordered by sync conflict resolution
- Supporting evidence does not create timeline anchors

---

## narrativeEvents

**Path:** `users/{userId}/incidents/{incidentId}/narrativeEvents/{eventId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

Investigator-authored reconstruction sections — traceable to evidence.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `title` | string | yes | |
| `summary` | string | no | Max ~500 chars |
| `sortOrder` | number | yes | Narrative sequence — independent of timeline |
| `timelineAnchorEvidenceId` | string | no | Primary anchor reference |
| `relationshipGroupIds` | array\<string\> | no | Traceability |
| `supportingEvidenceIds` | array\<string\> | no | Traceability |
| `reconstructionNoteIds` | array\<string\> | no | Traceability |
| `titleCustomized` | boolean | yes | Protect on reference refresh |
| `summaryCustomized` | boolean | yes | Protect on reference refresh |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

### Relationships

- **References** → evidence, relationshipGroups, reconstructionNotes
- **Does not duplicate** → evidence payloads

### Scalability

- Ordered query: `orderBy(sortOrder)`
- Reference arrays refreshed by client engine — not by stored AI conclusions

---

## trustPackages

**Path:** `users/{userId}/incidents/{incidentId}/trustPackages/{trustPackageId}`  
**Ownership:** `{userId}` + `{incidentId}`.

### Purpose

Export metadata and optional assembled snapshot for sharing. Trust Package is primarily a **projection** assembled from incident state — persisted documents represent **generated exports**, not live editing surfaces.

### Primary fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `ownerId` | string | yes | |
| `incidentId` | string | yes | |
| `status` | string | yes | `draft` · `generated` · `exported` |
| `generatedAt` | timestamp | no | Last assembly time |
| `exportFormat` | string | no | `pdf` · `archive` · `share_link` |
| `exportStoragePath` | string | no | Generated file in Storage |
| `sourceSnapshotHash` | string | no | Hash of inputs used for assembly — integrity |
| `assemblyMetadata` | map | no | Section coverage, integrity aggregates (derived) |
| `sections` | map | no | Lightweight section manifest — references only |
| `createdAt` | timestamp | yes | |
| `updatedAt` | timestamp | yes | |

### Sections manifest (references only)

```json
{
  "incidentSummary": { "included": true },
  "timeline": { "anchorCount": 12 },
  "relationshipGroups": { "groupIds": ["..."] },
  "reconstruction": { "eventIds": ["..."] },
  "evidenceAppendix": { "evidenceIds": ["..."] },
  "integritySummary": { "verificationScore": 0.85 }
}
```

### Relationships

- **Assembled from** → incident subcollections (read-time or Function-time)
- **Export file** → Storage `trustPackages/` prefix

### Scalability

- Multiple exports per incident allowed (history of shares)
- Large exports generated by Cloud Functions — not client-written Firestore blobs

---

## reconstructionNotes (supporting collection)

**Path:** `users/{userId}/incidents/{incidentId}/reconstructionNotes/{noteId}`  

Personal reflections and reconstruction notes — referenced by narrative events.

| Field | Type | Notes |
|---|---|---|
| `title` | string | optional |
| `body` | string | required |
| `createdAt` / `updatedAt` | timestamp | |

Included for domain completeness; aligns with [`ReflectionModel`](lib/models/reflection_model.dart) / reconstruction repository.

---

## Index Strategy (future)

| Query | Composite index |
|---|---|
| User's incidents by recency | `incidents`: `updatedAt desc` |
| Evidence by capture time | `evidence`: `kind asc`, `capturedAt asc` |
| Narrative by sort order | `narrativeEvents`: `sortOrder asc` |
| Relationships by source | `relationships`: `sourceEvidenceId asc` |

Collection group queries are **avoided in MVP** to keep security rules owner-scoped and simple.

---

## Security Rule Intent (design only)

```
// Pseudocode — NOT production rules
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null
                     && request.auth.uid == userId;
}
```

Additional field-level validation for immutable capture fields will be enforced in a dedicated Security Rules sprint.

---

*MVP-0.9.3.1 — Firestore data model blueprint. No implementation.*
