**Version:** 2.3  
**Status:** Implementation Architecture Reference  
**Last Updated:** August 4, 2026 (Permanent Product Rule — Onboarding Freeze)

> **Canonical platform engines (DI-1.4):** [`../PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) defines Capture, Evidence, Relationship, Narrative, and Trust Package engines plus Platform Services. This document retains sprint implementation detail and legacy four-engine naming (Enrichment, Story, Trust).

# Platform Architecture — Implementation Reference

This document defines the complete architecture of Evidence Vault as an **Incident Reconstruction Platform**. It describes how product modules connect, what each domain engine is responsible for, and the data model that powers them.

Evidence Vault is **not a storage application**. Its purpose is to help people preserve, enrich, connect, and understand moments that matter—ultimately reconstructing the truth behind an incident and producing trusted reports.

Application models, services, data stores, AI capabilities, and report generation must align with the definitions and rules stated here.

Related specifications:

- [`docs/INVESTIGATION_ENGINE.md`](INVESTIGATION_ENGINE.md) — reconstruction pipeline and workflow (DI-1.3)
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engine architecture (DI-1.4)
- [`docs/DOMAIN_MODEL.md`](DOMAIN_MODEL.md) — bounded contexts and domain object responsibilities (DI-1.2)
- [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) — Investigation Platform philosophy (DI-1.1)
- [`DEVELOPMENT_GUIDELINES.md`](../DEVELOPMENT_GUIDELINES.md) — onboarding freeze; investigation-first priorities
- [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) — product constitution
- [`docs/UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) — user experience specification
- [`docs/LANGUAGE_SYSTEM.md`](LANGUAGE_SYSTEM.md) — terminology and copy
- [`SPRINT_8.5_UX_REFINEMENT.md`](../SPRINT_8.5_UX_REFINEMENT.md) — post-baseline UX and domain refinements

**Everything in Evidence Vault revolves around one principle:**

**One Incident = One Truth Record.**

---

# Permanent Product Rule

## Onboarding is not the product.

Onboarding establishes trust, creates an account, and gets users into investigation as quickly as possible. It is **functionally complete**.

Evidence Vault's competitive advantage is created inside Capture, Organize, Investigation, Trust Package, and Investigation Coaching — not during account creation.

Do not redesign onboarding unless usability testing shows measurable friction, accessibility requirements change, or authentication architecture changes. Otherwise freeze onboarding and focus on investigation workflows.

Authoritative rule: [`../DEVELOPMENT_GUIDELINES.md`](../DEVELOPMENT_GUIDELINES.md).

**Decision filter:** Does this improve the investigation? If not, challenge whether it belongs.

---

## Core Platform Engines

Evidence Vault is powered by four domain engines. Together they implement the **Incident Reconstruction Platform**—measuring how well an incident has been reconstructed, not how many files have been collected.

```
Evidence Vault Core Platform
├── Enrichment Engine
├── Relationship Engine
├── Story Engine
└── Trust Engine
```

| Engine | Core question | Domain responsibility |
|---|---|---|
| **Enrichment Engine** | *How well is each piece of evidence supported?* | Determines evidence maturity; calculates Incident Status maturity; supplies enrichment status downstream |
| **Relationship Engine** | *How does evidence connect?* | Connects evidence items without modifying artifacts |
| **Story Engine** | *What happened?* | Builds the incident narrative from chain, enrichment, and relationships |
| **Trust Engine** | *Can this record be trusted and shared?* | Evaluates integrity; prepares the Trust Package |

These engines are **domain services**, not user-facing screens. User-facing modules (Library, Workspace, View Story, Trust Package) consume engine outputs through the presentation layer.

---

## Domain Hierarchy

The platform domain model is organised around reconstruction quality, not file quantity.

```
Incident
   ↓
Primary Evidence
   • Photo
   • Video
   • File
   • Witness
   ↓
Enrichment
   • Context
   • Voice Note
   • Text Note
   • Linked Evidence
   • Metadata
   • Tags
   • Location
   • Time clarification
   • AI Summary (future)
```

### Primary Evidence

**Primary evidence** represents the core incident records—the proof that something happened.

| Type | Role |
|---|---|
| **Photo** | Visual proof captured or imported |
| **Video** | Motion proof captured or imported |
| **File** | Imported document or attachment |
| **Witness** | Witness record as a core incident artifact |

Primary evidence is immutable after capture. It anchors the incident reconstruction.

### Enrichment

**Enrichment** is supporting information that helps another person understand the purpose of a primary evidence item.

| Enrichment type | Description |
|---|---|
| **Context** | Structured or narrative context attached to primary evidence |
| **Voice Note** | Spoken clarification linked to primary evidence |
| **Text Note** | Written clarification linked to primary evidence |
| **Linked Evidence** | Relationship-derived connection between evidence items |
| **Metadata** | Descriptive attributes that increase understanding |
| **Tags** | Classification labels applied without altering proof |
| **Location** | Geographic or place clarification |
| **Time clarification** | Temporal context that explains when relative to the incident |
| **AI Summary** *(future)* | System-generated summary; evidence-referenced and labeled |

**Terminology change (Sprint 8.5):** **Enrichment** is the umbrella concept. **Context** is one enrichment type among several—not the umbrella term for all supporting information. Manually entered context and linked supporting evidence count equally as enrichment.

Each primary evidence item exposes an enrichment status:

```
isEnriched = true | false
```

The Enrichment Engine evaluates this flag per primary item. Incident Status maturity is derived from enrichment across all primary evidence—not from evidence count alone.

---

## Platform Engine Interaction

Engines operate in a defined dependency order. Each engine consumes outputs from upstream engines and supplies structured status downstream.

```
Enrichment Engine
       ↓
Relationship Engine
       ↓
Story Engine
       ↓
Trust Engine
```

| Engine | Responsibility | Consumes | Produces |
|---|---|---|---|
| **Enrichment Engine** | Determines evidence maturity | Primary evidence, enrichments, relationship participation | Per-item `isEnriched`, Incident Status maturity, enrichment recommendations |
| **Relationship Engine** | Connects evidence | Evidence items within an incident | Bidirectional evidence relationships; link graph |
| **Story Engine** | Builds the incident narrative | Evidence Chain, enrichments, relationships, enrichment status | Timeline, Connections, Summary views |
| **Trust Engine** | Evaluates integrity and prepares sharing | Story synthesis, verification records, enrichment completeness | Trust Status, Trust Package assembly |

**Enrichment Engine → Relationship Engine:** Linked Evidence is an enrichment type resolved through the Relationship Engine. Enrichment status considers whether a primary item participates in meaningful links.

**Enrichment Engine → Story Engine:** Story synthesis weights narrative completeness using enrichment status—what is understood versus what remains raw.

**Enrichment Engine → Trust Engine:** Trust Package assembly receives enrichment completeness signals. Trust Packages remain available at every journey stage; enrichment status is advisory, never blocking.

**Relationship Engine → Story Engine:** Connections view and narrative cross-references derive from the relationship graph.

**Story Engine → Trust Engine:** Trust Package sections (Timeline, Summary, Connections) consume Story Engine outputs.

---

## 1. Enrichment Engine

The **Enrichment Engine** measures incident maturity by determining how well each primary evidence item has been supported.

### Purpose

Evidence Vault does not measure evidence quantity. It measures **reconstruction quality**—whether each core record has enough supporting information for another person to understand its purpose.

### Responsibilities

- Determine whether each primary evidence item is enriched (`isEnriched`)
- Calculate **Incident Journey** state from enrichment across all primary evidence
- Support future **AI enrichment** (summaries, inferred metadata, suggested tags) without UI state logic changes
- Provide **enrichment recommendations** (future)—guidance on what would strengthen reconstruction
- Supply enrichment status to the **Story Engine**
- Supply enrichment status to the **Trust Engine**

### Enrichment evaluation rules

| Signal | Counts as enrichment |
|---|---|
| Context attached to primary evidence | Yes |
| Voice Note linked to primary evidence | Yes |
| Text Note linked to primary evidence | Yes |
| Linked Evidence (via Relationship Engine) | Yes |
| Metadata, Tags, Location, Time clarification | Yes |
| AI Summary *(future)* | Yes — when evidence-referenced and labeled |
| Factory placeholders or capture defaults | No |
| Standalone supporting artifacts not linked to a primary | No — until attached |

All enrichment types count **equally**. No distinction is made between manually entered context and linked supporting evidence.

### Does not

- Modify captured evidence content, timestamps, or verification data
- Block Trust Package assembly at any journey stage
- Replace the Relationship Engine for link storage and resolution
- Require users to complete every enrichment type before progression

