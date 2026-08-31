**Version:** Sprint 4D  
**Status:** Active — Backend Implementation Roadmap  
**Last Updated:** August 5, 2026 (Sprint 4D — Production Hardening)

# Evidence Vault Backend Roadmap

Related: [`DATA_MODEL.md`](DATA_MODEL.md) · [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) · [`SPRINT_4D_PRODUCTION_READINESS_REPORT.md`](SPRINT_4D_PRODUCTION_READINESS_REPORT.md)

```
Phase 0   Architecture Foundation                     ✅
Phase 1   Firebase Project + Auth                     ✅
Phase 2   Firestore Core                              ✅ Sprint 4B
Phase 3   Storage + Capture Upload                    ✅ Sprint 4A
Phase 4   Investigation Objects Sync                  ✅ Sprint 4D
Phase 4D  Production Hardening (rules, offline, Home) ✅ Sprint 4D
Phase 5   App Check Enforce + rules unit tests        ← next
Phase 6   Cloud Functions (deletion cascade at scale)
Phase 7   Offline Sync Polish
Phase 8   Apple Sign-In + Production Hardening
```

### Sprint 4D deliverables

| Item | Status |
|---|---|
| Complete evidence metadata + syncStatus | ✅ |
| Persist anchors / groups / relationships / narrative / notes | ✅ |
| Home + Vault from Firestore | ✅ |
| Durable offline upload queue + auto-retry | ✅ |
| Hardened Firestore + Storage rules | ✅ |
| Canonical Storage hierarchy + thumbnails/ | ✅ |
| Legacy Create Evidence redirect | ✅ |
| Delete evidence cascade API | ✅ |

Each phase has explicit **entry criteria**, **deliverables**, and **do-not-build** boundaries.

---

## Phase 0 — Architecture Foundation ✅

**Sprint:** MVP-0.9.3.1

| Deliverable | Status |
|---|---|
| `BACKEND_ARCHITECTURE.md` | ✅ |
| `FIRESTORE_DATA_MODEL.md` | ✅ |
| `STORAGE_STRUCTURE.md` | ✅ |
| `AUTHENTICATION_FLOW.md` | ✅ |
| `BACKEND_ROADMAP.md` | ✅ |

**Do not build:** Firebase SDK, rules files, Functions, UI wiring.

**Exit criteria:** Architecture reviewed; domain model alignment confirmed with [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md).

---

## Phase 1 — Firebase Project + Authentication ✅

**Sprint:** MVP-0.9.3.2

**Goal:** Real identity; no investigation persistence yet.

