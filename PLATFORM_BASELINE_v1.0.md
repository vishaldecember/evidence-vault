# Evidence Vault Platform Baseline v1.0

**Date:** July 31, 2026  
**Version:** 1.0.0+1 (`pubspec.yaml`)  
**Milestone:** Product Architecture Freeze  
**Sprint:** 8  
**Status:** Platform Baseline — Pre-Backend Engineering  

---

## Platform Identity

| | |
|---|---|
| **Product** | Evidence Vault |
| **Experience** | Library of Truth |
| **Category** | Incident Reconstruction Platform |
| **Core Engine** | Relationship Engine |
| **Trust Model** | Verification + Integrity (Trust Status at incident level) |
| **Primary Output** | Trust Package |

---

## Product Status

Evidence Vault is an **Incident Reconstruction Platform** — not a storage, evidence management, or evidence collection product. Its purpose is to help people preserve, enrich, connect, and understand incidents, and produce trusted reports when ready.

Product philosophy is consolidated in [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) (v3.0 — Architecture Freeze). That document is the single source of truth for Vision, Mission, Product Identity, Product Category, Core Beliefs, operational rules, and Product North Star.

### Architecture freeze confirmations

| Area | Status | Notes |
|---|---|---|
| **Product Principles frozen** | ✅ | v3.0 constitution complete; manifestos merged and retired |
| **Workspace architecture finalized** | ✅ | Capture-and-build surface defined in Product Principles §3 and [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md); no dashboard model |
| **Story architecture finalized** | ✅ | View Story as intelligence centre — Timeline, Connections, Summary, Trust Status — defined in Product Principles §7 and UX Architecture |
| **Trust Package flow defined** | ✅ | Prepare Trust Package entry from Workspace; assembly and sections defined in Product Principles, [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) §5, and Language System |
| **Capture-first workflow established** | ✅ | Documented in Product Principles §9 and UX Architecture; first capture creates incident without prerequisite forms |

The **frontend implementation** is a **presentation prototype**: workspace state is held in memory via `WorkspaceEvidenceController`, authentication is simulated, and persistence is not yet unified across all capture paths. Product and UX architecture are frozen; backend integration is the next engineering phase.

---

## UX Baseline

### Surfaces confirmed (UI implemented)

| Surface | Implementation | Baseline status |
|---|---|---|
| **Home screen** | `HomeScreen` + `HomeBody` — Launch Pad, quick capture, Library preview, resume | ✅ UI complete; capture routes to Workspace without mode-specific capture (TODO in code) |
| **Capture flow** | Quick capture on Home; sticky capture bar on Workspace; legacy capture screens (`PhotoCaptureScreen`, `VideoCaptureScreen`, `AudioRecordingScreen`, `DocumentImportFlowScreen`) exist but are not wired from Home | ⚠️ Dual paths — primary Home → Workspace handoff; legacy chain orphaned from main journey |
| **Evidence Workspace** | `EvidenceWorkspaceScreen` + `WorkspaceBody` — Incident Journey, capture layer, View Story / Trust Package entry | ✅ Core working surface implemented |
| **Incident Journey** | `IncidentJourneyCard` + `LivingEvidencePreview` — EMPTY / BUILDING / RICH stages, evidence previews | ✅ Implemented per Sprint 7.x UX |
| **View Story** | `StoryScreen` + `StoryRenderer` — Timeline, Connections, Summary, Trust Status sections | ✅ Read-only assembly from workspace state |
| **Trust Package** | `TrustPackageScreen` + `TrustPackageRenderer` — structured preview | ✅ Read-only preview; sharing/export not implemented |
| **Library of Truth (Vault tab)** | `VaultScreen` | ⚠️ Stub — canonical empty-state copy; no incident browse/search |
| **Profile** | `ProfileScreen` | ⚠️ Stub |

### Current user journey (as implemented)

```
Splash
  ├── Create Account / Log in / Social (simulated) ──► MainShell
  └── Forgot Password

MainShell [IndexedStack — bottom navigation]
  ├── Home ──► Quick Capture ──► Evidence Workspace (push)
  │              Resume ──► Evidence Workspace (push)
  ├── Vault (stub — Library of Truth placeholder)
  └── Profile (stub)

Evidence Workspace
  ├── Capture (sticky Action Layer)
  ├── Incident Journey (living evidence preview)
  ├── Incident Title (progressive naming drawer)
  ├── View Story (push)
  ├── Prepare Trust Package (push)
  ├── Evidence Record (push — from journey preview)
  └── Bottom sheets: Add Context, Link Evidence, Reflection

View Story
  └── Evidence Record (push — from timeline/connections)

Trust Package
  └── Evidence Record (push — from evidence overview)
```