---

## 2. Relationship Engine

The **Relationship Engine** is the connective core of the platform. It connects evidence without modifying either artifact.

### Responsibility

- Accept a single user action: **Link Evidence**
- Store bidirectional relationships between evidence items without modifying either artifact
- Maintain relationship types **internally** — users never classify links manually
- Resolve **Linked Evidence** as an enrichment type for the Enrichment Engine
- Power all relationship-derived views: Connections, Evidence Map, Story synthesis, and Trust Package sections
- Support future AI inference of relationship types (Supports, Complements, References, Describes, Compares, Contradicts)

### Rules

- Relationships are **additive** — they never alter captured content, timestamps, or verification data
- Relationships exist **within one incident** — cross-incident linking requires explicit user intent
- Relationships may be established **at any time** — not required at capture
- Chronology (Evidence Chain) and relationships are **independent** — linking evidence never reorders the chain

**Time tells us when something happened. Relationships tell us why it mattered.**

The Relationship Engine preserves both.

---

## 3. Story Engine

The **Story Engine** builds the incident narrative. In the presentation layer this surfaces as **View Story**—the intelligence centre that answers: **“What happened?”**

### Responsibility

- Present multiple perspectives on the same underlying Evidence Chain, enrichments, and Relationship Engine graph
- Emphasise **chronology as narrative** — the authoritative timeline of the incident
- Consume enrichment status from the Enrichment Engine to reflect reconstruction completeness in narrative views
- Synthesise understanding without modifying preserved evidence

### Views (same underlying data)

| View | Purpose | Primary engine inputs |
|---|---|---|
| **Timeline** | Chronological reconstruction derived from the Evidence Chain | Evidence Chain |
| **Connections** | How evidence relates to other evidence | Relationship Engine |
| **Summary** | Narrative synthesis of the incident | Enrichment Engine + Relationship Engine + Evidence Chain |
| **Trust Status** | Incident-level verification and integrity assessment | Trust Engine (displayed in Story context) |

These are different **views of the same truth** — not separate data silos. Story is read-oriented. Capture and enrichment remain in the Workspace.

---

## 4. Trust Engine

The **Trust Engine** evaluates integrity and prepares the **Trust Package**—the platform's shareable trusted incident report.

### Responsibility

- Aggregate **Verification** and **Integrity** into incident-level **Trust Status**
- Consume enrichment completeness signals from the Enrichment Engine (advisory only)
- Assemble Trust Package sections from Story Engine outputs and verification records
- Maintain full **traceability** to source evidence and verification records
- Support export and sharing when the user is ready

### Typical Trust Package sections

| Section | Source engine |
|---|---|
| **Executive Summary** | Story Engine |
| **Timeline** | Story Engine (Evidence Chain) |
| **Evidence overview** | Primary evidence with verification metadata |
| **Connections** | Relationship Engine |
| **Trust Status** | Trust Engine |
| **Enrichment and annotations** | Enrichment Engine |
| **AI-assisted content** | Enrichment Engine *(future)* — always labeled as generated and evidence-referenced |

### Rules

- Trust Packages **never modify evidence**
- Trust Packages **only represent** what was preserved
- Available at **any journey stage** — the Incident Journey is advisory; it never blocks assembly
- AI-generated content must reference supporting evidence and express confidence where applicable

---

## Incident Status Model

**Incident Status** is the user-facing name for the workspace maturity indicator (formerly called Incident Journey in product copy). It visualises reconstruction progress within the Capture / Organize surfaces.

The official investigation workflow — **Capture → Organize → Investigation → Trust Package** — together represents the Incident Status lifecycle (methodology orientation). Separately, enrichment maturity still progresses EMPTY → BUILDING → RICH.

State progression for enrichment maturity is calculated by the **Enrichment Engine** from primary evidence enrichment status. It measures **reconstruction quality**, not evidence quantity.

| Stage | Definition | Enrichment condition |
|---|---|---|
| **EMPTY** | Raw evidence only | Primary evidence exists; **no** primary evidence is enriched |
| **BUILDING** | Reconstruction underway | **Some** primary evidence is enriched |
| **RICH** | Fully reconstructed incident | **Every** primary evidence item is enriched |

### Stage copy (canonical)

| Stage | Badge | Subtitle |
|---|---|---|
| **EMPTY** | EMPTY | Every library begins with one piece of truth. |
| **BUILDING** | BUILDING | Your truth is taking shape. |
| **RICH** | RICH | Your Library of Truth is ready. |

### Rules

- Adding primary evidence alone does **not** advance the journey beyond EMPTY
- Enrichment changes recalculate state **immediately** — no manual refresh
- Trust Package remains accessible in **every** state
- Incident Status guides quality; it **never blocks** the user

### Recalculation triggers

Incident Status maturity must recalculate whenever:

- Primary evidence is added or removed
- Enrichment is added, edited, or removed (context, voice note, text note, metadata, tags, location, time clarification)
- Relationships are created or removed (Linked Evidence enrichment)
- Witness records or witness-linked enrichment change
- Future AI enrichment is applied or withdrawn

---

## User-Facing Platform Flow

Evidence Vault is also organised as a linear **user experience flow**. Each module has a distinct responsibility. Data flows forward; understanding deepens at each stage.

```
Library of Truth
       ↓
Evidence Workspace
       ↓
View Story          ← powered by Story Engine
       ↓
Trust Package       ← powered by Trust Engine
```

| Module | Question it answers | Primary responsibility | Domain engines consumed |
|---|---|---|---|
| **Library of Truth** | *Where are my incidents?* | Long-term collection, browse, resume, and search | All engines (read-only summary) |
| **Evidence Workspace** | *What do I have?* | Capture evidence; display Incident Status | Enrichment Engine, Relationship Engine |
| **View Story** | *What happened?* | Intelligence centre — timeline, connections, summary, trust status | Story Engine, Trust Engine |
| **Trust Package** | *How do I share it?* | Shareable trusted incident report | Trust Engine, Story Engine, Enrichment Engine |

The flow is conceptual, not a rigid navigation lock. Users may enter at the Library and resume the Workspace, or open Story from the Workspace at any time. The architecture defines **ownership of responsibility**, not a single linear user path.

---

## Library of Truth

The **Library of Truth** is the user's long-term experience of Evidence Vault—the durable home for every incident they have preserved.

### Responsibility

- Present incidents as coherent truth records, not folders of files
- Support **browse**, **search**, and **resume** across the collection
- Surface incidents ready to continue building or ready to share
- Preserve history; the Library is an archive of reconstructed truth, not a file manager

### Does not

- Replace the Workspace for active capture and enrichment
- Display analytics dashboards or aggregate file counts as the primary experience
- Merge, link, or infer relationships between separate incidents automatically

The first captured evidence automatically creates an incident. There is no manual “Create Incident” step. Incidents enter the Library when created and remain accessible across their lifecycle.

---

## Evidence Workspace

The **Evidence Workspace** exists for one purpose: **Capture and build.**

### Responsibility

- Provide immediate access to capture (photo, video, voice, note, attachment, witness)
- Host **Incident Status** — driven by the Enrichment Engine
- Support progressive **Incident Title** naming without blocking capture
- Offer entry points to **View Story** and **Prepare Trust Package**
- Keep enrichment in the workflow — all enrichment types attach to primary evidence without leaving the workspace

### Essential components

| Component | Role | Engine |
|---|---|---|
| **Capture Evidence** | Preserve primary evidence at the moment it exists | — |
| **Incident Title** | Optional progressive naming | — |
| **Incident Status** | Visual maturity indicator; enrichment-driven | Enrichment Engine |
| **View Story** | Gateway to understanding | Story Engine |
| **Prepare Trust Package** | Gateway to sharing | Trust Engine |

### Does not

- Host analytics cards, metric dashboards, or file-manager patterns
- Hide evidence behind aggregate counters (“+5”, “3 preserved”)
- Emphasise chronology as narrative — that belongs in View Story
- Require categorisation or setup before capture
- Block Trust Package preparation based on journey stage

---

## Trust Architecture

Trust is communicated at the **incident level**, not as a per-file technical dump in the Workspace.

| Dimension | Measures | Engine |
|---|---|---|
| **Verification** | Documentation completeness — is the record attributable and complete? | Trust Engine |
| **Integrity** | Evidence authenticity — have preserved artifacts remained unaltered? | Trust Engine |

Individual evidence items store technical verification metadata (timestamps, hashes, device context). The Trust Engine aggregates and presents **Trust Status** for the incident as a whole in View Story and Trust Package.