| Deliverable | Status |
|---|---|
| Firebase project configuration | ✅ Placeholder + FlutterFire onboarding ([`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)) |
| FlutterFire configuration | ✅ `firebase_options.dart`; Android/iOS platform configs |
| Android Gradle + Google Services | ✅ |
| Auth implementation | ✅ `AuthenticationService`, `FirebaseAuthRepository`, `AuthGate` |
| Email sign-up / login / reset | ✅ Wired to existing auth screens |
| Google Sign-In | ✅ OAuth (google_sign_in 7.x) |
| Session persistence | ✅ Firebase Auth + `AuthenticationStateProvider` |
| Friendly error mapping | ✅ `AuthErrorMapper` |
| Apple Sign-In | ⏳ Interface prepared — implementation Phase 8 |
| App Check | ⏳ Prepare only — enforcement Phase 5 |
| User profile bootstrap (`users/{uid}`) | ⏳ Deferred to Phase 2 |

**Do not build:** Firestore incident sync, Storage uploads, investigation UI changes beyond auth error handling.

**Exit criteria:** User can register, login, logout, reset password; session restores on restart; mock auth replaced with Firebase Auth layer.

---

## Phase 2 — Firestore Core ✅ (Sprint 4B)

**Goal:** Persist incidents and evidence metadata.

| Deliverable | Status |
|---|---|
| `FirebaseIncidentRepository` / `FirebaseEvidenceRepository` | ✅ |
| `StorageRepository` boundary | ✅ |
| `IncidentCloudSyncService` write-through + hydrate | ✅ |
| Evidence docs with coaching fields | ✅ |
| Restore on AuthGate / app launch | ✅ |
| `firestore.rules` | ✅ |

**Still deferred to Phase 4:** relationship groups, narrative events, reconstruction notes as first-class Firestore subcollections (incident counters already stored).

**Exit criteria:** Incident and evidence metadata survive app restart — ✅

---

## Phase 3 — Storage + Capture Upload ✅ (Sprint 4A + 4B polish)

**Goal:** Evidence binaries persisted per [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md).

| Deliverable | Status |
|---|---|
| Upload pipeline (Photo/Video/Voice/Attachment) | ✅ Sprint 4A |
| Thumbnail + image compression | ✅ Sprint 4B (`MediaPreprocessService`) |
| Retry queue + non-blocking progress | ✅ Sprint 4A |
| Firestore `downloadUrl` / `storagePath` | ✅ Sprint 4B |

**Deferred:** SHA-256 content hash, resumable large-video sessions, full dual-path unification.

---

## Phase 4 — Investigation Objects Sync

**Goal:** Full incident aggregate sync.

| Deliverable | Description |
|---|---|
| Participants | Sync + inline creation ([Sprint 2.2](lib/repositories/participant_repository.dart)) |
| Relationship groups | Connect Mode persistence |
| Relationships | Evidence link graph |
| Narrative events | Reconstruction sections |
| Reconstruction notes | Reflections |
| Trust Package metadata | Export record documents (not full client assembly write) |

**Do not build:** Cloud Functions export; collaboration/multi-user.

**Exit criteria:** Investigation Workspace state survives cross-device login for same user.

---

## Phase 5 — Security Rules + App Check Enforce

**Goal:** Production-grade authorization.

| Deliverable | Description |
|---|---|
| Firestore Rules | Owner-only access; immutable capture fields |
| Storage Rules | Path-UID match; write-once originals |
| App Check enforce | Block unattested clients |
| Rules unit tests | Emulator test suite |

**Do not build:** Collaboration rules; public share links.

**Exit criteria:** Cross-user access attempts fail in emulator tests; App Check enforced in staging.

---

## Phase 6 — Cloud Functions

**Goal:** Server-side operations that must not run on client.

| Function | Purpose |
|---|---|
| `onAccountDelete` | Cascade Firestore + Storage deletion |
| `onIncidentDelete` | Prefix delete incident Storage |
| `generateTrustPackage` | PDF/archive assembly (optional) |
| `orphanStorageScanner` | Scheduled cleanup |

**Do not build:** AI inference Functions; coaching engine server-side.

**Exit criteria:** Account deletion leaves zero orphaned Storage objects in test environment.

---

## Phase 7 — Offline Sync + Autosave

**Goal:** Calm documentation without connectivity anxiety.

| Deliverable | Description |
|---|---|
| Firestore offline persistence | Enabled by default |
| Autosave policy | Debounced narrative; immediate capture queue |
| Conflict UI | Minimal — immutable field protection; last-write-wins on enrichment |
| Sync indicators | Subtle — not dashboard-style ([`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md)) |

**Do not build:** Real-time collaboration; CRDT merge.

**Exit criteria:** User documents incident offline; syncs on reconnect without chronology corruption.

---

## Phase 8 — Apple Sign-In + Production Hardening

**Goal:** App Store readiness and production deployment.

| Deliverable | Description |
|---|---|
| Apple Sign-In | iOS provider |
| Email verification gate | Optional before Trust Package export |
| Monitoring | Crashlytics, Performance, Auth analytics |
| Backup / export compliance | User data export per privacy policy |
| Production Firebase project | Separate from dev/staging |

**Exit criteria:** App Store submission requirements met; production security review passed.

---

## Engine Alignment by Phase

| Platform engine | First persisted in |
|---|---|
| Capture Engine | Phase 2–3 |
| Evidence Engine | Phase 2–3 |
| Relationship Engine | Phase 4 |
| Narrative Engine | Phase 4 |
| Trust Package Engine | Phase 4 (metadata) · Phase 6 (export) |
| Platform Services (Auth) | Phase 1 |
| Platform Services (Storage) | Phase 3 |

---

## Dependencies and Blockers

| Blocker | Blocks | Resolution |
|---|---|---|
| Dual capture paths | Phase 3 | Unify client capture before Storage wiring |
| Mock auth in production | Phase 1 | ✅ Resolved in MVP-0.9.3.2 |
| No Security Rules | Production launch | Phase 5 mandatory before public release |
| In-memory controller | Phase 2 | Repository abstraction already exists — implement Firebase backends |

---

## What Backend Roadmap Does Not Include

- UI redesign or new navigation
- Investigation coaching / health server endpoints (remain client-derived)
- Multi-user collaboration (reserved in data model only)
- Non-Firebase backend migration
- Blockchain / external evidence notarisation

---

## Document Hierarchy

| Topic | Document |
|---|---|
| Architecture overview | [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) |
| Collection schemas | [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) |
| Storage paths | [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) |
| Auth lifecycle | [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) |
| Product intelligence roadmap | [`ROADMAP.md`](ROADMAP.md) |

---

*MVP-0.9.3.2 — Backend roadmap. Phase 0–1 complete; implementation continues Phase 2.*
