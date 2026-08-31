**Version:** DI-3.1  
**Status:** Active — Platform Architecture  
**Last Updated:** August 4, 2026 (Permanent Product Rule — Onboarding Freeze)

# Evidence Vault Platform Architecture

This document defines Evidence Vault as an **Investigation Platform** — the engine architecture that powers incident reconstruction, independent of any single screen or sprint implementation.

It describes **what each platform engine is responsible for**, how engines depend on one another, and how future capabilities extend the platform without replacing it.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Investigation Platform philosophy; Simplicity Above Intelligence (DI-3.0)
- [`ROADMAP.md`](ROADMAP.md) — platform intelligence roadmap (DI-3.0)
- [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) — bounded contexts and domain objects (DI-1.2)
- [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) — reconstruction pipeline and workflow (DI-1.3)
- [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) — sprint implementation, repositories, and wiring reference
- [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — permanent engineering guardrails (DI-3.0)
- [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) — onboarding freeze; investigation-first decision filter
- [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — product constitution
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map

**Governing principle:** Evidence Vault is **not a storage application**. It is a platform that preserves observations, reveals relationships, reconstructs chronology, and communicates findings — without determining truth.

**Simplicity principle (DI-3.0):** Evidence Vault is **a calm documentation experience powered by an intelligent investigation engine**. Complexity belongs to the engine; simplicity belongs to the interface. See [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — [Simplicity Above Intelligence](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence).

---

# Permanent Product Rule

## Onboarding is not the product.

The purpose of onboarding is to:

- establish trust
- create an account
- get users into their investigation as quickly as possible

Once onboarding is complete, engineering effort should shift toward improving the investigation experience.

Evidence Vault's competitive advantage is created inside:

- Capture
- Evidence
- Investigation
- Trust Package
- Investigation Coaching

—not during account creation.

**Onboarding is functionally complete.** Future innovation belongs in the investigation experience — not in registration screens. Authoritative freeze rule: [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md).

### Engineering Rule

Do not redesign onboarding unless:

1. Usability testing demonstrates measurable friction.
2. Accessibility requirements change.
3. Authentication architecture changes.

Otherwise: **freeze onboarding** and focus on investigation workflows.

### Decision Filter

Before accepting any new platform feature, ask:

> **Does this improve the investigation?**

If not, challenge whether it belongs in the product.

---

## Platform Overview

Evidence Vault is structured as a **layered investigation platform**. Domain engines perform reconstruction work inside one Incident. Platform Services provide cross-cutting capabilities that support every engine. Presentation workspaces consume engine outputs — they do not own domain state.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│   Evidence Workspace · Investigation Workspace · Trust Package │
└────────────────────────────┬────────────────────────────────┘
                             │ consumes projections
┌────────────────────────────▼────────────────────────────────┐
│                     Platform Engines                         │
│                                                              │
│   Capture Engine ──► Evidence Engine ──► Relationship Engine │
│                           │                    │             │
│                           └────────┬───────────┘             │
│                                    ▼                         │
│                          Narrative Engine                    │
│                                    │                         │
│                                    ▼                         │
│                        Trust Package Engine                  │
└────────────────────────────┬────────────────────────────────┘
                             │ supported by
┌────────────────────────────▼────────────────────────────────┐
│                     Platform Services                        │
│   Identity · Storage · Privacy · Sharing · Library · Sync    │
└─────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                     Incident Aggregate                       │
│   Evidence · Timeline Events · Relationship Groups ·          │
│   Narrative Events · Trust Package (projection)              │
└─────────────────────────────────────────────────────────────┘
```

Every engine serves **reconstruction quality** — measuring how well an incident has been preserved, connected, explained, and prepared for communication — not how many files have been collected.

---

## Core Platform Engines

Evidence Vault is powered by five domain engines and one services layer:

```
Evidence Vault Platform
├── Capture Engine
├── Evidence Engine
├── Relationship Engine
├── Narrative Engine
├── Trust Package Engine
└── Platform Services
```

| Engine | Core question | Primary domain ownership |
|---|---|---|
| **Capture Engine** | *How are observations preserved at the moment they happen?* | Capture persistence, incident bootstrap, timeline anchor creation |
| **Evidence Engine** | *How well is each record supported and understood?* | Enrichment, maturity signals, supporting evidence, Journey derivation |
| **Relationship Engine** | *How does evidence connect?* | Evidence links, Relationship Groups, investigative structure |
| **Narrative Engine** | *How is the incident explained?* | Narrative Events, reconstruction projection, completeness validation |
| **Trust Package Engine** | *How are findings communicated with integrity?* | Trust Package assembly, integrity aggregates, export readiness |
| **Platform Services** | *What cross-cutting capabilities support all engines?* | Identity, storage, privacy, sharing, library, collaboration infrastructure |

Engines are **domain services** — not screens. Workspaces invoke engines through controllers and repositories. Backend services (future) should mirror these engine boundaries as separate modules with defined APIs.

---

## Engine Dependency Order

Engines operate in a defined dependency chain. Each engine consumes upstream outputs and supplies structured status downstream.

```
Capture Engine
      ↓
Evidence Engine
      ↓
Relationship Engine
      ↓
Narrative Engine
      ↓
Trust Package Engine
```

| Engine | Consumes | Produces |
|---|---|---|
| **Capture Engine** | Investigator capture intent | Persisted captured evidence, Incident bootstrap, Timeline Event anchors |
| **Evidence Engine** | Captured + supporting evidence | Enrichment status, Journey maturity, timeline tree structure |
| **Relationship Engine** | Evidence items within an Incident | Bidirectional links, Relationship Groups, linked-enrichment signals |
| **Narrative Engine** | Timeline Events, groups, enrichment | Narrative Events, validation summaries, reconstruction projections |
| **Trust Package Engine** | Full incident aggregate projection | Trust Package, integrity summaries, export-ready presentation model |

**Platform Services** span all engines horizontally — authentication before capture, storage beneath persistence, privacy controls across deletion, sharing at Trust Package output.

Investigators may work non-linearly across engines. Dependency order describes **data derivation**, not mandatory UI sequence.

---

## 1. Capture Engine

### Responsibility

The Capture Engine owns **the moment observations enter the platform** — fast, reliable preservation before memory fades.

### Core duties

- Accept capture actions: photo, video, voice, note, attachment, witness record
- Bootstrap the Incident automatically on first capture — no empty container creation
- Persist **Captured Evidence** as immutable artifacts with automatic metadata
- Create one **Timeline Event** (anchor) per capture — establishing initial chronology
- Apply initial verification and integrity metadata at preservation time
- Guarantee capture succeeds under stress: offline-tolerant where practical, automatic saving, thumb-first ergonomics at presentation layer

### Produces

| Output | Downstream consumer |
|---|---|
| `CapturedEvidence` records | Evidence Engine, all upper engines |
| Timeline Event anchors | Evidence Engine (tree), Narrative Engine, Trust Package Engine |
| New or existing Incident binding | All engines |
| Capture timestamps and device metadata | Trust Package Engine (integrity appendix) |

### Does not

- Enrich or interpret evidence (Evidence Engine)
- Group or link evidence (Relationship Engine)
- Generate narrative text (Narrative Engine)
- Assemble presentation packages (Trust Package Engine)
- Require naming, categorisation, or setup before first preservation

### Investigation pipeline layer

**Evidence** foundation — specifically the immutable capture act and automatic Timeline Event creation described in [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md).

---

## 2. Evidence Engine

### Responsibility

The Evidence Engine owns **evidence maturity** — how well each preserved record is supported, organised, and ready for reconstruction.

### Core duties

- Manage **Supporting Evidence** attached beneath captured anchors (notes, documents, context)
- Evaluate per-item enrichment and derive `isEnriched` maturity signals
- Calculate **Incident Status** maturity from enrichment across primary evidence — advisory, never blocking
- Maintain the **timeline tree**: captured anchors with nested supporting artifacts
- Supply enrichment completeness signals to Narrative and Trust Package engines
- Preserve immutability: enrichment surrounds evidence; it never replaces captured content

### Produces

| Output | Downstream consumer |
|---|---|
| Enrichment status per primary evidence item | Narrative Engine (validation), Trust Package Engine (summary) |
| Incident Status maturity stage | Presentation coaching, Readiness extensions |
| Supporting evidence linkage | Relationship Engine, Narrative traceability |
| Timeline tree read model | Investigation workspaces, Trust Package timeline section |

### Does not

- Perform capture persistence (Capture Engine)
- Commit Relationship Groups (Relationship Engine)
- Author or reorder Narrative Events (Narrative Engine)
- Block Trust Package assembly based on maturity

### Legacy mapping

The Evidence Engine subsumes responsibilities previously documented as the **Enrichment Engine** in [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md). Enrichment evaluation, Journey derivation, and supporting evidence ownership live here.

---

## 3. Relationship Engine

### Responsibility

The Relationship Engine owns **connection** — how evidence relates without modifying any artifact.

### Core duties

- Accept investigator linking actions: Connect Mode, Organize mode, pairwise links from Evidence Records
- Store bidirectional **Evidence Relationships** between items
- Commit and manage **Relationship Groups** as persisted investigative structures
- Maintain internal relationship type semantics — never exposed as user classification tasks
- Resolve **Linked Evidence** as an enrichment type for the Evidence Engine
- Preserve group identity: member IDs, colour index, optional name and investigative description

### Produces

| Output | Downstream consumer |
|---|---|
| `RelationshipGroup` entities | Narrative Engine (traceability), Trust Package Engine (group sections) |
| Evidence relationship graph | Evidence Engine (linked enrichment), Narrative validation |
| Group confidence coaching signals *(derived)* | Presentation layer, Coaching extensions |

### Does not

- Modify captured evidence content or timestamps
- Reorder Timeline Events
- Write narrative summaries (Narrative Engine)
- Duplicate evidence in group storage — membership is by reference ID only

### Investigative principle

Relationship Groups are **domain entities**, not UI constructs. The engine persists investigative structure whether or not a Connections panel is visible. See [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md).

---

## 4. Narrative Engine

### Responsibility

The Narrative Engine owns **explanation** — investigator-authored reconstruction built on preserved history.

### Core duties

- Initialise **Narrative Events** — one placeholder per Timeline Event on first access
- Project the incident aggregate into narrative read models without duplicating evidence
- Persist investigator titles, summaries, and narrative sequence (`sortOrder`)
- Refresh evidence and group **references** when upstream layers change — never overwrite customized investigator text
- Validate reconstruction **completeness** — coaching signals only, not truth adjudication
- Synchronise narrative selection with timeline and relationship perspectives in investigation workspaces

### Produces

| Output | Downstream consumer |
|---|---|
| `NarrativeEvent` entities | Trust Package Engine (reconstruction section) |
| Narrative validation summaries | Presentation coaching, Readiness extensions |
| Reconstruction health aggregates | Investigation workspace headers |
| Cross-perspective sync signals | Investigation canvas (presentation) |

### Does not

- Record capture chronology (Capture Engine / Timeline Events)
- Replace Timeline Event order when narrative is reordered
- Generate unsupported conclusions — AI extensions must remain evidence-referenced
- Duplicate evidence payloads inside narrative storage

### Timeline vs Narrative

| | Timeline Events | Narrative Events |
|---|---|---|
| **Engine** | Capture + Evidence (anchor ownership) | Narrative Engine |
| **Role** | Records history | Explains history |

See [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) for the full distinction.

### Legacy mapping

The Narrative Engine subsumes responsibilities previously documented as the **Story Engine** — narrative builder, validation, and reconstruction projection.

---

## 5. Trust Package Engine

### Responsibility

The Trust Package Engine owns **communication** — assembling a professional, traceable presentation of the complete incident.

### Core duties

- Assemble **Trust Package** from the Incident aggregate via a single assembler — no duplicate evidence embedding
- Compose sections: incident summary, timeline, relationship groups, narrative reconstruction, evidence appendix, integrity summary
- Aggregate Verification and Integrity signals at incident level
- Produce the canonical input for export pipelines: PDF, archive, print, secure share
- Preserve traceability — every section references domain objects by ID, not orphaned copies
- Remain available at every investigation stage — assembly is never blocked by maturity

### Produces

| Output | Downstream consumer |
|---|---|
| `TrustPackage` read model | Trust Package preview, export services, share services |
| Integrity and verification summaries | Export metadata, Readiness extensions |
| Section-level projections | PDF renderer, print service, archive serializer |

### Does not

- Mutate Evidence, Timeline Events, Relationship Groups, or Narrative Events
- Read the raw aggregate at export render time — exporters consume Trust Package only
- Determine factual or legal truth
- Replace the Incident as source of truth

### Legacy mapping

The Trust Package Engine subsumes responsibilities previously documented as the **Trust Engine** — integrity evaluation, Trust Package assembly, and share/export readiness.

---

## Platform Services

Platform Services provide **cross-cutting infrastructure** that every engine depends on but none should own.

### Responsibility

Platform Services support the investigation platform horizontally — identity, persistence infrastructure, privacy, distribution, and long-term incident management — without embedding business rules that belong inside domain engines.

### Core service domains

| Service domain | Responsibility |
|---|---|
| **Evidence Storage** | Firebase Storage binaries + Firestore evidence/investigation graph (Sprint 4D); repository-mediated only |
| **Identity & Session** | Firebase Auth via `AuthRepository` / `AuthenticationService`; investigation restore via `WorkspaceSession` |
| **Incident Library** | Library of Truth — browse, resume, search, archive across incidents |
| **Privacy & Data** | Account deletion, vault reset, incident data deletion, consent-aware controls |
| **Sharing & Export Infrastructure** | Secure share links, export directories, archive stores — consuming Trust Package output |
| **Notification & Sync** *(future)* | Cross-device sync, collaboration event delivery |
| **Organisation & Tenancy** *(future)* | Enterprise containers, role boundaries above individual users |

### Architectural rules

- Platform Services **never** encode reconstruction logic belonging to domain engines
- Domain engines **never** implement authentication, cloud sync, or export file I/O directly
- Export and share **always** consume Trust Package — never bypass the Trust Package Engine
- Privacy deletion operates transactionally across all repositories and service stores

### Does not

- Evaluate enrichment maturity (Evidence Engine)
- Commit relationship groups (Relationship Engine)
- Validate narrative completeness (Narrative Engine)
- Assemble Trust Package sections (Trust Package Engine)

---

## Engine ↔ Investigation Pipeline Mapping

The five domain engines implement the Investigation Engine pipeline described in [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md):

| Pipeline layer | Platform engine(s) |
|---|---|
| **Evidence** | Capture Engine + Evidence Engine |
| **Timeline Events** | Capture Engine (creation) + Evidence Engine (tree ownership) |
| **Relationship Groups** | Relationship Engine |
| **Narrative Events** | Narrative Engine |
| **Trust Package** | Trust Package Engine |

Capture and Evidence engines jointly own the **Evidence** and **Timeline Events** layers — Capture performs preservation and anchor creation; Evidence manages enrichment and timeline tree structure.

---

## Engine ↔ Domain Model Mapping

| Bounded context ([`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md)) | Owning engine |
|---|---|
| **Incident** | All engines (aggregate root); Capture Engine bootstraps |
| **Evidence** | Capture Engine + Evidence Engine |
| **Timeline Events** | Capture Engine + Evidence Engine |
| **Relationship Groups** | Relationship Engine |
| **Narrative Events** | Narrative Engine |
| **Trust Package** | Trust Package Engine |

---

## Presentation Layer (Reference)

Workspaces are **not engines**. They consume engine projections. Workspaces must never expose engine mechanics — investigation graphs, confidence models, health scoring, or simulation state — as user-managed concepts.

| Workspace | Primary engines invoked |
|---|---|
| **Evidence Workspace** | Capture, Organize, Relationship (Connect Mode commit) |
| **Investigation Workspace** | Evidence, Relationship, Narrative (Timeline, Connections, Reconstruction tabs); Investigation Coaching panel *(background capability — not a separate workflow)* |
| **Trust Package Workspace** | Trust Package (read-only preview and export actions) |

Workspace navigation and Investigation Journey header orientation are documented in [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) and [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md).

---

## Future Capabilities — Extend, Do Not Replace

Evidence Vault is designed as a **platform**, not a fixed feature set. Future capabilities attach to engine boundaries as extensions — they enhance reconstruction quality without rewriting core responsibilities.

### Extension principle

```
┌──────────────────────────────────────────┐
│         Future Capability Layer           │
│  Coaching · Readiness · Collaboration · AI │
└──────────────────┬───────────────────────┘
                   │ extends (derived signals,
                   │   suggestions, infra)
┌──────────────────▼───────────────────────┐
│         Core Platform Engines              │
│  Capture · Evidence · Relationship ·       │
│  Narrative · Trust Package                 │
└──────────────────┬───────────────────────┘
                   │ supported by
┌──────────────────▼───────────────────────┐
│         Platform Services                  │
└──────────────────────────────────────────┘
```

**Rules for all extensions:**

1. **Extend engines — never replace them.** A new capability adds derived signals, suggestions, or infrastructure; it does not absorb engine ownership.
2. **Never mutate captured evidence.** Extensions enrich understanding around immutable records.
3. **Never determine truth.** Coaching, Readiness, and AI advise completeness and structure — they do not adjudicate.
4. **Never bypass Trust Package.** All external communication flows through Trust Package Engine assembly.
5. **Fail open on investigation.** Extensions coach and recommend; they do not hard-block reconstruction work except where Platform Services enforce security or privacy policy.

---

### Coaching *(extends Evidence, Relationship, Narrative engines)*

**Purpose:** Continuously orient investigators toward stronger reconstruction — without gamification, completion pressure, or tutorial framing.

Investigation Coaching is documented in [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — [Investigation Coaching Philosophy](PRODUCT_PHILOSOPHY.md#investigation-coaching-philosophy). It is the platform’s **Strengthen** orientation: neutral, evidence-based guidance derived from investigation state. It is not a chatbot, legal advisor, or conclusion engine.

| Aspect | Design |
|---|---|
| **What it is** | Derived coaching insights and completeness indicators recomputed from engine state — surfaced inside the Investigation Workspace |
| **What it is not** | A chatbot, legal advisor, intent inference, progress tracking, scores, checkmarks, or mandatory step completion |
| **Engine touchpoints** | Evidence Engine (completeness, Journey stage copy), Relationship Engine (group confidence, unconnected evidence), Narrative Engine (validation recommendations), Trust Package Engine (readiness signals) |
| **Persistence** | Never persisted as domain truth — recomputed on projection rebuild; dismiss state is session presentation only |
| **Platform rule** | Coaching signals are advisory. Investigators retain full authority. The coach asks better investigative questions — it never provides investigative conclusions. |

Existing examples: Workspace Coaching Service (Journey stage copy), Relationship Group Confidence indicators, Narrative Validation recommendations, Investigation Coaching panel (SIC-2.0 foundation), Investigation Health Engine (SIC-2.1A — structured metrics consumed by coaching and readiness layers).

---

### Readiness *(extends Trust Package Engine)*

**Purpose:** Help investigators understand how prepared an incident is for communication — before sharing or export.

| Aspect | Design |
|---|---|
| **What it is** | Derived readiness evaluation against Trust Package section completeness and integrity thresholds |
| **What it is not** | A gate that blocks Trust Package assembly or export |
| **Engine touchpoints** | Trust Package Engine (section coverage, integrity aggregates), Narrative Engine (validation summaries), Evidence Engine (enrichment completeness) |
| **Persistence** | Readiness scores are projections — not stored as incident status |
| **Platform rule** | Readiness informs; it never prevents review or export. |

Readiness extends the Trust Package Engine's advisory layer — it does not replace assembly or create a separate report format.

---

### Collaboration *(extends Platform Services)*

**Purpose:** Enable multiple authorised participants to contribute to one incident investigation without merging truth records.

| Aspect | Design |
|---|---|
| **What it is** | Multi-user access, role-aware permissions, activity attribution, sync infrastructure |
| **What it is not** | Automatic incident linking, cross-incident inference, or shared mutable evidence |
| **Engine touchpoints** | Platform Services (identity, sync, permissions) — domain engines remain unchanged |
| **Persistence** | Collaboration metadata in Platform Services; incident aggregate rules unchanged |
| **Platform rule** | One incident = one truth record. Collaboration adds participants; it never merges incidents. |

Collaboration is a **Platform Services** extension. Capture through Trust Package engine contracts remain identical — collaborators invoke the same engines through authorised sessions.

---

### AI *(extends all engines — assistive layer)*

**Purpose:** Accelerate reconstruction by suggesting enrichment, inferring relationships, identifying gaps, and drafting narrative language — always subordinate to captured evidence.

| Aspect | Design |
|---|---|
| **What it is** | Evidence-referenced suggestions, inferred links, gap analysis, draft narrative language with clear labeling |
| **What it is not** | Autonomous truth determination, silent evidence modification, or unsupervised incident linking |
| **Engine touchpoints** | Capture (metadata inference), Evidence (summary enrichment type), Relationship (type inference), Narrative (draft sections), Trust Package (assembly assistance) |
| **Persistence** | AI output stored only as labeled enrichment or explicitly accepted investigator edits — never silent overwrite |
| **Platform rule** | AI assists. Investigators approve. Evidence remains immutable. |

AI extends each engine's **assistive surface** — it does not replace engine boundaries or collapse the pipeline into a single generative step.

| AI capability | Extends | Must not |
|---|---|---|
| Suggested context | Evidence Engine | Modify captured artifacts |
| Inferred relationship type | Relationship Engine | Auto-commit groups without investigator action |
| Missing information alerts | Narrative Engine | State unsupported facts |
| Draft narrative language | Narrative Engine | Overwrite customized investigator text |
| Trust Package drafting | Trust Package Engine | Bypass assembler traceability |

---

## Platform Roadmap — Intelligence as Background Capability

Future intelligence features **always remain background capabilities** — never additional user workflows, mandatory setup steps, or separate product modes. The investigator documents; the platform reasons. See [`ROADMAP.md`](ROADMAP.md) for the authoritative intelligence roadmap.

| Capability | Engine layer | User experience |
|---|---|---|
| **Investigation Coaching** | Derived from Evidence, Relationship, Narrative, Trust Package engines | Neutral questions surfaced in Investigation Workspace when helpful — dismissible, non-blocking |
| **Investigation Health** | Structured metrics and findings (SIC-2.1A foundation) | Consumed by coaching and readiness — never a dashboard users manage |
| **Simulation** | Engine-level what-if projection | Appears only when it naturally helps reconstruction — not a standalone mode |
| **Trust Readiness** | Extends Trust Package Engine advisory layer | Informs preparation for communication — never gates export or assembly |

### Simplicity commitments for all intelligence features

| Commitment | Meaning |
|---|---|
| **Background, not workflow** | Intelligence runs inside the engine; the interface stays calm |
| **Progressive disclosure** | Advanced reasoning appears when it helps — not as prerequisite setup |
| **Coaching without conclusions** | Better questions, not answers; no intent inference or legal advice |
| **Investigator authority** | Users document; the platform organises, connects, evaluates, and strengthens |
| **No interface growth** | The platform grows with the investigation; the interface does not grow in complexity |

---

## Platform Roadmap — Investigation Coaching

Investigation Coaching is a **long-term platform capability**, not a one-time feature. It evolves incrementally while remaining investigator-first — and **never becomes a separate user workflow**.

| Principle | Commitment |
|---|---|
| **Investigator-first** | Coaching assists; it never replaces investigator judgement or determines what happened |
| **Evidence-bound** | Every insight derives from evidence already in the Incident — no speculation, no intent inference |
| **Incremental delivery** | Categories, rules, and presentation expand sprint-by-sprint without rewriting core engines |
| **Embedded, not separate** | Coaching lives inside the Investigation Workspace — not a standalone stage or chat surface |
| **Non-blocking** | Recommendations are dismissible; investigation work continues regardless of coaching state |
| **Simplicity above intelligence** | Every new coaching signal reduces effort — it does not introduce concepts to learn (DI-3.0) |

### Evolution path

```
SIC-2.0  Foundation — persistent coaching panel; rule-based categories;
         Review navigation; dismiss; priority from completeness
    ↓
Future   Expanded signal coverage across Evidence, Relationship,
         Narrative, and Trust Package readiness
    ↓
Future   Richer presentation and contextual deep-linking —
         still derived, still advisory, still investigator-led
    ↓
Future   Optional AI-assisted suggestions — evidence-referenced only,
         explicitly labeled, never silent overwrite or autonomous conclusions
```

Coaching roadmap items **extend** the Coaching capability layer. They do not replace Capture through Trust Package engine boundaries or introduce a parallel investigation pipeline.

Authoritative product philosophy: [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Investigation Coaching Philosophy; [Simplicity Above Intelligence](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence).

Full intelligence roadmap: [`ROADMAP.md`](ROADMAP.md).

---

## Backend Alignment *(future)*

Authoritative backend blueprint: [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) · [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) · [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) (MVP-0.9.3.1).

Sprint 9+ backend services should **mirror platform engine boundaries**:

| Platform engine | Backend module responsibility |
|---|---|
| Capture Engine | Capture API, incident bootstrap, anchor creation |
| Evidence Engine | Enrichment evaluation, supporting evidence, Journey derivation |
| Relationship Engine | Link graph, group CRUD, organize transactions |
| Narrative Engine | Narrative event CRUD, projection, validation |
| Trust Package Engine | Assembler, integrity aggregates, export input |
| Platform Services | Auth, storage, privacy, sharing, library, sync |

Each module exposes a defined API matching engine inputs and outputs in this document. Detailed persistence schemas and service topology belong in backend architecture documentation — not in this platform overview.

---

## Platform Invariants

These rules apply across every engine and extension:

1. **One Incident = One Truth Record**
2. **Evidence is immutable after capture**
3. **Timeline chronology is never rewritten by narrative or presentation**
4. **Relationship Groups are investigative structures — not UI state**
5. **Narrative explains history; Timeline records history**
6. **Trust Package assembly consumes the aggregate — exporters consume Trust Package only**
7. **Platform neutrality — completeness coaching, not truth adjudication**
8. **Extensions enhance engines — they do not replace them**
9. **Simplicity above intelligence (DI-3.0)** — complexity belongs to the engine; the interface never grows in complexity to match engine sophistication

---

## Engineering Guardrails (DI-3.0)

Every sprint, feature, refactor, and design decision must be evaluated against permanent engineering guardrails **before implementation**.

Authoritative checklist and design rules: [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

### The guardrail question

> **Does this make the user's thinking calmer, or does it make the software more complicated?**

If the feature increases visible complexity for the user, **redesign it**. Complexity must move into the platform engine — not into the interface.

### Architecture implication

Engine extensions (coaching, health, simulation, reasoning pipelines, trust readiness) produce **outcomes for the investigator** — neutral questions, clearer views, preparation guidance. They do not produce **new user-managed systems**. Presentation workspaces consume engine outputs; they never expose engine mechanics as concepts users must learn.

---

## Document Hierarchy

| Topic | Authoritative document |
|---|---|
| Platform engine architecture | **This document** — `PLATFORM_ARCHITECTURE.md` |
| Investigation pipeline and workflow | [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) |
| Bounded contexts and domain objects | [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) |
| Sprint implementation, repositories, wiring | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) |
| Investigation methodology and Product Journey | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) |
| Investigation Coaching philosophy | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#investigation-coaching-philosophy) |
| Simplicity Above Intelligence (DI-3.0) | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence) |
| Onboarding freeze | [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) |
| Engineering guardrails (DI-3.0) | [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) |
| Platform intelligence roadmap | [`ROADMAP.md`](ROADMAP.md) |
| Product rules and non-negotiables | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) |
| UX surfaces and navigation | [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) |

### Legacy engine name mapping

| DI-1.4 platform engine | Prior name in implementation docs |
|---|---|
| Capture Engine | *(capture path — previously implicit in Evidence Repository)* |
| Evidence Engine | Enrichment Engine |
| Relationship Engine | Relationship Engine *(unchanged)* |
| Narrative Engine | Story Engine |
| Trust Package Engine | Trust Engine |

When reading [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md), map prior four-engine terminology through this table.

---

*DI-3.1 — Onboarding freeze. Competitive advantage lives in investigation engines.*