Enrichment completeness (from the Enrichment Engine) informs narrative and Trust Package advisory sections but does not replace Verification or Integrity assessment.

---

## Platform Data Model

The following sections define the business objects, rules, and relationships that power the platform engines and user-facing modules. Implementation in application code, data stores, and services must conform to these definitions.

---

### Core Objects

| Object | Responsibility |
|---|---|
| **Incident** | Highest-level container for one truth record |
| **Primary Evidence** | Core incident record (Photo, Video, File, Witness) |
| **Enrichment** | Supporting information attached to primary evidence |
| **Evidence Chain** | Immutable chronological timeline within an incident |
| **Evidence Relationship** | Bidirectional link between evidence items — Relationship Engine |
| **Evidence Map** | Visual representation of relationships |
| **Verification Record** | Automatic integrity and attribution metadata |
| **Trust Package** | Generated shareable report — Trust Engine output |
| **User** | Owner of incidents, evidence, preferences, security, and sharing permissions |

---

### Incident

An **Incident** is the root object. It represents one truth record—a bounded reconstruction of what happened, supported by primary evidence, enrichment, relationships, chronology, and trust signals.

**Business rules:**

- Automatically created when the first primary evidence is captured
- Never manually instantiated as an empty container
- Never merged or linked to other incidents automatically
- Cannot be deleted after first evidence; may be **archived**
- One incident equals one truth record

**Lifecycle (operational status):**

| Status | Description |
|---|---|
| **Draft** | Created by first capture; open for enrichment |
| **Active** | Actively being documented |
| **Paused** | Suspended; resumable without loss |
| **Finalized** | Core evidence and chronology locked for intended purpose |
| **Archived** | Long-term preservation in the Library of Truth |

**Key attributes:** Incident ID, Title, Category, Status, Journey Stage (derived), Created At, Updated At, Finalized At, Archived At, Owner, Trust Status (Verification + Integrity aggregate).

**Journey Stage** is a **derived attribute** calculated by the Enrichment Engine. It is not stored as user-editable state.

---

### Primary Evidence

A **primary evidence** item is a core incident record. Immutable after capture.

| Type | Description |
|---|---|
| **Photo** | Still image captured or imported |
| **Video** | Motion recording captured or imported |
| **File** | Imported file (PDF, image, document, spreadsheet, etc.) |
| **Witness** | Witness record preserved as a core incident artifact |

**Required fields:** Evidence ID, Incident ID, Type, Captured At, Created By, Metadata, Verification reference, Enrichment collection, `isEnriched` (derived).

**Rules:**

- Never exists without an Incident
- Cannot belong to multiple incidents
- Original content and capture metadata are never altered
- First capture automatically creates the parent incident
- Enrichment status is derived by the Enrichment Engine—not manually set

---

### Enrichment

**Enrichment** objects attach to exactly one primary evidence item. They increase understanding without modifying proof.

| Type | Description |
|---|---|
| **Context** | Structured or narrative context |
| **Voice Note** | Spoken clarification |
| **Text Note** | Written clarification |
| **Linked Evidence** | Relationship resolved via Relationship Engine |
| **Metadata** | Descriptive attributes |
| **Tags** | Classification labels |
| **Location** | Geographic or place clarification |
| **Time clarification** | Temporal context |
| **AI Summary** *(future)* | Evidence-referenced generated summary |

**Rules:**

- Additive only — never modifies primary evidence content, capture time, or verification data
- All enrichment types count equally toward `isEnriched`
- Context is one enrichment type—not an umbrella for all supporting information
- Linked Evidence enrichment is resolved through the Relationship Engine

---

### Evidence Lifecycle

Each primary evidence item progresses through:

```
Captured → Verified → Enriched → Referenced → Reported → Preserved
```

| Stage | Description | Engine |
|---|---|---|
| **Captured** | Recorded or imported with automatic metadata | — |
| **Verified** | Integrity and attribution checks applied automatically | Trust Engine |
| **Enriched** | Supporting information attached — additive only | Enrichment Engine |
| **Referenced** | Cited in narrative, timeline, or cross-references | Story Engine |
| **Reported** | Appears in Trust Package sections with full traceability | Trust Engine |
| **Preserved** | Stored long-term within the Library of Truth | — |

---

### Evidence Chain

The **Evidence Chain** is the immutable chronological timeline of evidence within an incident.

**Answers:** *“What happened, and in what order?”*

- Preserves capture sequence; never reordered or reduced
- Every captured item automatically joins the chain
- Supplementary enrichment appears in context of its primary evidence, not as a substitute for chronology
- Supporting items store `parentEvidenceId` + `relationshipType` (`supports` by default) for chain traversal, AI reasoning, narrative reconstruction, and Trust Package assembly
- Capture / Organize journey connectors: **orange** = primary chronology (Photo / Video / Voice); **blue** = supporting enrichment (Note / File)
- Unique per incident; powers Timeline in View Story (Story Engine)

---

### Evidence Relationships

Stored and resolved by the **Relationship Engine**. Bidirectional links that preserve how evidence connects without modifying any item.

**Examples:**

- A text note enrichment explains a photo
- A photo validates an earlier witness record
- A file supports a voice note enrichment

**Rules:** additive, bidirectional, within-incident, established at any time. Users perform one action — **Link Evidence** — without selecting relationship types.

Participation in a relationship may satisfy **Linked Evidence** enrichment for the Enrichment Engine.

---

### Evidence Map

Visual representation of Evidence Relationships within the Workspace and review surfaces.

**Answers:** *“How are these pieces of evidence connected?”*

- Derived from the Relationship Engine — presentation layer, not source of truth
- Does not replace the Evidence Chain
- Updates when relationships change; never reorders evidence

| Concept | Answers | Nature |
|---|---|---|
| **Evidence Chain** | What happened, and in what order? | Immutable chronology |
| **Evidence Relationships** | How do items connect? | Relationship Engine data |
| **Evidence Map** | How are items connected visually? | Derived presentation |
| **Enrichment status** | How well is each primary supported? | Enrichment Engine (derived) |

---

### Verification Record

Automatic verification at capture or import. Users never manually enter verification data.

| Element | Description |
|---|---|
| **Timestamp** | Date, time, timezone |
| **GPS** | Location and accuracy where permitted |
| **Device Information** | Attribution context |
| **File Hash** | Integrity verification |
| **Capture Method** | Camera, microphone, import, text entry |
| **Platform / App Version** | Recording environment |
| **Verification Status** | Outcome for the evidence item |

Verification data supports incident-level **Trust Status — Verification** (Trust Engine).

---

### Trust Package (generated artifact)

A **Trust Package** is the structured output of the **Trust Engine**—derived from an incident's Evidence Chain, Relationship Engine graph, enrichment summary, verification records, and Trust Status. It serves presentation and sharing; it is not a source of truth.

Replaces the legacy term *Professional Report* in all new implementation and documentation within this architecture.

---

### User

Authenticated account owning incidents and evidence.

**Responsibilities:** authentication, ownership, preferences, security, subscription entitlements, privacy and sharing controls.

---

### Object Relationships

```
User
  ↓ owns
Incident
  ↓ contains
Primary Evidence
  ↓ enriched by
Enrichment (Context · Voice Note · Text Note · Linked Evidence · Metadata · Tags · Location · Time · AI Summary)
  ↓ evaluated by
Enrichment Engine → Incident Status maturity · isEnriched per primary
  ↓ ordered in
Evidence Chain
  ↓ linked by
Relationship Engine (Evidence Relationships · Linked Evidence enrichment)
  ↓ visualized as
Evidence Map
  ↓ verified by
Verification Record (per evidence item) → Trust Engine
  ↓ understood through
Story Engine (Timeline · Connections · Summary · Trust Status display)
  ↓ shared as
Trust Engine output (Trust Package)
  ↓ preserved in
Library of Truth
```

| Relationship | Description |
|---|---|
| **User owns Incident** | One owner; establishes access and responsibility |
| **Incident contains Primary Evidence** | Core records anchor reconstruction |
| **Primary Evidence receives Enrichment** | Additive supporting information |
| **Enrichment Engine evaluates Primary Evidence** | Derives `isEnriched` and Journey Stage |
| **Incident contains Evidence Chain** | Chronological ordering of captured items |
| **Relationship Engine links evidence items** | Bidirectional, additive, within incident |
| **Evidence Map visualizes relationships** | Derived; does not replace chain |
| **Verification belongs to evidence items** | Automatic at capture; Trust Engine aggregates |
| **Story Engine represents Incident** | Read-only intelligence views |
| **Trust Engine produces Trust Package** | Generated output; never alters evidence |
| **Library preserves Incidents** | Long-term archive across lifecycle states |

