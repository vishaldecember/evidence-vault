**Version:** 3.2 (DI-3.0 + Sprint 6C Workspace/Cockpit lock)  
**Status:** Active Product Constitution — Architecture Freeze  
**Last Updated:** August 10, 2026 (Architecture Source-of-Truth — Workspace vs Capture Cockpit)

# Evidence Vault Product Principles

This document is the **single source of truth** for product philosophy at Evidence Vault. It governs product, design, and engineering decisions. When guidance conflicts elsewhere, this document wins.

It defines **Vision**, **Mission**, **Product Philosophy**, **Product Identity**, **Product Category**, and **Product North Star** — as well as operational rules, non-negotiables, and platform behaviour.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Investigation Platform philosophy; Simplicity Above Intelligence (DI-3.0)
- [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — permanent engineering guardrails (DI-3.0)
- [`ROADMAP.md`](ROADMAP.md) — platform intelligence roadmap (DI-3.0)
- [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) — structural UX rules; canonical Home / Workspace / Cockpit flows
- [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) — Capture Cockpit source of truth
- [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) — Incident, CaptureSession, Evidence relationships
- [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) — platform structure and data model
- [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) — voice, labels, and terminology
- [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) — visual and interaction standards
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map

---

## 1. Product Vision

To become the world's leading **Incident Reconstruction Platform** for individuals and professionals.

We envision a future where reconstructing what happened is calm, clear, and trustworthy—where preserved evidence speaks with the rigor it deserves, and where every incident can mature from a first capture into a record that carries confidence.

### Mission

Evidence Vault exists to help people **preserve, enrich, connect, and understand** the moments that matter—ultimately reconstructing the truth behind an incident.

We serve anyone who needs to document what happened with integrity: individuals facing difficult situations, professionals building defensible records, and anyone who understands that the truth of an incident deserves more than memory alone.

### Operational purpose

Evidence Vault is **not a storage application**.

Evidence Vault is an **Incident Reconstruction Platform** that helps people preserve, enrich, connect, and understand moments that matter—ultimately producing trusted incident reports.

The purpose is not collecting files.  
The purpose is **reconstructing truth**.

Evidence Vault helps users:

- **Preserve** what happened before memory fades or accounts diverge
- **Enrich** captured evidence with context that surrounds—not replaces—the original record
- **Connect** evidence through relationships that reveal meaning over time
- **Understand** the incident through narrative, connections, and trust signals
- **Report** with confidence through Trust Packages built from verified, connected evidence

Every feature must serve reconstruction—not filing, sorting, or hoarding media.

We do not simply store files. We help people **confidently reconstruct what happened.** Storage is a means. Reconstruction is the purpose.

---

## Product Identity

| | |
|---|---|
| **Product** | Evidence Vault |
| **Experience** | Library of Truth |
| **Category** | Incident Reconstruction Platform |
| **Identity (DI-3.0)** | A calm documentation platform powered by an intelligent investigation engine — not investigation software |

**Evidence Vault** is the product—the platform where incidents are captured, built, and understood.

The **Library of Truth** is the experience—the long-term home where incidents grow into trusted records and remain accessible across time.

**Incident Reconstruction Platform** is the category we define and lead—not a file manager, not a notes app, not a storage locker, but a place where truth is rebuilt with intention.

Evidence Vault is **not investigation software**. Users document what they observed. The platform quietly organises, reasons, and strengthens. The investigator always remains in control.

---

## Product Category

Evidence Vault is an **Incident Reconstruction Platform**.

It is not an evidence management platform, evidence collection platform, gallery, notes application, or cloud storage product. The category describes **what the platform does**: preserve, enrich, connect, understand, and report incidents—not manage files.

Every architectural and UX decision should reinforce reconstruction over storage.

---

## Core Beliefs

These convictions shape every product decision. They are permanent—not slogans.

**Truth deserves structure.** Facts scattered across messages, memory, and moments are fragile. Structure gives truth a form it can defend.

**Moments disappear faster than memory.** The right time to preserve is now.

**We preserve truth, not files.** What matters is what was captured and what it represents—not how many items sit on a drive.

**Evidence is immutable.** What was preserved remains preserved. The original record is never rewritten, replaced, or silently altered.

**Context enriches understanding.** Context surrounds evidence—it does not change it.

**Connected evidence builds knowledge.** Individual pieces of truth gain meaning through relationship. Meaning **emerges** through the connections users establish between immutable pieces of evidence.

**Understanding grows over time.** An incident may begin with a single captured moment and mature into something richer. That growth is measured by depth—not checkboxes or completion states.

**Reflection preserves wisdom.** Looking back preserves what an experience taught—wisdom that sits alongside facts, never replacing them.

**Trust is built through preservation, enrichment, and connection.** Trust is not a label applied at the end. It grows from how evidence is captured, how context is added, and how the pieces of an incident are woven into a coherent, defensible whole.

**Technology should quietly accompany people through important moments.** Evidence Vault should feel calm when stress is highest. It should disappear behind the user's purpose—witness, preserve, understand—rather than demand attention for itself.

**Every incident deserves to be reconstructed with confidence.** People deserve a record built with care—one they can stand behind when it matters most.

Compassionate voice and copy standards are defined in [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md).

---
## 2. The Library of Truth

The **Library of Truth** is the user's long-term collection of incidents.

Each incident grows through evidence and enrichment until it becomes a trusted record. The Library is not a file manager. It is a durable archive of reconstructed truth—searchable, resumable, and reportable across time.

The Library supports:

- **Resume** — return to active work and continue building an incident
- **Browse** — navigate incidents as coherent records, not folders of files
- **Search** — find incidents and evidence across the collection
- **Report** — access and regenerate Trust Packages from preserved records

**Capture Now** establishes a new incident silently before Cockpit (Photo / Video / Voice) or before Workspace (Note / File). There is no manual “Create Incident” form. Structure emerges from Capture Now / first capture action—not empty forms or empty Workspace staging.

**One incident = one truth record.** Incidents are discrete by design. They are never automatically linked, merged, or inferred to be related without explicit user intent.

---

## 3. Workspace Philosophy

Evidence Vault has two distinct product states:

| State | Meaning |
|---|---|
| **Incident Workspace** | **Incident State** — the persistent environment for a real/current incident |
| **Capture Cockpit** | **Active Capture State** — the immersive Photo / Video / Voice capture layer |

### Incident Workspace = Incident State

The **Incident Workspace** (Evidence Workspace / Continuous Capture hub) is the persistent environment for a **real/current incident**.

It is **never** an empty capture staging screen. When the Workspace appears, it already represents an incident that either:

- holds evidence captured during the current Capture Now → Cockpit flow, or
- already belongs to an existing incident (Continue Preserving / Workspace continuation)

The Workspace contains:

- incident identity (`incidentId`)
- previously captured evidence
- newly captured evidence
- chronological evidence timeline
- sticky capture actions (Photo / Video / Voice → Cockpit; Note / File on Workspace)
- organization / investigation / trust capabilities as applicable

Workspace purpose remains **capture and build** for that incident — without dashboard thinking.

| Component | Role |
|---|---|
| **Sticky capture bar** | Photo / Video / Voice open Cockpit; Note / File stay on Workspace |
| **Evidence timeline** | Authoritative chronological view of accumulated evidence |
| **Incident Title** | Progressive naming—optional, never blocking |
| **Incident Status** | Living canvas of what has been preserved |
| **View Story** | Intelligence centre for understanding the incident |
| **Prepare Trust Package** | Assemble a trusted report when ready |

**Remove dashboard thinking.** The workspace is a working surface—not an analytics console.

The following do **not** belong inside the workspace:

- Analytics cards and metric dashboards
- Aggregate counters that replace visual evidence
- File-manager patterns (numbered grids, overflow badges, “N preserved” summaries)
- Empty staging UX that awaits a first capture with no incident identity

### Capture Cockpit = Active Capture State

**Capture Cockpit** is the focused immersive environment for actively capturing **Photo, Video, or Voice**.

- Cockpit operates **on** an existing `incidentId`
- Cockpit does **not** own incident creation, naming, organization, investigation, or Trust Package
- Note and File are **Workspace** capture actions — not Cockpit modalities
- Exiting Cockpit returns to the same incident Workspace (Capture Now: the newly established incident’s Workspace)

Canonical flows, Cockpit contract, and non-negotiable invariants: [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) and [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md).

### Capture Now vs Continue Preserving

| Action | Meaning |
|---|---|
| **Capture Now** | Start a **new** incident and capture immediately — establish incident → open Cockpit → same Incident Workspace |
| **Continue Preserving** | Return to an **existing** Incident Workspace — do **not** auto-open Cockpit |

Users capture first. They enrich in place. They understand through Story. They report through Trust Package.

---

## 4. Incident Status Philosophy

**Incident Status** is the living canvas of an incident (UI label formerly *Incident Journey*).

It answers: **“What have I captured so far?”**

The primary investigation workflow — **Capture → Organize → Investigation → Trust Package** — is the Incident Status lifecycle.

Evidence appears in capture order as real previews—photos, videos, voice notes, notes, and attachments—not generic icons or sequence numbers. Incident Status grows naturally as evidence accumulates. Every captured item remains visible. Nothing is hidden behind aggregate labels such as “+5” or “3 preserved.”

**Context, witnesses, and linked evidence are attached directly to evidence items**—not scattered across separate workflows. Users enrich evidence where it lives. They should never leave the capture-and-build flow to add meaning.

The Journey visualizes maturity. It is not a progress bar, score, or gamification mechanic. It guides quality without blocking progress.

**Chronology as narrative** belongs in **View Story**. The workspace Journey shows what exists; Story explains what happened.

---

## 5. Journey Stages

Journey stages describe the **maturity of understanding**—not operational status, task completion, or evidentiary validity.

```
EMPTY → BUILDING → RICH
```

| Stage | Meaning |
|---|---|
| **EMPTY** | Evidence has been captured |
| **BUILDING** | Evidence has context **or** linked evidence |
| **RICH** | Primary evidence has been enriched with sufficient context |

Users may **Prepare Trust Package** at any stage. The journey guides quality but **never blocks progress**.

### Presentation rules

- The active stage is determined by domain rules and passed to the presentation layer
- The UI visualizes maturity; it does not evaluate or score it
- No percentages, rewards, or “completion” language
- Prefer *Journey*, *Building*, *Enriched*, and *Rich*. Avoid *Progress*, *Finished*, and *Done*

Journey stages are distinct from **incident lifecycle** status (Draft, Active, Paused, Finalized, Archived), which describes operational state—not maturity of understanding.

---

## 6. Relationship Engine

Users do **not** draw relationship lines. The system creates relationships from
metadata and organization; users inspect and refine.

Relationship types are **internal**. The product never asks users to classify relationships manually.

Sprint pipeline:

**Capture → Evidence → Evidence Collections → Primary Evidence → Supporting Evidence → Relationships → Investigation → Memory Recall → Risk Coach**

- Collections (Organize) ≠ Relationships (Investigation) ≠ Supporting Evidence
- Deterministic RELATED may be suggested from time / location / collection
- SUPPORTS stays conservative (user-established supporting assignment)
- Future AI plugs into `RelationshipSuggestionProvider` without changing Capture
- Memory Recall (Vault) asks what should be remembered; Risk Coach (Investigation) asks what may need attention
- Memory Recall consumes library + investigation signals; AI Memory Recall is future architecture only
- Risk Coach consumes Investigation Graph + Collections; `AIRiskAssessmentProvider` is future architecture only
- Neither Memory Recall nor Risk Coach is a chatbot, journal, or task manager

Relationships never modify original evidence. They preserve the evolving understanding of an incident over time.

Meaning is not captured in isolation. It **emerges** through the connections the system reveals—and the investigator accepts—between immutable pieces of evidence.

---

## 7. Story Philosophy

**View Story** is the intelligence centre of an incident.

It answers: **“What happened?”**

Story contains multiple perspectives on the same underlying Relationship Engine:

| View | Purpose |
|---|---|
| **Timeline** | Chronological reconstruction of events |
| **Connections** | How evidence relates to other evidence |
| **Summary** | Narrative synthesis of the incident |
| **Trust Status** | Verification and integrity at the incident level |

These are different **views of the same truth**—not separate data silos. Story is where chronology is emphasised. The workspace Journey is where preserved evidence is remembered visually.

---

## 8. Trust Philosophy

Trust is presented at the **incident level**.

**Trust Status** consists of:

| Dimension | Measures |
|---|---|
| **Verification** | Documentation completeness |
| **Integrity** | Evidence authenticity |

Individual evidence stores technical metadata, but **trust is communicated for the incident as a whole**. Users should understand whether their record is defensible—not decipher per-file checksums in the workspace.

Verification confirms that evidence is attributable and complete. Integrity confirms that preserved artifacts remain authentic. Both support the goal of trusted incident reports.

---

## 9. Simplicity Principle

Every design decision should **reduce friction**.

Users should spend time documenting events—not learning the interface.

Simplicity means:

- **Capture before thinking** — no prerequisite naming, categorization, or setup
- **Efficiency + effectiveness** — Capture Now establishes a new incident and opens Cockpit immediately; Continue Preserving returns to the real Workspace without detours; Workspace sticky actions preserve incident identity
- **Progressive documentation** — capture first; enrich when ready
- **Progressive disclosure** — show what is needed now; reveal depth on demand
- **Calm under stress** — clear, restrained UI during difficult moments
- **Consistency** — predictable patterns across every surface
- **Engine over interface** — complexity moves into the platform engine, not into UI (DI-3.0)

Friction that does not directly serve preservation, enrichment, connection, or trust is removed. Empty Workspace staging before capture is friction — not simplicity.

Permanent engineering guardrails, review checklist, and design rules: [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

---

## 10. Future AI Philosophy

**AI assists. AI never replaces the user's account.**

AI may:

- Suggest context
- Infer relationships
- Identify missing information
- Prepare narratives
- Draft Trust Packages

Users always remain in control.

### AI boundaries

AI **must**:

- Label generated output clearly
- Reference supporting evidence
- Express confidence where applicable
- Say when evidence is insufficient

AI **must never**:

- State facts unsupported by evidence
- Link incidents automatically
- Rewrite chronology
- Modify or delete evidence
- Replace professional judgment
- Become the source of truth

All AI output is subordinate to captured evidence.

---

## Evidence & Immutability

These principles are permanent. They apply to every surface that touches preserved evidence.

> **Evidence itself never changes.**  
> **Understanding grows around it.**

### Evidence Record

An **Evidence Record** is the permanent home of one preserved artifact. It is observational—designed for reading, understanding, and enriching—not editing or replacing captured evidence.

Every Evidence Record answers four questions:

| Question | Pillar |
|---|---|
| What was preserved? | **Evidence** |
| Can I trust it? | **Integrity** |
| What helps me understand it? | **Context** |
| Where did it come from? | **Metadata** |

The canonical enrichment action is **Add Context**. The product must never offer Edit Evidence, Replace Evidence, or Modify Evidence within the Evidence Record experience.

Future capabilities—relationships, reflection, chain of custody, AI analysis—extend understanding. They never alter preserved artifacts.

---

## UX & Interaction Principles

### Thumb-first interaction

Evidence Vault is designed for one-handed use during real-world situations. Primary capture actions receive ergonomic priority over informational content. Frequently used controls must be comfortably reachable.

### Trust through transparency

Users must always understand what the platform does with their evidence: what is captured, stored, verified, and presented. Hidden behaviour erodes trust.

### Motion with purpose

Animation confirms actions and maintains context—it does not decorate, delay capture, or obscure information.

### Information before decoration

Visual design supports comprehension. Evidence, context, and trust signals take precedence over ornamental elements.

Language must align with [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md).

---

## Incident Lifecycle

Operational status is separate from Journey maturity:

```
Draft → Active → Paused → Finalized → Archived
```

| Status | Meaning |
|---|---|
| **Draft** | Created by first capture; open to enrichment |
| **Active** | Actively being documented |
| **Paused** | Suspended; resumable without loss |
| **Finalized** | Core evidence and chronology locked for intended purpose |
| **Archived** | Long-term preservation in the Library of Truth |

---

## Engineering Principles

Evidence Vault is built to match the seriousness of what it preserves.

| Principle | Requirement |
|---|---|
| **Security first** | Protection of evidence and user data is foundational |
| **Privacy by design** | Minimize exposure; users control capture, storage, and sharing |
| **Offline-first where practical** | Capture must not depend on connectivity |
| **Automatic saving** | Evidence and incident state save continuously and reliably |
| **Performance** | Capture, review, and search must be fast |
| **Accessibility** | Usable by people with diverse abilities |
| **Scalable architecture** | Support growth without compromising integrity |
| **Maintainable code** | Clear separation of services, models, and presentation |

---

## Non-Negotiables

1. **One incident = one truth record.** Incidents are never automatically merged or linked.
2. **Capture is always faster than categorization.** No workflow requires organization before evidence is recorded.
3. **Evidence is never silently modified or deleted.** Changes must be explicit, auditable, and user-initiated.
4. **Chronology is preserved forever.** Order and timing are never rewritten—by users, AI, or the system.
5. **Enrichment surrounds evidence; it does not replace it.** Supplementary context adds meaning without overwriting originals.
6. **Users do not draw relationship lines or classify relationship types.** The system generates relationships; semantics are internal or AI-inferred.
7. **AI assists but never becomes the source of truth.** All AI output is evidence-bound and explainable.
8. **The Workspace is Incident State — never an empty capture staging screen.** It is for capture and build of a real/current incident—not dashboards or file-manager patterns.
9. **Capture Cockpit is Active Capture State.** It captures Photo / Video / Voice on an existing `incidentId`; it never creates or replaces an incident.
10. **Capture Now establishes a new incident before Cockpit**, then returns to that same incident’s Workspace. Continue Preserving opens existing Workspace only (no auto-Cockpit).
11. **The Journey guides; it never blocks.** Trust Packages are available at any stage.
12. **Trust is communicated at the incident level.** Verification and integrity serve the whole record.
13. **The product must feel calm during moments of stress.** Design reduces pressure—it never amplifies it.
14. **When trust and convenience conflict, trust wins.**
15. **Intelligence grows in the engine; simplicity grows in the interface.** Every feature must pass the guardrail question in [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) before implementation.
16. **Incident identity is preserved across capture, Workspace, Cockpit, and recovery.** No silent duplication or empty-draft replacement. Full invariant list: [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md).

---

## Product North Star

Evidence Vault exists to help people **reconstruct the truth of an incident with confidence**.

Evidence Vault should become **more intelligent every release**. The interface should become **simpler every release**.

Every feature should answer:

**Does this help the user preserve, enrich, connect, or understand the truth more naturally?**

And the permanent engineering guardrail (DI-3.0):

**Does this make the user's thinking calmer, or does it make the software more complicated?**

If either answer is no, it does not belong in the core product — or it must be redesigned so complexity moves into the engine, not the interface. See [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

---

*This constitution governs all current and future development of Evidence Vault. When in doubt, return to this document.*