Authentication precedes the journey. Operational states (Draft, Active, Paused, Finalized, Archived) are documented but not fully surfaced in UI.

---

## Frontend Baseline

### Design System

| Item | Status |
|---|---|
| **Design System documented** | ✅ [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) v2.0 — colours, typography, spacing, Interaction Philosophy |
| **Theme standardized** | ✅ `lib/theme/` — `AppTheme`, `AppColors`, `AppTextStyles`, `AppButtonStyles`, `AppDecorations`, `AppMotion` |
| **Spacing scale** | ✅ `lib/constants/app_spacing.dart` aligned with design tokens |
| **Reachability supplement** | ✅ [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) |

### Navigation architecture

| Item | Status |
|---|---|
| **App entry** | `SplashScreen` → auth → `MainShellScreen` |
| **Shell navigation** | Three-tab `IndexedStack` (Home, Vault, Profile) |
| **Workspace navigation** | Imperative `Navigator.push` via `AppNavigation` |
| **No declarative router** | MaterialApp with `home:` — no GoRouter |

### Shared widgets established

81 widget files under `lib/widgets/`, organized by domain:

- **Common:** `AppSnackBar`, `SuccessConfirmation`, `AppBackButton`, section cards
- **Home:** Launch Pad, quick capture, library preview
- **Workspace:** capture bar, journey card, living evidence preview, incident identity drawer, evidence map section
- **Evidence Record:** preview, integrity, metadata, add context bar
- **Story / Trust Package:** renderers and section widgets
- **Context / Linked Evidence / Reflection / Verification / Timeline:** enrichment and trust UI

### Responsive layouts

| Context | Status |
|---|---|
| **Mobile portrait (primary)** | ✅ Target layout — Motorola moto g35 5G reference device |
| **Tablet / landscape** | ❌ Not implemented — phone-portrait only |
| **Text scaling** | ⚠️ Partial — Sprint 6.4 accessibility improvements; not fully validated at all scale factors |

### Local presentation engines (no backend)

| Component | Location | Role |
|---|---|---|
| `WorkspaceEvidenceController` | `lib/controllers/` | In-memory workspace state |
| `RelationshipRepository` | `lib/repositories/` | In-memory link storage |
| `StoryBuilder` | `lib/story/` | Assembles Story from workspace data |
| `TrustPackageBuilder` | `lib/trust_package/` | Assembles Trust Package from workspace data |
| `InsightEngine` | `lib/engines/` | Rule-based insights (local) |
| `EvidenceStorageService` | `lib/services/` | Local file storage — not wired to primary workspace path |

---

## Documentation Baseline

### Authoritative documents (Architecture Freeze)