---

### Business Rules

| Rule | Statement |
|---|---|
| **One Incident = One Truth Record** | Bounded record; not combined by default |
| **Evidence creates Incident** | First capture creates the incident |
| **Primary evidence requires Incident** | Every primary item references exactly one incident |
| **Evidence is immutable** | Original capture is never altered |
| **Enrichment surrounds evidence** | Supporting information adds meaning without replacing proof |
| **Context is one enrichment type** | Enrichment is the umbrella; context is not |
| **Link, don't classify** | Users link evidence; relationship types are internal |
| **Enrichment is additive** | Enrichment never replaces proof |
| **Verification is automatic** | System-captured; not user-entered |
| **Chronology is preserved** | Evidence Chain order is never rewritten |
| **Journey measures reconstruction** | Incident Journey reflects enrichment, not file count |
| **Journey never blocks sharing** | Trust Package available at every stage |
| **Incidents are never linked automatically** | Similarities may be suggested; never auto-linked |
| **AI never changes evidence** | Assists only; evidence-bound and explainable |
| **Trust Package never changes evidence** | Read-only representation |
| **Nothing is silently deleted** | Archive; auditable actions only |

---

### Future Platform Objects

Reserved for expansion beyond the current release. Not active in initial implementation.

| Future Object | Intended Purpose | Engine |
|---|---|---|
| **Enrichment Recommendation** | Suggested next enrichment actions per primary evidence | Enrichment Engine |
| **AI Observation** | System-generated observations, evidence-referenced and confidence-scored | Enrichment Engine |
| **Incident Reconstruction (derived)** | Visual or narrative reconstruction from evidence, clearly labeled as interpretive | Story Engine |
| **Similarity Analysis** | Possible cross-incident similarities for user review — not automatic linking | Relationship Engine |
| **Collaboration** | Multi-user documentation within defined roles | Platform services |
| **Secure Sharing** | Controlled disclosure to third parties | Trust Engine |
| **Legal Hold** | Compliance preservation constraints | Trust Engine |
| **Organization** | Enterprise container above individual users | Platform services |
| **Cross-Incident Collections** | Curated groupings for analysis or export without merging truth records | Platform services |

---

## Sprint 9.0 — Domain Consolidation (Frontend)

Sprint 9.0 introduces the **Incident aggregate root** and normalizes evidence ownership in `lib/domain/` without UI changes. Presentation layers consume projected DTOs (`WorkspaceEvidenceItem`, `ReflectionModel` alias).

### Domain hierarchy

```
Incident
  ├── TimelineAnchor (immutable order — one per CapturedEvidence)
  ├── CapturedEvidence (immutable: Photo, Video, Voice)
  ├── SupportingEvidence (flexible: Notes, PDF, Documents, Attachments, Witness Statements)
  ├── RelationshipGroup (incident-owned; memberEvidenceIds)
  └── ReconstructionNote (domain successor to Reflection)
```

### Repository ownership

| Repository | Owns |
|---|---|
| `IncidentRepository` | Incident lifecycle (title, completion) |
| `EvidenceRepository` | Captured + supporting evidence persistence |
| `TimelineRepository` | TimelineAnchor ordering |
| `RelationshipRepository` | Relationship groups + evidence links |
| `ReconstructionRepository` | Reconstruction notes |
| `WorkspaceCoachingService` | Derived coaching copy (independent) |

### Evidence pipeline

```
Capture → Persist (EvidenceRepository) → Project (EvidenceProjection) → Reconstruct (Story/Trust engines)
```

`WorkspaceEvidenceController` delegates to `IncidentAggregate`. Legacy `WorkspaceEvidenceState` is projected on read. `WorkspaceStateMigration` converts existing in-memory incidents automatically.

---

## Sprint 9.1 — Timeline Workspace

The **Timeline Workspace** is the first dedicated Incident Reconstruction workspace. It is a read-only pushed route — not embedded in the Incident Workspace.

### Reconstruction workspaces

```
Incident Workspace (capture + coaching)
   ↓
Timeline Workspace      — "What happened, and in what order?"
Connections Workspace   — relationship groups (Sprint 9.x)
Reconstruction Workspace — meaning and notes (Sprint 9.x)
```

### Data flow

```
IncidentAggregate
   ↓
TimelineRepository.orderedCapturedEvidenceIds()
   ↓
TimelineAnchor (immutable capture order — anchoredAt)
   ↓
CapturedEvidence (Photo, Video, Voice)
   ↓
SupportingEvidence (attached beneath anchor — Notes, PDF, Witness, etc.)
   ↓
Evidence Record (tap to open — read-only from Timeline)
```

Supporting evidence **does not** create timeline anchors. Chronology is determined exclusively by anchor sequence and original capture timestamps — never by `lastPreservedAt` sorting or UI reordering.

Centralized read logic lives in `WorkspaceEvidenceRepository.anchoredTree()`. The Timeline Workspace consumes `WorkspaceEvidenceController.anchoredTimeline` — no duplicate timeline ordering in widgets.

### Filters

Timeline filters (All, Photos, Videos, Voice, Documents, Notes, Witness) affect **visibility only**. Anchor order never changes when a filter is applied.

---

## Sprint 9.2 — Connections Workspace

The **Connections Workspace** is the second dedicated Incident Reconstruction workspace. It is the **only** place where relationship editing is permitted.

### Relationship ownership

```
IncidentAggregate
   ↓
RelationshipRepository
   ↓
RelationshipGroup (memberEvidenceIds, stable colorIndex)
   ↓
EvidenceRepository (captured + supporting members)
```

Centralized group presentation lives in `WorkspaceEvidenceRepository.connectionGroupNodes()`. Captured evidence within a group follows `TimelineRepository` order; supporting evidence nests beneath linked captured anchors.

### Modes

| Mode | Behaviour |
|---|---|
| **View** (default) | Read-only inspection, expand/collapse groups, open Evidence Record |
| **Organize** | Move supporting evidence between groups, remove from group, merge, split, delete empty groups, create groups |

**Captured evidence never moves.** Chronology remains owned by the Timeline Workspace.

### Organize actions

- `moveSupportingToGroup` — supporting evidence only
- `removeSupportingFromGroup`
- `mergeGroups` — preserves target group colour
- `splitGroup` — supporting evidence into a new group
- `deleteEmptyGroup`
- `commitRelationshipGroup` — create new groups from Organize mode

Relationship editing was removed from the Incident Workspace (legacy Connect Mode).

### Named groups (Sprint 9.2.1)

Each [RelationshipGroup] carries an optional `displayName` persisted by [RelationshipRepository]. When empty, UI resolves to `Group N` by creation order. Investigators rename groups inline from the Connections Workspace header (max 40 characters, trimmed, duplicates allowed). Colours remain the primary visual identifier; names capture investigative meaning for future Reconstruction Workspace section headings.

### Investigative metadata (Sprint 9.2.2)

Relationship Groups are first-class investigative entities. Each group persists optional `displayName` and `description` fields owned exclusively by [RelationshipRepository]. The Connections Workspace exposes an inline **Edit** action on each group header — no modal — for name (max 40 characters) and reasoning description (max 200 characters, optional, hidden when empty). Existing groups migrate with default `Group N` labels and empty descriptions. These fields will feed Reconstruction Workspace section headings and investigator reasoning in Sprint 9.3.

### Confidence indicator (Sprint 9.2.3)

Each relationship group displays a derived **Confidence** coaching indicator beneath the header (`Low`, `Medium`, `High`). [RelationshipGroupConfidenceService] computes this from member count, evidence-type diversity, contextual enrichment, primary enrichment, and supporting evidence attachment. It is never persisted and recomputes whenever group membership or enrichment changes. This measures investigative completeness, not evidentiary truth.

---

## Sprint 9.3.1 — Reconstruction Canvas

The **Reconstruction Canvas** is the flagship investigative workspace. It unifies Timeline, Connections, and Narrative into one synchronized experience without duplicating workspace logic.

### Composition

```
ReconstructionCanvasScreen
├── ReconstructionCanvasHeader (incident stats)
├── ReconstructionCanvasSegmentBar (Timeline | Connections | Narrative)
└── IndexedStack
    ├── TimelineWorkspaceList (reused, read-only)
    ├── ConnectionsWorkspaceBody (reused, organize mode preserved)
    └── StructuredNarrativeBuilder (Sprint 9.3.2)
```

### Shared selection state

[InvestigationCanvasState] is the single source of truth for cross-segment selection in the Reconstruction Canvas:

