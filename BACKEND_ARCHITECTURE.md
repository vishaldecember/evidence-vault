**Version:** MVP-0.9.3.1  
**Status:** Active — Backend Architecture Blueprint  
**Last Updated:** August 3, 2026 (MVP-0.9.3.1 — Backend Architecture Foundation)

# Evidence Vault Backend Architecture

This document defines the **production backend architecture** for Evidence Vault. It transforms the platform from a frontend prototype into a scalable, trustworthy investigation platform — **without connecting the UI in this sprint**.

**Founding principle:** A trustworthy investigation platform begins with trustworthy data architecture. Build the foundation before connecting the interface.

Related specifications:

- [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) — collection schemas and relationships
- [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) — Firebase Storage layout
- [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) — identity lifecycle
- [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) — implementation phases
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engine boundaries (frontend/domain)
- [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) — bounded contexts
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map

> **Sprint boundary:** No Firebase integration, Firestore code, Storage uploads, Authentication screens, or UI changes in MVP-0.9.3.1. This increment is architecture only.

---

## Architecture Decision

Evidence Vault uses **Firebase** as the backend platform.

| Service | Role in Evidence Vault | Why this service |
|---|---|---|
| **Firebase Authentication** | User identity — email, Google, Apple (future) | Managed identity with proven OAuth providers; integrates natively with Firestore and Storage security rules via `request.auth.uid`. Anonymous access is **not** supported — every investigation must belong to an accountable user. |
| **Cloud Firestore** | Primary data store for users, incidents, and all investigation objects | Document model fits incident-scoped hierarchies; real-time listeners support future autosave and collaborative editing; offline persistence aligns with calm, interruption-tolerant documentation workflows. |
| **Firebase Storage** | Immutable evidence binaries — photos, video, audio, documents, export artifacts | Object storage with path-based ownership; content-addressable file layout under user/incident boundaries; integrates with Storage security rules mirroring Firestore ownership. |
| **Firebase Security Rules** | Authorization layer — no cross-user access, no public evidence | Declarative, server-enforced access control evaluated on every read/write; rules reference Auth UID and document ownership fields. Rules are designed in this sprint; implemented in a future sprint. |
| **Firebase Cloud Functions** | Future server-side orchestration — deletion cascades, export assembly, integrity jobs | Reserved for operations that must not run on client: account deletion cascades, Trust Package export generation, webhook-style integrations, App Check enforcement at API boundary. **Not implemented in this sprint.** |
| **Firebase App Check** | Device/app attestation — reduce abuse of backend resources | Prepare attestation providers (Play Integrity, App Attest, reCAPTCHA) for when API surfaces expand. Document integration points; **do not fully implement yet.** |

### Why Firebase (summary)

1. **Ownership-aligned security** — Auth UID maps directly to user-scoped data paths and security rules.
2. **Offline-first path** — Firestore local cache supports documentation without constant connectivity.
3. **Operational simplicity** — Managed infrastructure appropriate for MVP → production without operating custom servers initially.
4. **Engine alignment** — Backend modules can mirror platform engine boundaries defined in [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md).
5. **Trust posture** — No public evidence collections; all reads require authenticated, owner-matched identity.

### What Firebase is not responsible for

