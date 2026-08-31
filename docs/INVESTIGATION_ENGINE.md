**Version:** DI-1.3  
**Status:** Active — Investigation Engine  
**Last Updated:** August 2, 2026 (Documentation Increment DI-1.3)

# Investigation Engine

This document describes the **Investigation Engine** — the domain pipeline that transforms preserved observations into structured incident intelligence within one Incident.

The Investigation Engine is a **conceptual pipeline**, not a single class or UI module. It defines how evidence moves through layered reconstruction stages, what each layer produces, and why those layers remain separate. Workspaces, screens, and navigation are presentation concerns documented elsewhere.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) — Investigation Method and Product Journey (DI-1.1)
- [`docs/DOMAIN_MODEL.md`](DOMAIN_MODEL.md) — bounded contexts and object responsibilities (DI-1.2)
- [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) — platform engine architecture (DI-1.4)
- [`docs/PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — sprint implementation and repository wiring
- [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) — product constitution
- [`DOCS_INDEX.md`](../DOCS_INDEX.md) — documentation map

**Governing principle:** The platform **does not determine truth**. The Investigation Engine structures observations, chronology, relationships, explanation, and presentation so investigators can reconstruct and communicate findings with confidence.

---

## What the Investigation Engine Is

The Investigation Engine is the **reconstruction pipeline** inside every Incident. It answers one question at each layer:

| Layer | Question |
|---|---|
| **Evidence** | What was preserved? |
| **Timeline Events** | In what order did observations enter the record? |
| **Relationship Groups** | Which evidence belongs together investigatively? |
| **Narrative Events** | How does the investigator explain what happened? |
| **Trust Package** | How is the incident communicated professionally? |

Each layer consumes the output of layers below it (except Evidence, which is the foundation). Each layer adds **structure** — not conclusions. Investigators interpret meaning; the engine preserves integrity of the record.

The Investigation Engine operates **independently of UI**. An investigator may capture evidence in the Evidence Workspace, organise groups in Connections, reconstruct narrative in the Investigation Workspace, and assemble a Trust Package — or perform equivalent operations through any future surface — without changing the pipeline itself.

---

## Investigation Pipeline

```
Evidence
   ↓
Timeline Events
   ↓
Relationship Groups
   ↓
Narrative Events
   ↓
Trust Package
```

The arrow direction indicates **dependency and derivation**, not mandatory sequential completion. Investigators may work across layers as understanding grows. Lower layers constrain upper layers; upper layers never rewrite lower layers.

---

## Layer 1 — Evidence

### Purpose

**Preserve observations before they are lost.**

Evidence is the factual foundation of every investigation. It records what was seen, heard, documented, or attested — photos, video, voice, files, witness records, and the supporting notes and context that clarify them.

### What this layer produces

- **Captured evidence** — immutable primary artifacts created at observation time
- **Supporting evidence** — notes, attachments, and context linked to captured items
- **Enrichment signals** — derived maturity indicators (`isEnriched`) measuring how well each item is supported

### Engine role

The **Enrichment Engine** evaluates evidence maturity. It does not alter captured content. Enrichment surrounds evidence; it never replaces it.

### Pipeline contract

| Input | Output |
|---|---|
| Investigator capture actions | Persisted evidence artifacts bound to one Incident |
| Enrichment attachments | Additive context linked to primary evidence |

**Downstream dependency:** Timeline Events anchor to captured evidence. Relationship Groups reference evidence IDs. Narrative Events trace back to evidence references. Trust Package appendices list evidence without duplicating payloads.

### Does not

- Assign investigative meaning or conclusions
- Define chronology (Timeline Events derive from capture)
- Group evidence investigatively (Relationship Groups)

---

## Layer 2 — Timeline Events

### Purpose

**Record the history of how observations entered the incident.**

Timeline Events establish immutable capture chronology — the order in which evidence was preserved, not the order in which an investigator later explains events.

### What this layer produces

- One **Timeline Event** (Timeline Anchor) per captured evidence item
- Fixed `sequenceOrder` and `anchoredAt` timestamps
- A canonical timeline tree: captured anchors with supporting evidence nested beneath

### Engine role

Timeline ordering is owned by the **Timeline Repository** within the incident aggregate. No Story or Trust engine rewrites capture sequence. Filters and views may hide items; they never reorder anchors.

### Pipeline contract

| Input | Output |
|---|---|
| Captured evidence persistence | Timeline anchor per capture |
| Supporting evidence linkage | Nested clarification beneath anchors — no new anchors |

**Downstream dependency:** Narrative Events initialise with one placeholder per Timeline Event. Trust Package timeline sections consume anchor order. Relationship Groups reference evidence that Timeline Events position in time.

### Does not

- Explain why events matter (Narrative Events)
- Group related evidence (Relationship Groups)
- Change order when narrative is reordered

---

## Layer 3 — Relationship Groups

### Purpose

**Reveal investigative structure across evidence.**

Relationship Groups express which artifacts the investigator considers related — membership, optional name, optional reasoning, and stable visual identity. They make structure visible without assuming it.

### What this layer produces

- Persisted **Relationship Groups** with member evidence IDs
- Investigative metadata: display name, description, permanent colour index
- Internal relationship links resolved by the **Relationship Engine**

### Engine role

The Relationship Engine connects evidence without modifying artifacts. Relationship Groups are **investigator-owned structures** committed on top of those links — not UI cards or temporary selection state.

### Pipeline contract

| Input | Output |
|---|---|
| Evidence IDs + investigator grouping actions | Committed Relationship Groups |
| Relationship Engine links | Linked Evidence enrichment signals |

**Downstream dependency:** Narrative Events reference group IDs for traceability. Trust Package relationship sections assemble group metadata. Timeline views may show related group IDs on anchors.

### Does not

- Alter evidence content or capture timestamps
- Reorder Timeline Events
- Author narrative explanation (Narrative Events)

---

## Layer 4 — Narrative Events

### Purpose

**Explain history — the investigator's reconstruction of what happened.**

Narrative Events are where chronology becomes **meaning**. Investigators name events, write summaries, and assemble references to timeline anchors, relationship groups, and supporting evidence into a coherent account.

### What this layer produces

- **Narrative Events** with editable titles and optional summaries
- Traceability references — never duplicated evidence payloads
- Narrative sequence via `sortOrder`, independent of capture chronology when reordered
- Validation and completeness coaching (derived, not persisted)

### Engine role

The **Story Engine** projects the incident aggregate into narrative read models. **Narrative Builder** and **Narrative Validation** services derive completeness signals. They measure reconstruction quality — not truth or legal certainty.

### Pipeline contract

| Input | Output |
|---|---|
| Timeline Events | Primary anchor reference per narrative event |
| Relationship Groups | Group ID traceability |
| Evidence + enrichment | Supporting references and validation inputs |
| Investigator edits | Persisted title, summary, and narrative order |

**Downstream dependency:** Trust Package reconstruction sections consume narrative events and validation summaries.

### Does not

- Replace Timeline Events or alter capture history
- Duplicate evidence binaries inline
- Auto-conclude unsupported facts

---

## Layer 5 — Trust Package

### Purpose

**Communicate findings through a professional, structured presentation.**

Trust Package is the terminal projection of the Investigation Engine — a canonical assembly of incident summary, timeline, relationship groups, narrative reconstruction, evidence appendix, and integrity signals prepared for review and sharing.

### What this layer produces

- **Trust Package** read model — assembled from the full incident aggregate
- Traceable sections referencing every upstream layer
- Export-ready presentation input (PDF, archive, print, secure share)

### Engine role

The **Trust Engine** evaluates integrity and assembles the Trust Package via **TrustPackageAssembler**. Export and share pipelines consume Trust Package only — never the raw aggregate at render time.

### Pipeline contract

| Input | Output |
|---|---|
| Incident + Evidence maturity | Incident summary |
| Timeline Events | Timeline section |
| Relationship Groups | Relationship group section |
| Narrative Events + validation | Reconstruction section |
| Evidence references | Evidence appendix |
| Verification + integrity aggregates | Integrity summary |

### Does not

- Mutate Evidence, Timeline Events, Relationship Groups, or Narrative Events
- Replace the incident as source of truth
- Block assembly based on investigation maturity

---

## Timeline Records History; Narrative Explains History

Timeline Events and Narrative Events are the most commonly confused layers. They are **complementary**, not redundant.

### Timeline records history

Timeline Events answer: **“What entered the record, and when?”**

- Created automatically when evidence is captured
- Order fixed by capture sequence — immutable
- Content-free beyond anchor references — no investigator prose
- Represents **historical fact of preservation**, not interpretation

Timeline is the **audit trail of observation entry**. It does not judge significance, causality, or narrative coherence.

### Narrative explains history

Narrative Events answer: **“What does the investigator say happened?”**

- Authored and edited by the investigator
- Titled, summarised, and sequenced for explanation
- References Timeline Events — does not replace them
- Narrative order **may diverge** from capture chronology when investigators reorder for clarity

Narrative is the **interpretive reconstruction** built on top of preserved history. It connects anchors, groups, and supporting evidence into an account someone else can follow.

### Side-by-side

| | Timeline Events | Narrative Events |
|---|---|---|
| **Verb** | Records | Explains |
| **Question** | When was this observed and preserved? | What happened according to this investigation? |
| **Authorship** | System at capture | Investigator |
| **Mutability** | Immutable order | Editable text and sequence |
| **Relationship** | Foundation | Projection + explanation over foundation |

### Why separation matters

1. **Integrity** — Capture chronology cannot be rewritten when narrative is edited or reordered
2. **Neutrality** — The platform preserves history without endorsing an explanation
3. **Auditability** — Every narrative claim traces to timeline anchors and evidence references
4. **Flexibility** — Investigators may explain events in an order that differs from capture order without corrupting the record

**Rule:** Timeline is **what was observed and when it entered the record**. Narrative is **what the investigation concludes structurally about what happened** — always evidence-referenced, always investigator-owned.

---

## Investigation Workflow (UI-Independent)

The following workflow describes **investigative work** through the pipeline. It maps to the [Investigation Method](../PRODUCT_PHILOSOPHY.md#the-investigation-method) in Product Philosophy but is expressed in **domain layers**, not screens.

```
1. Capture observations        → Evidence
2. Establish capture history   → Timeline Events (automatic)
3. Enrich evidence             → Evidence (enrichment)
4. Discover relationships      → Relationship Groups
5. Reconstruct explanation     → Narrative Events
6. Communicate findings        → Trust Package
```

### Stage descriptions

| Step | Layer | Investigator action | System behaviour |
|---|---|---|---|
| 1 | Evidence | Preserve photos, video, voice, notes, attachments | Creates Incident if first capture; persists immutable artifacts |
| 2 | Timeline Events | *(passive)* | Creates one anchor per capture; fixes chronology |
| 3 | Evidence | Add context, notes, metadata | Enrichment Engine updates maturity signals |
| 4 | Relationship Groups | Connect related evidence; name and describe groups | Relationship Engine links; repository commits groups |
| 5 | Narrative Events | Title events, write summaries, reorder explanation | Story Engine projects; validation coaches completeness |
| 6 | Trust Package | Review assembled presentation; export or share | Trust Engine assembles; export consumes package only |

### Workflow properties

**Non-linear.** Investigators may enrich evidence after creating groups, or draft narrative before all groups are complete. Lower layers constrain upper layers; incomplete lower layers surface coaching — they do not hard-block upper work.

**Continuous.** Investigation does not “finish” at any layer except when an investigator chooses to finalize or archive the incident operationally. Trust Package assembly is available at any stage.

**UI-agnostic.** The same workflow executes regardless of whether the investigator uses the Evidence Workspace, Investigation Workspace tabs, standalone reconstruction routes, or future clients. Repositories and engines enforce the pipeline; workspaces are lenses.

**Reference discipline.** Each layer stores IDs and investigator metadata — never duplicate evidence content. Projections rebuild when upstream layers change; customized narrative text survives reference refresh.

---

## Pipeline Data Flow

Conceptual flow through the incident aggregate:

```
Capture action
      │
      ▼
┌─────────────┐     Enrichment Engine
│  Evidence   │◄──── evaluates maturity
└──────┬──────┘
       │ one anchor per capture
       ▼
┌─────────────┐
│  Timeline   │
│   Events    │
└──────┬──────┘
       │ evidence IDs
       ▼
┌─────────────┐     Relationship Engine
│ Relationship│◄──── resolves links
│   Groups    │
└──────┬──────┘
       │ anchor + group + evidence refs
       ▼
┌─────────────┐     Story Engine
│  Narrative  │◄──── projects + validates
│   Events    │
└──────┬──────┘
       │ aggregate assembly
       ▼
┌─────────────┐     Trust Engine
│   Trust     │◄──── assembles presentation
│  Package    │
└─────────────┘
```

---

## Mapping to Platform Engines

The Investigation Engine pipeline aligns with the platform engines in [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md):

| Pipeline layer | Primary platform engine(s) |
|---|---|
| Evidence | Capture Engine + Evidence Engine |
| Timeline Events | Capture Engine + Evidence Engine |
| Relationship Groups | Relationship Engine |
| Narrative Events | Narrative Engine |
| Trust Package | Trust Package Engine |

Legacy mapping: Enrichment → Evidence Engine, Story → Narrative Engine, Trust → Trust Package Engine. See [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md).

Platform engines are **implementation services**. The Investigation Engine is the **conceptual model** they collectively implement. Backend services (Sprint 9+) should mirror this pipeline as separate bounded modules with APIs matching layer responsibilities.

---

## Mapping to Product Journey

The [Product Journey](../PRODUCT_PHILOSOPHY.md#product-journey) describes **where investigators work**. The Investigation Engine describes **what happens to the record**:

| Product Journey stage | Primary pipeline layers |
|---|---|
| **Capture** | Evidence → Timeline Events |
| **Evidence** | Evidence enrichment → Relationship Groups (initial) |
| **Investigation** | Timeline Events + Relationship Groups → Narrative Events |
| **Trust Package** | Full pipeline → Trust Package assembly |

Product Journey is workspace orientation. Investigation Engine is domain reconstruction. Both describe the same methodology from different angles.

---

## Invariants

These rules apply at every layer of the Investigation Engine:

1. **One Incident = One Truth Record** — the pipeline runs entirely within one incident boundary
2. **Evidence is immutable** — no layer modifies captured content
3. **Chronology is sacred** — Timeline Event order is never rewritten by narrative or presentation
4. **References, not copies** — upper layers point to lower layers; payloads are not duplicated
5. **Investigator owns explanation** — Narrative text and group reasoning are investigator-authored
6. **Platform neutrality** — validation measures completeness; it does not determine truth
7. **Trust through structure** — Trust Package communicates assembly integrity, not adjudication

---

## Relationship to Other Documents

| Topic | Authoritative document |
|---|---|
| Investigation pipeline and workflow | **This document** — `docs/INVESTIGATION_ENGINE.md` |
| Bounded contexts and object definitions | [`docs/DOMAIN_MODEL.md`](DOMAIN_MODEL.md) |
| Platform engine architecture | [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) |
| Sprint implementation and repository wiring | [`docs/PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) |
| Investigation Method and Product Journey | [`PRODUCT_PHILOSOPHY.md`](../PRODUCT_PHILOSOPHY.md) |
| Product rules and non-negotiables | [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) |

---

*Documentation Increment DI-1.3 — Investigation Engine. No implementation changes.*