| Field | Purpose |
|---|---|
| `selectedTimelineAnchorId` | Active captured anchor |
| `selectedRelationshipGroupId` | Active relationship group |
| `selectedNarrativeSectionId` | Active narrative section |
| `selectedEvidenceId` | Evidence Inspector target |

[InvestigationCanvasController] owns session state and notifies listeners. [InvestigationCanvasSyncEngine] propagates selection bidirectionally so choosing an anchor, group, or narrative section highlights corresponding evidence across all segments. State is never persisted.

### Evidence Inspector

Selecting evidence opens a lightweight bottom-sheet inspector (not full-screen Evidence Record). It shows thumbnail, type, capture time, device, location, context, relationship groups, and a quick action to open the full record without leaving the canvas.

### Data ownership

The canvas consumes [IncidentAggregate] through [WorkspaceEvidenceController]. Timeline ordering, relationship groups, and reconstruction notes are never duplicated.

---

## Sprint 9.3.1A — Unified Investigation Synchronization

Sprint 9.3.1A enhances the Reconstruction Canvas with a shared synchronization engine. It does **not** redesign Timeline, Connections, or Narrative — it wires them together as one investigative surface.

### Synchronization engine

```
InvestigationCanvasController (ChangeNotifier)
        ↓
InvestigationCanvasSyncEngine
        ↓
TimelineWorkspaceList | ConnectionsWorkspaceBody | StructuredNarrativeBuilder
```

[InvestigationCanvasSyncEngine] computes both next state and highlight sets:

| Selection source | Timeline | Connections | Narrative |
|---|---|---|---|
| Timeline anchor | Selected anchor | Member group | Sections referencing anchor |
| Relationship group | Captured anchors in group | Selected group | Sections referencing group |
| Narrative section | Referenced anchors | Referenced groups | Selected section |

[InvestigationNarrativeReferenceResolver] resolves note → anchor/group references from note title and body text against evidence titles and IDs.

### Visual language

[InvestigationSelectionVisuals] defines one consistent selection animation (`AppMotion.medium` / `AppMotion.enter`):

| Segment | Highlight |
|---|---|
| Timeline | Subtle blue outline on captured anchors |
| Connections | Existing group colour with stronger border |
| Narrative | Blue left border on section cards |

### Performance

`ReconstructionCanvasScreen` uses `ListenableBuilder` on the canvas controller so segment bar and `IndexedStack` children rebuild only when selection changes — not the full canvas chrome. Individual widgets use `RepaintBoundary` and `AnimatedContainer` for localized highlight updates.

### Evidence Inspector (enhanced)

[EvidenceInspectorPanel] displays thumbnail, evidence type, capture time, device, location, context, relationship groups, and **Open Full Evidence Record**. The inspector opens as a bottom sheet and does not navigate away from the Reconstruction Canvas.

### Backward compatibility

[ReconstructionCanvasState] and [ReconstructionCanvasSyncService] remain as deprecated aliases delegating to the investigation types.

---

## Sprint 9.3.2A — Structured Narrative Builder (Phase 1)

Phase 1 delivers the production narrative structure: evidence-backed events, inline editing, confidence badges, and traceability. **Deferred to Sprint 9.3.2B:** drag-and-drop reordering, live canvas synchronization, AI generation, and automatic narrative writing.

### Core principle

The narrative answers **“What happened?”** Every event must remain explainable through evidence. Investigators never begin with a blank document.

### NarrativeEvent

[NarrativeEvent] (`lib/domain/reconstruction/narrative_event.dart`) persists:

| Field | Purpose |
|---|---|
| `sortOrder` | Narrative sequence (timeline order in Phase 1) |
| `title` | Inline-renameable event name (`Event N` default) |
| `summary?` | Optional investigator explanation (max 500 chars) |
| `timelineAnchorEvidenceId` | Primary anchor reference |
| `relationshipGroupIds` | Traceability — never duplicated |
| `reconstructionNoteIds` | Linked note references |
| `supportingEvidenceIds` | Supporting evidence references |

### Initial narrative

On first open, [NarrativeEventRepository.ensureInitialStructure] creates one placeholder event per timeline anchor. No text is generated.

### NarrativeBuilder

[DefaultNarrativeBuilder] projects the incident aggregate into [NarrativeEventViewModel] read models — narrative events are projections, never duplicated domain objects.

### Narrative Confidence

[NarrativeEventConfidenceService] derives confidence badges (never persisted):

- 🟢 High / 🟡 Medium / 🔴 Low — inherited from linked [RelationshipGroupConfidenceService] results (lowest linked group wins)
- **Supported by** breakdown by evidence type (📷 Photos, 🎥 Videos, 👤 Witnesses, etc.)

This is an investigation completeness indicator, not legal certainty.

### UI (Phase 1)

| Widget | Role |
|---|---|
| [StructuredNarrativeBuilder] | Scrollable event list in Reconstruction Canvas Narrative segment |
| [NarrativeBuilderHeader] | Incident name, event/anchor/group counts, `N of N Events Created` progress |
| [NarrativeEventCard] | Inline title + summary, confidence badge, evidence thumbnails |

Evidence thumbnail tap → [EvidenceInspectorPanel] (no navigation away).

### Performance

Each [NarrativeEventCard] uses [RepaintBoundary]. Editing one event does not rebuild the full narrative.

### Sprint 9.3.2B (planned)

- ~~Drag-and-drop event reordering~~ → audit-friendly **Move Up / Move Down / Insert Before / Insert After** (Sprint 9.3.2B)
- ~~Live investigation canvas synchronization for narrative selection~~ (Sprint 9.3.2B)
- AI-assisted narrative generation

---

## Sprint 9.3.2B — Live Narrative Synchronization & Narrative Ordering

Sprint 9.3.2B completes the Structured Narrative Builder as a **live projection** of the incident aggregate.

### Live synchronization

[NarrativeEventRepository.refreshReferences] updates evidence references, relationship group IDs, and supporting evidence whenever the incident changes. Investigator-authored **title** and **summary** are never overwritten (`titleCustomized` / `summaryCustomized` flags).

New timeline anchors automatically append a placeholder `Event N`. Missing anchor evidence displays **Referenced evidence removed.** while preserving investigator summaries.

### Narrative ordering

Audit-friendly ordering via [NarrativeEventRepository]:

- Move Up / Move Down
- Insert Before / Insert After

Narrative order is independent of timeline chronology.

### Canvas synchronization

[NarrativeEventCard] rejoins [InvestigationCanvasSyncEngine] — selecting an event highlights its timeline anchor and relationship groups across canvas segments.

### Confidence & evidence

[NarrativeEventConfidenceService] recalculates on every projection rebuild when evidence, context, or relationship groups change. Evidence thumbnails update automatically; taps open [EvidenceInspectorPanel].

---

## Sprint 9.3.3 — Narrative Validation Engine

Sprint 9.3.3 replaces confidence badges with a **Narrative Validation Engine** that continuously evaluates evidence completeness and coaches investigators toward stronger reconstructions.

### Core principle

Evidence Vault never decides what happened. Validation measures **completeness only** — not truth, not legal certainty, and not AI interpretation.

### NarrativeValidationService

[NarrativeValidationService] (`lib/services/narrative_validation_service.dart`) computes validation dynamically on every projection rebuild. Nothing is persisted.

**Inputs**

| Input | Source |
|---|---|
| Timeline anchors | [NarrativeEventViewModel.anchorNode] / display evidence |
| Relationship groups | Linked groups for traceability context |
| Evidence | Primary + supporting evidence references |
| Context | Event summary, reconstruction notes, contextual evidence |

**Outputs**

| Output | Purpose |
|---|---|
| [NarrativeEventValidation] | Per-event 🟢/🟡/🔴 status, Supported by breakdown, coaching recommendations |
| [NarrativeReconstructionHealth] | Workspace-level Excellent / Needs Review / Incomplete |
| Narrative Coverage | e.g. `7 of 8 Narrative Events sufficiently supported` |

### Validation rules (heuristic)

| Status | Completeness signals |
|---|---|
| 🟢 High | Multiple primary evidence, context present, multiple evidence types, supporting evidence, witness present |
| 🟡 Medium | Two or more evidence items with partial context or supporting evidence; missing one important category |
| 🔴 Low | Single evidence item, no context, no supporting evidence, or missing anchor |

### Smart recommendations

Coaching messages only — never interpret what happened:

- Missing witness statement
- Missing contextual explanation
- Only one primary evidence captured
- Consider attaching supporting document
- Voice note has no context
- Capture additional evidence

### UI