- **Truth adjudication** — the platform never determines what happened; backend stores investigator documentation.
- **Client-side intelligence** — coaching, health, simulation remain derived on device or via future Functions; not stored as authoritative truth.
- **UI workflow** — backend exposes data; calm documentation UX remains a frontend concern per [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Client (future)                      │
│  Platform Engines · Repositories · Offline Cache · Autosave      │
└────────────────────────────┬────────────────────────────────────┘
                             │ Firebase SDK
┌────────────────────────────▼────────────────────────────────────┐
│                    Firebase Platform Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ Firebase Auth │  │  Firestore   │  │  Firebase Storage    │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ Security Rules│  │ App Check    │  │ Cloud Functions      │ │
│  │ (design only) │  │ (prepare)    │  │ (future-ready)       │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

Backend services **mirror platform engine boundaries** (Capture, Evidence, Relationship, Narrative, Trust Package) at the **persistence and API layer** — not as separate microservices in MVP. See [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md).

---

## Ownership Model

Every object must belong to an accountable identity. Nothing exists without ownership.

```
User (Firebase Auth UID)
└── User Profile (Firestore: users/{userId})
    └── Incident (users/{userId}/incidents/{incidentId})
        └── Investigation Objects
            ├── evidence/{evidenceId}
            ├── participants/{participantId}
            ├── relationshipGroups/{groupId}
            ├── relationships/{relationshipId}
            ├── timelineAnchors/{anchorId}
            ├── narrativeEvents/{eventId}
            ├── reconstructionNotes/{noteId}
            └── trustPackages/{trustPackageId}
```

### Ownership rules

| Rule | Requirement |
|---|---|
| **User root** | Every Firestore path for investigation data includes `{userId}` matching `request.auth.uid` |
| **Incident scope** | Every investigation object includes `incidentId` and lives under that incident's subcollection |
| **No orphans** | Documents without valid `userId` + `incidentId` must not be writable |
| **No cross-user reads** | Users read and write only their own `users/{userId}/...` tree |
| **No public data** | No world-readable collections; no unauthenticated Storage paths |
| **Storage parity** | Every Storage object path includes `users/{userId}/incidents/{incidentId}/...` |

### Future collaboration (reserved)

Multi-user incident access is **not** in MVP. Architecture reserves an optional `members` map on incident documents for future authorised collaborators without changing the user-root ownership model. Until collaboration ships, `ownerId == request.auth.uid` is the only access path.

---

## Repository Folder Structure (proposed)

Backend documentation and future implementation code should live in a dedicated area — **not mixed with Flutter UI** until integration sprints.

```
evidence_vault/
├── BACKEND_ARCHITECTURE.md          ← this document
├── FIRESTORE_DATA_MODEL.md
├── STORAGE_STRUCTURE.md
├── AUTHENTICATION_FLOW.md
├── BACKEND_ROADMAP.md
│
├── backend/                         ← future implementation root (empty in MVP-0.9.3.1)
│   ├── README.md                    ← pointer to architecture docs
│   ├── firestore/
│   │   ├── rules/                   ← security rules (future sprint)
│   │   ├── indexes/                 ← composite indexes (future sprint)
│   │   └── schemas/                 ← JSON schema / validation references
│   ├── storage/
│   │   └── rules/                   ← storage rules (future sprint)
│   ├── functions/                   ← Cloud Functions (future sprint)
│   │   └── src/
│   │       ├── account/             ← deletion cascades
│   │       ├── trust-package/       ← export assembly
│   │       └── integrity/           ← verification jobs
│   └── app-check/                   ← App Check config notes
│
└── lib/                             ← Flutter client (unchanged this sprint)
    └── ...
```

No `backend/` implementation files are created in MVP-0.9.3.1. The structure above is the **target layout** for subsequent sprints.

---

## Sync Strategy (design only)

See [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) for implementation phasing.

| Principle | Design |
|---|---|
| **Offline-first ready** | Firestore persistence enabled on client; reads/writes queue when offline |
| **Firestore cache** | Local cache is source for UI responsiveness; server is source of truth when online |
| **Autosave** | Document-level writes on meaningful user actions — not per-keystroke for long text fields; debounced narrative edits |
| **Conflict philosophy** | **Last-write-wins per field** for enrichment metadata; **immutable fields never merge** (capture timestamps, original file hashes, `capturedAt`) |
| **Chronology protection** | Timeline anchor order is append-only at capture; reordering is never synced from client conflict resolution |
| **Evidence immutability** | Captured evidence binaries and core capture metadata are write-once; updates limited to enrichment fields explicitly marked mutable |
| **Projection rebuild** | Trust Package and coaching signals rebuilt from domain state — not synced as authoritative stored conclusions |

No sync implementation in this sprint.

---

## Delete Strategy (design only)

Complete deletion must leave **nothing orphaned**. Account deletion is irreversible and total within the user's data boundary.

```
Delete Account (user-initiated)
    ↓
Firebase Auth: delete user
    ↓
Cloud Function: cascade (future — not optional for production)
    ↓
Firestore: delete users/{userId} profile
    ↓
Firestore: delete all users/{userId}/incidents/** subcollections
    ↓
Storage: delete all users/{userId}/** objects
    ↓
Firestore: delete users/{userId} document
    ↓
Verify: no dangling Storage objects; no incident docs referencing deleted userId
```

### Per-incident deletion (future)

```
Delete Incident
    ↓
Delete all investigation subcollections under incident
    ↓
Delete Storage prefix users/{userId}/incidents/{incidentId}/
    ↓
Delete incident document
```

### Per-evidence deletion (future)

Evidence deletion is **user-initiated and explicit** — never silent. Deleting captured evidence triggers timeline anchor archival rules documented in [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md). Storage objects for that evidence are deleted in the same transaction batch where possible.

---

## Security Philosophy (design only — no rules written)

| Principle | Requirement |
|---|---|
| **Defence in depth** | Client respects ownership; Security Rules enforce it server-side |
| **Default deny** | All paths denied unless explicitly allowed for authenticated owner |
| **No cross-user reads** | Rules match `request.auth.uid` to path `{userId}` |
| **No public evidence** | Storage and Firestore deny unauthenticated access |
| **Immutable capture** | Rules prevent modification of protected capture fields after initial write |
| **App Check (future)** | Attested clients only for write-heavy operations and Functions invocation |

Detailed rule patterns are specified in [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) and [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md). Rule **implementation** is deferred to a future sprint.

---

## Alignment with Platform Engines

| Platform engine | Backend persistence |
|---|---|
| **Capture Engine** | `evidence` (captured), `timelineAnchors`, Storage uploads |
| **Evidence Engine** | `evidence` (supporting), enrichment fields, `reconstructionNotes` |
| **Relationship Engine** | `relationshipGroups`, `relationships` |
| **Narrative Engine** | `narrativeEvents` |
| **Trust Package Engine** | `trustPackages` (export metadata + assembled snapshot references) |
| **Platform Services** | `users` profile, Auth, Storage, Functions |

Frontend repositories (`IncidentAggregate`, `*Repository`) will gain Firebase-backed implementations in future sprints — **without changing domain object shapes** where possible.

---

## Architectural Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Firestore subcollection depth** | Deep paths complicate batch queries across incidents (Library browse) | Maintain `users/{userId}/incidents` with summary fields for list views; collection group indexes only where needed |
| **Large incident documents** | Incidents with thousands of evidence items may hit query limits | Paginate evidence lists; cap batch writes; use cursor-based sync |
| **Storage cost at scale** | Video evidence dominates storage spend | Lifecycle rules for archived incidents; export tier separation; client-side capture compression policy |
| **Deletion cascade reliability** | Partial deletion leaves orphaned Storage files | Mandatory Cloud Function for account deletion; Storage prefix delete; periodic orphan scanner (Functions) |
| **Offline conflict on immutable fields** | Client could queue invalid mutations offline | Repository layer rejects immutable field changes before write; Security Rules enforce server-side |
| **Dual capture paths (frontend)** | Legacy and workspace capture paths complicate first integration | Unify client capture pipeline before backend wiring ([`EVIDENCE_CAPTURE_VALIDATION_REPORT.md`](EVIDENCE_CAPTURE_VALIDATION_REPORT.md)) |
| **Trust Package duplication** | Storing full assembled packages duplicates evidence references | Store export metadata + generation inputs hash; treat Trust Package as projection with optional export snapshot |
| **App Check friction** | Attestation can block legitimate clients if misconfigured | Stage App Check in monitor mode before enforce mode |
| **Google/Apple OAuth policy** | Apple Sign-In required if Google offered on iOS | Document Apple provider before App Store submission |
| **Security Rules complexity** | Collaboration feature increases rule surface | Keep MVP rules owner-only; design `members` map extension without implementing yet |

---

## Document Hierarchy

| Topic | Authoritative document |
|---|---|
| Backend architecture (this overview) | **This document** — `BACKEND_ARCHITECTURE.md` |
| Firestore collections and fields | [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) |
| Storage paths and file conventions | [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) |
| Authentication lifecycle | [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) |
| Backend implementation phases | [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) |
| Domain bounded contexts | [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) |
| Platform engines | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) |

---

*MVP-0.9.3.1 — Backend Architecture Foundation. Architecture only — no Firebase integration.*