| Document | Responsibility |
|---|---|
| [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | **Single source of truth** — vision, mission, identity, category, philosophy, rules, North Star |
| [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Platform flow, modules, Relationship Engine, data model, Trust Package |
| [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) | User journey, screen responsibilities, progressive disclosure |
| [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) | Terminology, voice, canonical copy |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Visual and interaction standards |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Reachability ergonomics supplement |
| [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) | Feature evaluation gates |
| [`DOCS_INDEX.md`](DOCS_INDEX.md) | Documentation map and authoritative homes |

### Retired (redirect stubs only)

| Document | Status |
|---|---|
| [`PRODUCT_MANIFESTO.md`](PRODUCT_MANIFESTO.md) | Merged into Product Principles |
| [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | Merged into Product Principles |

### One source of truth per concept

Confirmed via [`DOCS_INDEX.md`](DOCS_INDEX.md) — each concept (Vision, Mission, Identity, Category, Relationship Engine, Trust Status, Trust Package, etc.) has exactly one authoritative document. Supporting specs reference Product Principles; they do not redefine philosophy.

### Engineering documentation

| Document | Role |
|---|---|
| [`docs/DEVELOPMENT_BASELINE.md`](docs/DEVELOPMENT_BASELINE.md) | Toolchain versions and recovery |
| [`docs/BUILD_HEALTH.md`](docs/BUILD_HEALTH.md) | Daily pre-sprint checklist |

### Quality audit reports (historical — Sprint 6.x)

`V1_READINESS_REPORT.md`, `FTUE_AUDIT.md`, `TRUST_AUDIT.md`, `PERFORMANCE_REPORT.md`, `ACCESSIBILITY_AUDIT.md` — snapshots of prior sprints; not product specifications.

---

## Repository Health

| Item | Status | Detail |
|---|---|---|
| **Git repository** | Active | Remote: `origin/main` |
| **Current branch** | `main` | Up to date with `origin/main` at last fetch |
| **Latest commit** | `ddbc9f5` | *Milestone 1 - Premium Create Account Screen* |
| **Working tree** | ⚠️ Uncommitted | Extensive modified and untracked files — Sprint 8 frontend, documentation, and Architecture Freeze work not yet committed |
| **`.gitignore` configured** | ✅ | Flutter/Dart, `build/`, `android/build/`, `.dart_tool/`, `.gradle/`, `.gradle-user-home/`, `.vscode/` |
| **Architecture Freeze tag** | ☐ **Pending** | No git tag applied at time of baseline |
| **Branch strategy** | Single branch | `main` — feature branches not documented |
| **Backup status** | Not verified in repository | Remote sync via `origin/main`; no automated backup policy recorded in docs |

**Pre-backend action required:** Commit Architecture Freeze documentation and frontend baseline; apply Architecture Freeze git tag before backend sprint begins.

---

## Engineering Health

Values from [`docs/DEVELOPMENT_BASELINE.md`](docs/DEVELOPMENT_BASELINE.md) and live verification (July 31, 2026).

| Item | Status |
|---|---|
| **Flutter Version** | 3.44.6 (stable) |
| **Dart Version** | 3.12.2 |
| **Android Build Status** | Builds on baseline environment per DEVELOPMENT_BASELINE; debug APK verified historically — not re-run for this baseline |
| **Analyzer Status** | ⚠️ 2 issues — 1 info (`withOpacity` deprecation in `splash_screen.dart`); 1 error (`MyApp` reference in `test/widget_test.dart`) |
| **Tests Status** | ⚠️ **28 passed, 4 failed** (32 total) — failures in `main_shell_navigation_test.dart` (library hero copy, capture preservation, layout overflow) |
| **Reference device** | Motorola moto g35 5G (`ZA222V9Y3V`) |

### Known Technical Debt

| Item | Source |
|---|---|
| **Dual capture paths** — Home bypasses mode-specific capture; legacy `CreateEvidenceScreen` chain unreachable | V1 Readiness Report; `home_screen.dart` TODO |
| **In-memory workspace** — `WorkspaceEvidenceController` mock data; not persisted to backend or unified local DB | V1 Readiness Report; Trust Audit |
| **Simulated authentication** — `AuthService` placeholder; no Firebase/backend integration | `auth_service.dart` |
| **Integrity / verification cosmetic** — UI presents trust signals; hashing and real verification workflow not implemented | Trust Audit |
| **Vault and Profile stubs** — Library browse/search and user profile not built | Code inspection |
| **Encryption claims vs implementation** — copy may exceed current security implementation | Trust Audit |
| **Orphaned / dead code** — `EvidenceWorkspacePlaceholderScreen`, legacy navigation paths | V1 Readiness Report |
| **README** — default Flutter template; not product-specific | DOCS_INDEX |

### Known Risks

| Risk | Severity |
|---|---|
| Uncommitted Architecture Freeze work lost if not committed/tagged | High |
| Frontend tests failing — regression signal on core navigation | Medium |
| Analyzer error blocks clean CI gate | Medium |
| Presentation prototype mistaken for production-ready trust product | High — messaging must stay honest until backend built |
| Dual capture/persistence paths will complicate backend wiring without unification plan | Medium |

---

## Product Readiness

### Ready to begin backend implementation?

**Yes — for product architecture and frontend specification.**

The platform has a **frozen product constitution**, **defined platform architecture**, **complete UX specification**, **standardized design system**, and a **working presentation-layer prototype** that demonstrates the primary user journey from Home through Workspace, View Story, and Trust Package.

**No — for public release or trust claims.**

Backend services, real authentication, persistent evidence storage, trust engine implementation, and unified capture persistence are required before the product can deliver on its documented promises.

### Frontend work intentionally deferred

| Item | Rationale |
|---|---|
| Vault / Library browse and search UI | Requires Incident Service backend |
| Profile and account management UI | Requires Authentication and User Profiles backend |
| Unified Home → capture mode → persist → Workspace flow | Deferred to backend integration sprint |
| Trust Package export / sharing | Requires Trust Package Generator and Cloud Storage |
| Tablet and landscape layouts | Post-MVP responsive pass |
| End-to-end automated tests | Post-backend integration |
| Public README and App Store assets | Pre-release polish |
| Removal of legacy capture chain | After primary path wired to backend |

---

## Backend Readiness Checklist

All items unchecked — backend engineering has not begun.

| | Service | Frontend dependency |
|---|---|---|
| ☐ | **Authentication** | Auth screens exist; `AuthService` is simulated |
| ☐ | **User Profiles** | Profile tab is stub |
| ☐ | **Incident Service** | Incidents created implicitly in workspace controller only |
| ☐ | **Evidence Service** | Local `EvidenceStorageService` exists; not wired to workspace |
| ☐ | **Context Service** | Add Context UI exists; no API persistence |
| ☐ | **Relationship Engine** | In-memory `RelationshipRepository` only |
| ☐ | **Trust Engine** | Trust Status UI exists; no verification/integrity backend |
| ☐ | **Story Engine** | Local `StoryBuilder` only |
| ☐ | **Trust Package Generator** | Local `TrustPackageBuilder` only; no export |
| ☐ | **Cloud Storage** | Not implemented |
| ☐ | **API Layer** | Not implemented |

---

## CTO Release Assessment

Evidence Vault has reached the **Product Architecture Freeze** milestone. This is the correct checkpoint to transition from frontend architecture into backend engineering.

**Why the platform is ready for backend work:**

1. **Product identity is settled.** Evidence Vault is defined as an Incident Reconstruction Platform with Library of Truth as the experience, Relationship Engine as the connective core, and Trust Package as the primary output. No competing philosophy documents remain active.

2. **Architecture is documented and aligned.** Product Principles, Platform Architecture, UX Architecture, Language System, and Design System describe the same platform flow: Library → Workspace → Relationship Engine → View Story → Trust Package. Backend teams can implement against [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) without ambiguity.

3. **The frontend prototype validates the UX.** Nineteen screen files, eighty-one widget modules, and a working Workspace → Story → Trust Package path prove the capture-first journey is viable on the reference Android device. Backend services have clear UI consumers.

4. **Presentation engines define contracts.** `StoryBuilder`, `TrustPackageBuilder`, `RelationshipRepository`, and `WorkspaceEvidenceController` establish the data shapes and assembly logic backend services must satisfy — even though they currently operate on in-memory data.

5. **Technical debt is known and scoped.** Simulated auth, dual capture paths, cosmetic trust signals, and stub Vault/Profile screens are documented and intentionally deferred — not hidden. Backend integration is the explicit next phase.

**Conditions before backend sprint starts:**

- Commit and tag the Architecture Freeze baseline on `main`
- Resolve analyzer error in `test/widget_test.dart`
- Agree unification plan for capture → persist → Workspace (retire legacy path)
- Define API contracts from Platform Architecture data model

**Assessment:** The frontend architecture phase is complete. Backend engineering may proceed against this baseline. Public release readiness remains a separate milestone requiring all Backend Readiness Checklist items and resolution of documented trust and persistence gaps.

---

## Post-Baseline Product Refinements

Following the creation of this baseline, additional UX refinements were approved before backend implementation.

These refinements are tracked under:

**Sprint 8.5 – UX Refinement & Product Finalization**

The Platform Baseline remains an **accurate snapshot of the platform at the time of documentation** and should be read together with [`SPRINT_8.5_UX_REFINEMENT.md`](SPRINT_8.5_UX_REFINEMENT.md) implementation notes.

Sprint 8.5 changes do not alter the frozen product constitution (`PRODUCT_PRINCIPLES.md`) or platform architecture. They refine presentation-layer UX within the established architecture.

---

*This document captures Evidence Vault at Platform Baseline v1.0 — immediately before backend development begins. Update only at major milestones.*