| Widget | Role |
|---|---|
| [NarrativeBuilderHeader] | Reconstruction Health + Narrative Coverage at workspace top |
| [NarrativeValidationSummary] | Per-event Supported by + Recommendation panel beneath title |
| [NarrativeEventCard] | Validation colour emoji prefix on title, live updates on evidence/context changes |

### Live updates

Validation recomputes whenever context, evidence, or relationship references change via [DefaultNarrativeBuilder] projection rebuilds — the same path used for live narrative sync in Sprint 9.3.2B.

---

## Sprint 9.3.4 — Investigation Workspace Navigation

Sprint 9.3.4 transforms Timeline, Connections, and Reconstruction into a **single Investigation Workspace**. The three workspaces are not separate features — they are synchronized perspectives of one investigation.

### Product principle

Users are not changing screens. They are changing perspectives:

| Workspace | Question |
|---|---|
| **Timeline** | When did it happen? |
| **Connections** | What belongs together? |
| **Reconstruction** | What happened? |

### InvestigationWorkspaceScreen

[InvestigationWorkspaceScreen] (`lib/screens/investigation_workspace_screen.dart`) is the parent surface. Legacy [ReconstructionCanvasScreen] delegates to it.

```
InvestigationWorkspaceScreen
├── InvestigationHeader (shared across all tabs)
├── InvestigationWorkspaceTabBar (Timeline | Connections | Reconstruction)
└── InvestigationWorkspaceTabStack (state-preserving cross-fade)
    ├── TimelineWorkspace
    ├── ConnectionsWorkspace
    └── ReconstructionWorkspace
```

Each child workspace consumes the shared [InvestigationCanvasState] via [InvestigationCanvasController].

### Shared Investigation Header

[InvestigationHeader] displays identical context on every tab:

- Incident Name
- Journey Status
- Timeline Anchor Count
- Relationship Group Count
- Narrative Event Count
- Overall Reconstruction Health (+ narrative coverage)

Per-workspace headers are suppressed when embedded in the Investigation Workspace.

### State preservation

[InvestigationWorkspaceTabStack] keeps all three workspaces mounted. Tab switches cross-fade without rebuilding the incident aggregate. Scroll positions use `PageStorageKey` values; selections (timeline anchor, relationship group, narrative event, evidence inspector target) persist across tab changes.

### Unified Evidence Inspector

One [EvidenceInspectorPanel] serves the entire Investigation Workspace. Evidence taps in any tab open the same inspector and sync selection through [InvestigationCanvasSyncEngine].

### Navigation

[AppNavigation.openInvestigationWorkspace] is the primary entry point. Hub CTAs for Timeline, Connections, and Reconstruction open the Investigation Workspace on the corresponding initial tab. Standalone workspace screens remain for read-only or legacy flows.

---

## Sprint 9.4.1 — Trust Package Domain Model

Sprint 9.4.1 introduces the canonical **Trust Package** domain aggregate — the authoritative investigation artifact from which all future outputs (PDF, print, secure share, legal bundle) will be derived.

### Core principle

The Trust Package is generated entirely from the [IncidentAggregate]. It never duplicates evidence, never embeds media, and never mutates the incident. There is exactly one source of truth: the Incident Aggregate.

### TrustPackage aggregate

[TrustPackage] (`lib/domain/trust_package/trust_package.dart`) is an immutable projection with seven sections:

```
TrustPackage
├── TrustPackageIncidentSummary
├── TrustPackageInvestigationSummary
├── TrustPackageTimelineSection
├── TrustPackageRelationshipGroupsSection
├── TrustPackageReconstructionSection
├── TrustPackageEvidenceAppendix
├── TrustPackageIntegritySummary
└── TrustPackageMetadata
```

| Section | Contents |
|---|---|
| **Incident Summary** | Name, type, status, created/updated dates, investigator (reserved), investigation confidence, reconstruction health |
| **Investigation Summary** | Factual counts only — anchors, groups, narrative events, primary/supporting evidence, context, witnesses, documents |
| **Timeline Section** | Immutable chronology from [TimelineAnchor] — timestamp, title, related evidence IDs, relationship group IDs |
| **Relationship Groups** | Colour, name, supporting evidence IDs, connected timeline anchor IDs, confidence level |
| **Reconstruction** | Narrative event title, summary, evidence reference IDs, confidence, validation status |
| **Evidence Appendix** | Per-artifact references — ID, type, timestamp, device, location, context, group IDs |
| **Integrity Summary** | Evidence count, timeline/relationship integrity, missing references, validation status |
| **Metadata** | Package version, generated timestamp (from incident `updatedAt`), generated by, incident version, trust package ID |

### TrustPackageAssembler

[DefaultTrustPackageAssembler] (`lib/domain/trust_package/trust_package_assembler.dart`) consumes [IncidentAggregate] and produces [TrustPackage].

- Deterministic — same aggregate always yields the same package
- Read-only — no repository mutations
- Reuses [DefaultNarrativeBuilder], [NarrativeValidationService], and [RelationshipGroupConfidenceService] for derived coaching fields

Legacy [TrustPackageModel] / [DefaultTrustPackageBuilder] remain for existing UI preview until Sprint 9.4.2 migrates presentation to the domain aggregate.

### Reference model

All sections store **IDs and factual metadata only**. Evidence files, thumbnails, and media bytes are never copied into the Trust Package.

---

## Sprint 9.4.2 — Trust Package Preview & Renderer

Sprint 9.4.2 delivers the first read-only **Trust Package Preview** experience — a professional document-style presentation layer generated exclusively from [TrustPackage].

### Core principle

The Trust Package answers: *If I handed this to another person, would they understand what happened?* It is not a PDF viewer. It is the canonical presentation layer for future PDF, print, secure share, and archive outputs.

### TrustPackagePreview

[TrustPackagePreview] (`lib/widgets/trust_package/preview/trust_package_preview.dart`) consumes **only** [TrustPackage]. It never reads [IncidentAggregate] directly.

Document section order:

1. Cover Page
2. Executive Summary
3. Investigation Quality (Trust Scorecard)
4. Chronological Timeline
5. Relationship Groups
6. Reconstruction Narrative
7. Evidence Appendix
8. Integrity Report

### Trust Scorecard

[TrustPackageScorecardService] derives investigation quality indicators and an overall rating (Excellent / Good / Needs Review / Incomplete) from the domain package only. No percentages.

### Navigation

[TrustPackagePreviewNavigation] provides sticky section jumps (vertical panel on wide layouts, horizontal chips on compact layouts).

### Evidence inspection

Evidence appendix taps invoke [EvidenceInspectorPanel] at the screen boundary via evidence ID resolution — the renderer emits IDs only; the screen resolves inspector context.

### Screen

[TrustPackageScreen] hosts the preview workspace. [AppNavigation.openTrustPackage] opens the preview using [WorkspaceEvidenceController.canonicalTrustPackage].

---

## Sprint 9.4.3 — Trust Package Export & Secure Sharing

Sprint 9.4.3 enables investigators to export, print, archive, and securely share a completed Trust Package without modifying the Investigation Workspace or the domain aggregate.

### Core principle

The Trust Package is complete. Export pipelines are isolated presentation outputs that consume [TrustPackage] only — never [IncidentAggregate]. Every exported artifact remains a faithful, traceable representation of the domain package.

### Export pipeline

[TrustPackageExportService] (`lib/services/trust_package/trust_package_export_service.dart`) orchestrates export formats through an extensible [TrustPackageExportFormat] enum (PDF, Archive). Additional formats can register without changing the domain model.

| Format | Output | Notes |
|---|---|---|
| **PDF** | `{IncidentName}_TrustPackage_v1_YYYYMMDD.pdf` | Professional report via [TrustPackagePdfRenderer] |
| **Archive** | `{IncidentName}_TrustPackage_v1_YYYYMMDD.zip` | Immutable snapshot: manifest, JSON snapshot, embedded PDF |

[TrustPackageFilenameService] standardises filenames. [TrustPackageExportMetadata] embeds trust package ID, version, generated timestamp, incident version, and generated by in every export. PDF document properties and cover-page metadata block carry the same fields.

PDF section order (matches canonical report):

1. Cover Page (+ export metadata)
2. Executive Summary
3. Chronological Timeline
4. Relationship Groups
5. Reconstruction Narrative
6. Evidence Appendix
7. Integrity Report
8. Integrity Notice (final page)

Page numbering and section headings are preserved. Evidence references remain textual — media is never embedded, consistent with the domain reference model.

### Print pipeline

[TrustPackagePrintService] renders the PDF layout through the `printing` package for A4 output. [TrustPackagePrintScreen] provides a print-friendly preview: navigation hidden, minimal controls, optimised document spacing via [TrustPackagePreview] `printLayout` mode.

