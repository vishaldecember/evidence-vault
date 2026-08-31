**Version:** DI-1.5  
**Status:** Active — Domain Architecture  
**Last Updated:** August 10, 2026 (Sprint 6C — Workspace / Cockpit / CaptureSession identity)

# Evidence Vault Domain Model

This document defines the **bounded contexts** within an Incident — the domain objects that compose one truth record and the responsibility of each.

It complements [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md), which defines platform engine architecture, and [`docs/PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md), which describes sprint implementation and repository wiring.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) — Investigation Platform philosophy (DI-1.1)
- [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) — product constitution
- [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) — platform engines and services (DI-1.4)
- [`docs/INVESTIGATION_ENGINE.md`](INVESTIGATION_ENGINE.md) — reconstruction pipeline and workflow (DI-1.3)
- [`docs/PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — sprint implementation and repository wiring
- [`docs/UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) — Workspace / Cockpit navigation (canonical flows)
- [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md) — Capture Cockpit source of truth
- [`docs/LANGUAGE_SYSTEM.md`](LANGUAGE_SYSTEM.md) — terminology and copy
- [`DOCS_INDEX.md`](../DOCS_INDEX.md) — documentation map

**Governing principle:** **One Incident = One Truth Record.** Every domain object below belongs to exactly one Incident and must never be merged or linked across incidents without explicit investigator intent.

---

## Bounded Contexts

An **Incident** is the aggregate root. All reconstruction activity occurs within its boundary. The incident does not determine truth — it **structures** preserved observations, chronology, relationships, narrative, and presentation.

```
Incident
├── Evidence
├── Timeline Events
├── Relationship Groups
├── Narrative Events
└── Trust Package
```

Each child context owns a distinct investigative concern. They share references — never duplicated evidence payloads — and are consumed by platform engines (Enrichment, Relationship, Story, Trust) described in Platform Architecture.

| Bounded context | Core question | Owned by |
|---|---|---|
| **Evidence** | *What was preserved?* | `EvidenceRepository` |
| **Timeline Events** | *In what order were observations captured?* | `TimelineRepository` |
| **Relationship Groups** | *Which evidence belongs together investigatively?* | `RelationshipRepository` |
| **Evidence Collections** | *What did Organize cluster together?* | `CollectionEngine` + store |
| **Investigation Relationships** | *How are items related / supporting?* | `RelationshipEngine` |
| **Memory Recall** | *What forgotten incidents may matter?* | `MemoryRecallProvider` (Vault) |
| **Risk Coach** | *What may need attention next?* | `RiskAssessmentProvider` (Investigation) |
| **Narrative Events** | *How does the investigator explain what happened?* | `NarrativeEventRepository` |
| **Trust Package** | *How is the incident communicated professionally?* | `TrustPackageAssembler` (projection) |

Supporting domain objects (Enrichment, Reconstruction Notes, Evidence Relationships) exist **within or between** these contexts. They are documented in Platform Architecture. This document focuses on the five primary bounded contexts above.

---

## Incident

The **Incident** is the highest-level container — one bounded reconstruction of what happened.

### Responsibility

- Own every child context (Evidence, Timeline Events, Relationship Groups, Narrative Events)
- Provide incident identity: title, operational status, ownership, timestamps
- Serve as the single entry point for investigation workspaces and Trust Package assembly
- Enforce the rule that incidents are never automatically merged or linked

### Key attributes

| Attribute | Role |
|---|---|
| `id` | Stable incident identifier |
| `title` | Progressive incident name (optional until named) |
| `status` | Operational lifecycle: Draft, Active, Paused, Finalized, Archived |
| `createdAt` / `updatedAt` | Incident lifecycle timestamps |
| Journey Stage | **Derived** enrichment maturity — not user-editable state |

### Business rules

- **Capture Now** establishes a new incident identity **before** Capture Cockpit opens (Photo / Video / Voice) — silently, without a “New Incident” form
- The Incident Workspace is **never** presented as an empty staging screen; when Workspace appears it already represents a real/current incident (with Cockpit-captured evidence or existing evidence)
- One incident equals one truth record across the Library of Truth
- Trust signals (Verification, Integrity) aggregate at incident level
- Workspace continuation and Cockpit capture **must not** create a replacement `incidentId`

### Does not

- Store narrative text, relationship membership, or timeline order directly — these belong to child contexts
- Adjudicate truth or legal conclusions
- Block Trust Package assembly based on maturity or completeness
- Belong to Capture Cockpit as an owned entity — Cockpit operates **against** `incidentId`; it does not create incidents

Implementation reference: [`Incident`](../../lib/domain/incident/incident.dart), [`IncidentAggregate`](../../lib/domain/incident/incident_aggregate.dart).

### CurrentIncident — single source of truth

[`CurrentIncident`](../../lib/domain/incident/current_incident.dart) is the **shared read model** for the active investigation. It projects repository-owned state (title, status, evidence, timeline anchors, relationship groups, narrative counts, capture progress, Trust Package progress) into one object.

| Rule | Requirement |
|---|---|
| Ownership | Repository layer / [`IncidentAggregate`](../../lib/domain/incident/incident_aggregate.dart) owns the incident store; UI reads `WorkspaceEvidenceController.currentIncident` |
| Evidence collection | **One** collection: `CurrentIncident.evidence`. Journey strip order is `CurrentIncident.journeyEvidence` (derived from the same store — not a second repository) |
| Subscription | `WorkspaceEvidenceController` is a `ChangeNotifier`; Capture, Organize, Investigation, Trust Package, and Evidence Inspector rebuild via `ListenableBuilder` |
| No local copies | Screens must not cache incident title, status, or evidence lists outside the shared projection |
| Sync | Capture, rename, or other mutations update every stage immediately — no restart, refresh, or navigation |
| Shared identity | Incident Workspace and Capture Cockpit read/write the **same** `CurrentIncident` / `incidentId` |

Supported capture kinds (Photo, Video, Voice, Note, File, and future Witnesses / Locations) insert into the same collection. Future AI Coach, Reports, Timeline Engine, and Trust Package assembly consume this same projection.

### CaptureSession — internal grouping

**CaptureSession** is an internal grouping / recovery concept bound to an `incidentId`. It is **not** a user-facing workflow and must not be exposed as timers, pause language, or session UI.

| Rule | Requirement |
|---|---|
| Binding | A CaptureSession belongs to exactly one `incidentId` |
| Capture Now | New incident → CaptureSession → Cockpit → evidence → same Workspace |
| Workspace continuation | Existing incident’s open/active session is reused; Cockpit must **not** mint a replacement incident or silently replace the session identity for that Workspace incident |
| Visibility | Users see evidence and Workspace/Cockpit — never “session management” |

### Incident Workspace and Capture Cockpit (presentation surfaces)

These are **not** separate bounded contexts. They are presentation / session surfaces over the same Incident:

| Surface | Domain role |
|---|---|
| **Incident Workspace** | Persistent Incident State — timeline, sticky capture, organize / investigation / trust entry |
| **Capture Cockpit** | Active Capture State for Photo / Video / Voice — operates on `incidentId`; does **not** own Incident creation |

Evidence captured in Cockpit is Evidence of that Incident. Note / File capture remains a Workspace concern. See [`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md) and [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md).

---

## Evidence

**Evidence** is everything that was **preserved** about the incident — the observable record investigators capture and enrich.

### Responsibility

- Store immutable captured artifacts (photos, video, voice, files, witness records)
- Store supporting artifacts (notes, attachments, documents) linked to captured evidence
- Belong to exactly one `incidentId` — including all items captured via Capture Cockpit

Photo / Video / Voice evidence created in Capture Cockpit must use the `incidentId` with which Cockpit was opened. Note / File evidence created on Workspace uses the Workspace’s current `incidentId`. There is no separate Cockpit-owned evidence namespace.
- Hold enrichment that **surrounds** evidence without altering originals
- Supply the factual substrate for timeline anchoring, relationship grouping, narrative traceability, and Trust Package appendices

### Structure

```
Evidence
├── Captured Evidence (immutable after capture) — PRIMARY chronology
│     Photo · Video · Voice
└── Supporting Evidence (flexible, linked to a primary parent)
      Notes · File Attachments · Documents · Context
      (+ future Witnesses / Locations as enrichment)
```

| Sub-type | Role | Timeline connector |
|---|---|---|
| **Captured Evidence** | Primary proof — chronology ("what happened"). User-facing term in Investigation: **Primary Evidence** (internal timeline anchors retained). | Orange |
| **Supporting Evidence** | Enrichment under a primary parent ("supports what happened") | Blue |

Supporting evidence carries:

| Field | Purpose |
|---|---|
| `parentEvidenceId` | Primary evidence this item supports |
| `relationshipType` | Default `supports` — prepares Evidence Chains, AI, narrative, Trust Package |

### Business rules

- Original capture content and timestamps are **never modified**
- Capture sequence order is immutable — connector colour communicates role, not reorder
- Note / File captures attach to the nearest preceding primary evidence
- Enrichment is additive only — Context, notes, metadata, linked evidence
- Supporting evidence does not independently define chronology
- Every evidence item belongs to exactly one Incident
- `isEnriched` is derived by the Enrichment Engine — not manually toggled

### Does not

- Define investigative groupings — that is Relationship Groups
- Define narrative meaning — that is Narrative Events
- Define presentation layout — that is Trust Package

Implementation reference: [`CapturedEvidence`](../../lib/domain/evidence/captured_evidence.dart), [`SupportingEvidence`](../../lib/domain/evidence/supporting_evidence.dart).

---

## Timeline Events

**Timeline Events** record **when observations entered the incident** in immutable capture order.

In implementation, each Timeline Event is a [`TimelineAnchor`](../../lib/domain/timeline/timeline_anchor.dart) — one anchor per captured evidence item.

### Responsibility

- Establish the **canonical chronology** of the incident from capture sequence
- Bind each anchor to exactly one captured evidence item
- Preserve `anchoredAt` and `sequenceOrder` as the source of truth for timeline reconstruction
- Nest supporting evidence beneath anchors without creating new timeline positions

### Key attributes

| Attribute | Role |
|---|---|
| `capturedEvidenceId` | The captured evidence this event anchors |
| `anchoredAt` | When the observation was preserved |
| `sequenceOrder` | Immutable position in capture chronology |

### Business rules

- One Timeline Event per captured evidence item — created at capture time
- Order is determined by `sequenceOrder` and `anchoredAt` — **never** by UI sorting, filters, or `lastPreservedAt` projections
- Supporting evidence attaches beneath anchors; it does not create Timeline Events
- Timeline Events are **read-only** in reconstruction workspaces — chronology is not rearranged by investigators
- Filters (Photos, Videos, Notes, etc.) affect visibility only — never order

### Does not

- Carry investigator narrative or interpretation
- Represent relationship group membership
- Change when narrative events are reordered
- Determine legal or factual truth — only **capture chronology**

---

## Relationship Groups

**Relationship Groups** are **investigative structures** — persisted domain entities that express which evidence belongs together and why.

They are **not UI constructs**. Colour chips, group cards, and Connections Workspace panels are **projections** of Relationship Groups. The group exists in the domain whether or not it is currently visible on screen.

### Responsibility

- Persist membership: which evidence items investigators have grouped together
- Persist investigative metadata: optional display name and reasoning description
- Maintain stable visual identity via assigned `colorIndex` (never reassigned on edit)
- Supply traceability references for Narrative Events and Trust Package sections
- Express relationship semantics internally — investigators link evidence; they do not classify relationship types

### Key attributes

| Attribute | Role |
|---|---|
| `memberEvidenceIds` | Evidence belonging to this investigative group |
| `colorIndex` | Permanent palette index assigned at creation |
| `displayName` | Optional investigator label (falls back to `Group N`) |
| `description` | Optional reasoning — why these items belong together |
| `type` | Internal relationship classification — not user-facing |

### Business rules

- Owned exclusively by the Incident — created via Connect Mode, Organize mode, or repository commit
- Require at least two members to commit a new group
- Captured evidence membership defines investigative structure; supporting evidence may move between groups in Organize mode
- Confidence indicators (`Low` / `Medium` / `High`) are **derived coaching signals** — never persisted, never legal certainty
- Editing name or description does not alter evidence or timeline order

### Does not

- Modify captured evidence content
- Reorder Timeline Events
- Author narrative summaries — Narrative Events reference groups; they do not replace them
- Exist only in UI state — groups survive navigation, workspace changes, and projection rebuilds

Implementation reference: [`RelationshipGroup`](../../lib/domain/relationship/relationship_group.dart), [`RelationshipRepository`](../../lib/repositories/relationship_repository.dart).

---

## Narrative Events

**Narrative Events** are **investigator-authored reconstruction sections** — structured explanations of what happened, traceable to evidence.

### Responsibility

- Persist investigator titles and optional summaries for each reconstruction section
- Reference Timeline Events, Relationship Groups, supporting evidence, and reconstruction notes — **never duplicate evidence payloads**
- Maintain narrative sequence via `sortOrder` (independent of timeline chronology when reordered)
- Preserve customized investigator text when underlying evidence references refresh

### Key attributes

| Attribute | Role |
|---|---|
| `title` | Event name — inline editable (`Event N` default) |
| `summary` | Optional investigator explanation (max 500 characters) |
| `timelineAnchorEvidenceId` | Primary anchor reference |
| `relationshipGroupIds` | Traceability to Relationship Groups |
| `supportingEvidenceIds` | Supporting evidence references |
| `reconstructionNoteIds` | Linked reconstruction note references |
| `sortOrder` | Narrative sequence |
| `titleCustomized` / `summaryCustomized` | Protect investigator edits on reference refresh |

### Business rules

- Initialised with one placeholder event per Timeline Event — no generated narrative text
- Reference refresh updates links when evidence or groups change; customized title/summary are never overwritten
- Validation measures **completeness** — not truth, legal certainty, or AI interpretation
- Selecting a Narrative Event synchronises investigation canvas highlights across Timeline and Connections views

### Does not

- Replace Timeline Events or alter capture chronology
- Store evidence binaries or enrichment content inline
- Auto-generate conclusions unsupported by referenced evidence (AI generation, when introduced, remains evidence-bound)

Implementation reference: [`NarrativeEvent`](../../lib/domain/reconstruction/narrative_event.dart), [`NarrativeEventRepository`](../../lib/repositories/narrative_event_repository.dart).

---

## Trust Package

The **Trust Package** is the **presentation projection** of a complete incident — a structured assembly for professional review and sharing.

It is not a duplicate incident. It is a **read model** produced from the Incident aggregate when an investigator prepares to communicate findings.

### Responsibility

- Assemble incident summary, timeline, relationship groups, narrative reconstruction, evidence appendix, and integrity signals into one canonical presentation model
- Preserve traceability — every section references domain objects, never orphaned copies
- Serve as the single input for export pipelines (PDF, archive, print, secure share)
- Communicate structural integrity and completeness without adjudicating truth

### Structure

| Section | Source context |
|---|---|
| Incident Summary | Incident + Evidence maturity signals |
| Timeline Section | Timeline Events + linked evidence references |
| Relationship Groups | Relationship Groups + confidence coaching |
| Reconstruction Section | Narrative Events + validation summaries |
| Evidence Appendix | Evidence references (no embedded media duplication) |
| Integrity Summary | Verification and integrity aggregates |

### Business rules

- Generated entirely from [`IncidentAggregate`](../../lib/domain/incident/incident_aggregate.dart) via [`TrustPackageAssembler`](../../lib/domain/trust_package/trust_package_assembler.dart)
- Preview and export consume **Trust Package only** — never read the aggregate directly at presentation time
- Available at every investigation stage — assembly is never blocked by journey maturity
- Does not mutate Evidence, Timeline Events, Relationship Groups, or Narrative Events

### Does not

- Store investigator workspace state or UI selections
- Replace the incident as source of truth — regenerating the package reflects current aggregate state
- Determine what happened — it **communicates** structured findings

Implementation reference: [`TrustPackage`](../../lib/domain/trust_package/trust_package.dart).

---

## Timeline Events vs Narrative Events

Timeline Events and Narrative Events answer **different investigative questions**. They are related but not interchangeable.

| Dimension | Timeline Events | Narrative Events |
|---|---|---|
| **Question** | *When were observations captured?* | *What does the investigator say happened?* |
| **Nature** | Immutable capture chronology | Investigator-authored reconstruction |
| **Order** | Fixed by capture sequence | Narrative `sortOrder` — may diverge from chronology |
| **Content** | References captured evidence only | Title, summary, and cross-references |
| **Authorship** | System-created at capture | Investigator-edited; placeholders at init |
| **Mutability** | Order and anchors do not change | Titles, summaries, and sequence editable |
| **Workspace** | Timeline / Investigation chronology view | Reconstruction / Narrative builder |

### How they relate

```
Timeline Event (anchor)
        │
        │  one-to-one at initialization
        ▼
Narrative Event (placeholder "Event N")
        │
        │  investigator enriches with title, summary, group references
        ▼
Reconstruction section traceable to evidence
```

- Every Narrative Event **references** a primary Timeline Event via `timelineAnchorEvidenceId`
- Reordering Narrative Events changes **explanation sequence**, not **capture chronology**
- New captured evidence appends Timeline Events and may append matching Narrative placeholders
- Removing evidence preserves investigator narrative where possible; broken references surface explicitly

**Rule of thumb:** Timeline Events record **what was observed and when it entered the record**. Narrative Events record **how the investigator explains the incident** using that record.

---

## Relationship Groups as Investigative Structures

Relationship Groups must be understood as **domain entities**, not presentation artifacts.

### Why they are not UI constructs

| Misconception | Domain reality |
|---|---|
| “A group is a card in Connections” | The card is a **view**; the group persists in `RelationshipRepository` |
| “Colour is a UI theme choice” | `colorIndex` is assigned at creation and stored permanently |
| “Grouping is temporary Connect Mode state” | Connect Mode uses `TemporaryRelationshipGroup` (UI-only); commit creates a persisted `RelationshipGroup` |
| “Confidence badges are group properties” | Confidence is **derived coaching** — recomputed, never stored on the group |

### Investigative role

Relationship Groups express **structure the investigator assigns to evidence**:

- **Membership** — which artifacts belong together in the investigation
- **Reasoning** — optional description of why they belong together
- **Identity** — name and colour for consistent reference across Timeline, Connections, Narrative, and Trust Package

Groups enable the platform to **reveal relationships** without assuming them. The Relationship Engine stores links; Relationship Groups express **investigator-organised structure** over those links and member evidence.

### Downstream consumption

| Consumer | Uses Relationship Groups for |
|---|---|
| Connections Workspace | Editing membership and metadata |
| Timeline Workspace | Showing related group IDs on anchors |
| Narrative Events | Traceability references in event cards |
| Trust Package | Group sections with names, colours, and confidence coaching |
| Investigation Canvas | Synchronised selection across perspectives |

Removing or renaming a group in the UI edits **investigative structure** — not a transient layout state.

---

## Context Map

How bounded contexts reference each other within one Incident:

```
                    ┌─────────────┐
                    │   Incident  │
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
     ┌──────────┐   ┌─────────────┐   ┌──────────────────┐
     │ Evidence │◄──│Timeline     │   │ Relationship     │
     │          │   │Events       │   │Groups            │
     └────┬─────┘   └──────┬──────┘   └────────┬─────────┘
          │                │                    │
          │                └────────┬───────────┘
          │                         ▼
          │                 ┌───────────────┐
          └────────────────►│ Narrative     │
                            │Events         │
                            └───────┬───────┘
                                    │
                                    ▼ assemble (read-only)
                            ┌───────────────┐
                            │ Trust Package │
                            └───────────────┘
```

**Reference discipline:** Child contexts store IDs and metadata — not duplicated evidence content. Projections (`WorkspaceEvidenceItem`, `NarrativeEventViewModel`, `TrustPackage`) are read models for presentation.

---

## Relationship to Platform Architecture

| Topic | Document |
|---|---|
| Bounded contexts and object responsibilities | **This document** — `docs/DOMAIN_MODEL.md` |
| Investigation pipeline and layer workflow | [`docs/INVESTIGATION_ENGINE.md`](INVESTIGATION_ENGINE.md) |
| Platform engine architecture | [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) |
| Sprint implementation and repository wiring | [`docs/PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) |
| Investigation methodology and Product Journey | [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) |
| Product rules and non-negotiables | [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) |

---

*Documentation Increment DI-1.2 — Domain Architecture. No implementation changes.*