### Archive model

[TrustPackageArchiveRecord] (`lib/models/trust_package_archive_record.dart`) stores immutable snapshots linked to the originating incident via [TrustPackageArchiveStore]. Each archive records package version, generated date, generated by, archive date, and the frozen [TrustPackage] snapshot reference.

Archive ZIP manifest includes SHA-256 hashes for PDF and JSON snapshot integrity verification.

### Secure share model

[TrustPackageShareService] (`lib/services/trust_package/trust_package_share_service.dart`) implements a lightweight secure sharing framework designed for future authentication:

- Unique package ID (UUID)
- Optional expiry date
- Optional view-only mode
- Recipient notes
- Share URL scaffold (`https://evidencevault.app/share/...`)

[TrustPackageShareStore] registers links locally. [TrustPackageShareSheet] captures share settings and distributes link details via the platform share sheet.

### UI

[TrustPackageExportActions] adds an Export button to [TrustPackageScreen]. Options: Export PDF, Print, Archive Snapshot, Create Secure Share Link. Archived snapshots for the current incident appear in the export sheet.

### Integrity notice

Every PDF ends with an **Integrity Notice** stating the package was generated directly from the Incident Aggregate and that Evidence Vault does not alter investigator observations ([TrustPackageExportMetadata.integrityNoticeBody]).

---

## Sprint P1 — MVP Privacy Controls

Sprint P1 delivers the minimum privacy controls required for MVP: **Delete Account** and **Clear Vault**.

### Core principle

Users own their data. Evidence Vault makes it as easy to permanently erase information as it is to preserve it. Destructive actions are explicit, confirmed, and transactional.

### Delete Account flow

Location: Profile → Privacy & Data → Delete Account

1. Typed confirmation — user must enter `DELETE`
2. Re-authentication — biometric or password via [ReAuthenticationService]
3. [AccountDeletionService] executes transactional deletion
4. [AuthService.signOut] invalidates the session
5. Navigation returns to [SplashScreen] (Welcome)

### Clear Vault flow

Location: Profile → Privacy & Data → Clear Vault

1. Typed confirmation — user must enter `CLEAR`
2. [VaultResetService] clears investigation data
3. Account, profile, subscription, preferences, and onboarding status are preserved
4. [VaultClearedDialog] confirms success and offers **Create First Incident**

### Deletion order

[InvestigationDataDeletionService] deletes in order:

1. Trust Packages (archive + share stores, export directories)
2. Relationship Groups
3. Timeline Anchors
4. Narrative Events (+ reconstruction notes)
5. Evidence
6. Incidents (fresh workspace session)
7. Dashboard statistics reset ([HomeDashboardMock.resetToEmpty])

Account deletion additionally removes the user account via [UserSessionService.deleteAccount].

Persisted media, metadata indexes, and cloud backup placeholders are removed only after in-memory deletion succeeds.

### Rollback strategy

[InvestigationDataDeletionSnapshot] captures workspace controller, trust package stores, and dashboard state before deletion begins. If any step fails, the snapshot restores prior state so orphaned or partial deletions never remain.

### Services

| Service | Responsibility |
|---|---|
| [InvestigationDataDeletionService] | Shared transactional investigation purge |
| [VaultResetService] | Clear Vault — preserves account |
| [AccountDeletionService] | Delete Account — removes account + all data |
| [ReAuthenticationService] | Biometric/password confirmation |
| [UserSessionService] | Session + account lifecycle |

---

## MVP-0.9.3.3A — Authentication Verification & Session Foundation

**Status:** ✅ Complete (August 4, 2026)

Firebase Authentication is the identity boundary for Evidence Vault. Sprint 4B persists incident + evidence metadata to Firestore and restores the active investigation on launch via `WorkspaceSession` / `IncidentCloudSyncService`. Binaries live in Firebase Storage (Sprint 4A). UI never calls Firebase SDKs directly — only repositories.

### AuthService

| Method | Purpose |
|---|---|
| `register()` | Email/password account creation |
| `signIn()` | Email/password sign-in |
| `signOut()` | End Firebase + local session |
| `currentUser` | Active Firebase user |
| `authStateChanges()` | Session restore stream |

Implementation: `lib/services/auth_service.dart` → `AuthenticationService` → `FirebaseAuthRepository`.  
UI must not call Firebase Auth APIs directly. Auth must not write investigation data.

### Session routing

```
Launch → FirebaseBootstrap → AuthenticationStateProvider → AuthGate
  Authenticated   → MainShellScreen (Investigation application shell)
  Unauthenticated → SplashScreen → Sign In / Create Account
```

Firebase Auth persists sessions across restarts. Signed-in users skip authentication on cold start. Sign Out returns to Splash.

### Isolation

- No direct Firestore calls from widgets — repository + `IncidentCloudSyncService` only (Sprint 4B)
- No Incident collections
- Google Sign-In optional; Email/Password required
- Project: `evidence-vault-dev` only — see [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)

---

## Backend Preparation — Sprint 9

Sprint 9 backend services will **mirror these domain engines**. The backend architecture should implement the four engines as **separate services or modules**, each with a defined API boundary matching the responsibilities in this document.

| Backend module | Mirrors | Primary responsibilities |
|---|---|---|
| **Enrichment Service** | Enrichment Engine | Evaluate `isEnriched`; compute Journey Stage; store enrichment records; future AI enrichment ingestion |
| **Relationship Service** | Relationship Engine | Persist and resolve evidence relationships; link graph queries |
| **Story Service** | Story Engine | Timeline, Connections, Summary generation; narrative synthesis |
| **Trust Service** | Trust Engine | Verification aggregation; Trust Status; Trust Package assembly and export |

### Implementation guidance

- **Engine boundaries are domain boundaries.** Avoid monolithic incident services that merge enrichment evaluation with relationship storage or trust assembly.
- **Journey Stage is derived**, not stored as authoritative state—recalculate on enrichment or relationship change events.
- **Enrichment types are extensible.** New types (AI Summary, inferred metadata) register with the Enrichment Service without changing Journey Stage UI logic.
- **Trust Package assembly is non-blocking.** The Trust Service must not gate on Journey Stage.
- **Event-driven recalculation.** Primary evidence and enrichment mutations emit domain events consumed by the Enrichment Service for real-time Journey Stage updates.

Detailed API contracts, persistence schemas, and service topology will be specified in Sprint 9 backend architecture documentation. This document defines the **domain model and engine responsibilities** that backend design must implement.

---

## Sprint SIC-M1 — Workspace Consolidation & Architecture Closure

SIC-M1 closes implementation debt from the Investigation Workspace and Writing Experience sprints. It introduces **no new product features** — it consolidates navigation, ownership boundaries, and documentation so SIC-2.0 (Investigation Coaching) can build on a stable shell.

### Persistent Investigation Workspace

[IncidentWorkspaceShell] (`lib/screens/incident_workspace_shell.dart`) is the **single source of truth** for incident investigation. All methodology stages live in one persistent environment:

```
Brand (IncidentProductHeader)
  ↓
Capture → Organize → Investigation → Trust Package
                              ↓
                    Timeline | Connections | Reconstruction
```

These four methodology stages together represent the **Incident Status** lifecycle.

- [WorkspaceSession] holds active stage, investigation tab, canvas controller, and resume target above individual routes.
- Stage bodies are mounted once in an [IndexedStack] with memoized children — switching stages preserves scroll positions and investigation context.
- In-shell stage taps call [InvestigationJourneyNavigation.switchStageInShell] — no redundant [Navigator.push] for stage changes.
- **[CurrentIncident](../../lib/domain/incident/current_incident.dart)** is the shared incident read model. [WorkspaceEvidenceController] extends `ChangeNotifier` and exposes `currentIncident` with a single evidence collection (`evidence` + derived `journeyEvidence`). Capture, Organize, Investigation, Trust Package, and Evidence Inspector subscribe with `ListenableBuilder` so title/status/evidence stay synchronized without local copies or duplicate lists. See [`docs/DOMAIN_MODEL.md`](DOMAIN_MODEL.md) — CurrentIncident.

### Progressive Evidence Interaction

Evidence taps across Capture, Organize, Investigation, and Trust Package (where editing is permitted) open the **Evidence Inspector modal** — not the full Evidence Record screen.

[showInvestigationEvidenceInspectorModal] (`lib/widgets/investigation/investigation_evidence_inspector_modal.dart`):

- Centered modal with light backdrop blur over the workspace (~86% viewport height)
- **~80% preview / ~20% context** body split — professional evidence viewer, not a small popup
- Type-specific preview renderers via [EvidencePreviewRegistry] (`lib/widgets/evidence_inspector/`):
  - `PhotoEvidenceRenderer` — proportional fit, no crop
  - `VideoEvidenceRenderer` — thumbnail, play, duration, playback
  - `VoiceEvidenceRenderer` — waveform, duration, play/pause, seek
  - `TextEvidenceRenderer` — full editable note
  - `AttachmentEvidenceRenderer` — file card (icon, name, extension, size, date) or image preview; overflow-safe
- Context field: max 2 visible lines; expands while editing
- Supporting Evidence and Metadata in the compact lower region
- Save / Close / **View complete record →** keep footer locations

Extensibility: add Witness / Location / AI evidence by registering a new renderer — avoid growing modal switch statements.

The legacy [EvidenceInspectorPanel] bottom sheet is retired. One inspector serves the entire workspace.

### Navigation hierarchy

| Entry | Route |
|---|---|
| Home / quick capture | [AppNavigation.openIncidentWorkspace] |
| Resume | [AppNavigation.resumeWorkspace] |
| Investigation perspectives | [AppNavigation.openInvestigationWorkspace] (shell, initial tab) |
| Trust Package | [AppNavigation.openTrustPackage] (shell, Trust Package stage) |
| Advanced record | [AppNavigation.openEvidenceRecord] (explicit only) |

**Retired standalone routes:** `TimelineWorkspaceScreen`, `ConnectionsWorkspaceScreen`, `ReconstructionCanvasScreen`. Timeline, Connections, and Reconstruction exist **only** inside [InvestigationWorkspaceScreen] within the shell.

### Workspace ownership boundaries

| Stage | Owns |
|---|---|
| **Capture** | Preserving primary evidence (photo, voice, note, attachment). Incident identity. |
| **Evidence** | Organizing evidence — Connect mode, relationship group creation, reflections, completeness. |
| **Investigation** | Analysing evidence — Timeline chronology, Connections analysis, Reconstruction narrative. |
| **Trust Package** | Read-only presentation and export. Evidence taps navigate to Investigation for editing. |

Connect mode and relationship group creation live exclusively on the **Evidence** stage ([EvidenceOrganizationToolbar]). Capture no longer exposes organization actions.

### Trust Package policy

Trust Package is **read-only**. Investigators review and export; they do not edit evidence in place. Tapping evidence in the Trust Package preview switches to the Investigation stage where editing tools are available.

### Performance

Stage switching uses [IndexedStack] + [RepaintBoundary] to avoid rebuilding offstage children. [WorkspaceSession._scheduleNotify] batches listener updates via microtask for responsive in-shell navigation.

---

## Sprint SIC-2.0 — Investigation Coaching Foundation

SIC-2.0 introduces the first generation of **Investigation Coaching** — a rule-based assistant layer inside the Investigation Workspace. Product philosophy and long-term vision: [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) — Investigation Coaching Philosophy. Platform roadmap: [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) — Platform Roadmap — Investigation Coaching.

### Coaching panel

A persistent [InvestigationCoachingPanel] sits between the Investigation header and tab bar. It presents short coaching cards — not a chatbot or conversation window.

### Categories (rule-based)

| Category | Examples |
|---|---|
| Evidence Completeness | Photos without observations; single-support timeline events; missing witness statements |
| Relationship Coaching | Unconnected evidence; similar ungrouped photos; isolated documents |
| Timeline Coaching | Time gaps; anchors without supporting evidence |
| Narrative Coaching | Single-source events; unenriched evidence; low-confidence conclusions |
| Trust Package Readiness | Almost complete; events needing support; ready for review |

### Interaction model

- **Review** — navigates to the relevant workspace section (Organize stage, Investigation tab, or Trust Package stage) with optional deep-link to anchor, event, or evidence
- **Dismiss** — temporarily hides a recommendation; may regenerate if conditions persist
- **Priority** — High / Medium / Low derived from investigation completeness, not severity

### Principles (non-negotiable)

Coaching is neutral, evidence-based, and actionable. It never states what happened, infers intent, provides legal advice, or replaces investigator judgement.

Implementation: [InvestigationCoachingEngine], [InvestigationCoachingController], [InvestigationCoachingPanel] in `lib/engines/`, `lib/controllers/`, and `lib/widgets/investigation/`.

---

## Sprint SIC-2.1A — Investigation Health Engine Foundation

SIC-2.1A introduces the **Investigation Health Engine** — a domain service that evaluates investigation structure. It produces structured metrics and findings for consumption by Investigation Coaching, Trust Package readiness, and future dashboards. **No UI changes.**

Product principle: the engine evaluates structure — never truth, intent, or legal conclusions.

### Domain models (`lib/domain/investigation_health/`)

| Model | Role |
|---|---|
| [InvestigationHealth] | Overall + category scores (0–100), `generatedAt`, `findings` |
| [HealthFinding] | Structured finding: `id`, `category`, `priority`, `type`, `messageKey`, `affectedObjectId`, `recommendationKey`, `status` |
| [InvestigationHealthWeights] | Configurable category weights (default sum = 1.0) |
| [InvestigationHealthScoring] | Penalty-based category scores + weighted overall score |
| [HealthMessageKeys] / [HealthRecommendationKeys] | Structured keys only — no English copy in the engine |

### Engine (`lib/engines/investigation_health_engine.dart`)

[InvestigationHealthEngine.evaluate] accepts an [IncidentAggregate] and returns [InvestigationHealth].

- **No Flutter dependencies**
- **No coaching text or presentation logic**
- **Deterministic rules only**

Context is built via [InvestigationHealthContext.fromAggregate], composing existing projections (enrichment, timeline tree, narrative builder, trust package scorecard).

### Evaluation categories

| Category | Example rules |
|---|---|
| Evidence Completeness | Missing observation; not linked to relationship; not referenced by narrative |
| Relationship Coverage | Isolated documents; groups with single member |
| Timeline Integrity | Anchors without supporting evidence; chronological gaps |
| Narrative Support | Insufficient supporting evidence; unsupported narrative statements |
| Trust Readiness | Missing required trust package quality indicators |

### Scoring

Each category returns **0–100** using priority-based penalties ([InvestigationHealthScoring.priorityPenalties]). Overall score is a weighted sum via [InvestigationHealthWeights.defaults] (configurable).

### Consumers (future)

Investigation Coach, Trust Package advisory layers, and health dashboards consume [InvestigationHealth] — the engine does not render UI or notifications.

Tests: `test/investigation_health_test.dart`.

---

## Epic 2 — Sprint 2.1 — Participant Domain Foundation

Participants are **first-class investigation entities** — people involved in an investigation. They are not evidence.

### Domain model (`lib/domain/participant/`)

| Entity | Fields |
|---|---|
| [Participant] | `id`, `incidentId`, `displayName`, `role`, `contactInformation?`, `organisation?`, `notes`, `createdAt`, `updatedAt` |
| [ParticipantRole] | `reporter`, `witness`, `subject`, `investigator`, `other` |

### Evidence ownership

Optional `participantId` on [CapturedEvidence] and [SupportingEvidence] — evidence may reference the person who created, supplied, or is associated with it. Projected to [WorkspaceEvidenceItem.participantId].

### Repository

[ParticipantRepository] / [InMemoryParticipantRepository]:

- Create, Update, Delete, Get by Incident, Get by Id
- Delete blocked when evidence references the participant

Wired through [IncidentAggregate] and [WorkspaceEvidenceController.participantRepository].

### Investigation graph

[InvestigationGraph.nodesFromStore] projects participants as graph nodes alongside evidence, timeline anchors, relationship groups, and narrative events. Architecture only — no UI.

Tests: `test/participant_repository_test.dart`.

---

## Architecture Philosophy

Evidence Vault does not organise files. It reconstructs truth.

Media and documents are evidence artifacts—carriers of proof within a truth record. The platform's purpose is capture, enrichment, connection, understanding, and trusted sharing—not folder hierarchy or document management.

Every engine serves reconstruction quality:

- The **Enrichment Engine** measures how well each primary record is supported
- The **Relationship Engine** connects evidence into meaning
- The **Story Engine** reconstructs what happened
- The **Trust Engine** shares truth with confidence

Every user-facing module consumes these engines:

- The **Library** preserves incidents across time
- The **Workspace** captures and builds without friction
- **View Story** presents narrative understanding
- The **Trust Package** delivers shareable trusted output

**Every feature added to Evidence Vault must strengthen the integrity, trustworthiness, and usefulness of a truth record.**

---

*This document is the canonical platform architecture of Evidence Vault. When implementation details conflict with this specification, this document wins.*
