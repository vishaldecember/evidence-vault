**Version:** DI-3.0  
**Status:** Active — Product Philosophy Evolution  
**Last Updated:** August 4, 2026 (Permanent Product Rule — Onboarding Freeze)

# Evidence Vault Product Philosophy

This document describes the **evolved product philosophy** of Evidence Vault as an **Investigation Platform** — **a calm documentation experience powered by an intelligent investigation engine**.

Investigators document what they observed. The platform reasons about structure, completeness, and support behind the scenes. The investigator always remains in control.

Related specifications:

- [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) — why Evidence Vault exists (DI-1.5)
- [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — product constitution
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engine architecture (DI-1.4)
- [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) — sprint implementation and repository wiring
- [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) — bounded contexts (DI-1.2)
- [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) — reconstruction pipeline (DI-1.3)
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engines and services (DI-1.4)
- [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) — workspace and navigation
- [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) — terminology and voice
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map
- [`ROADMAP.md`](ROADMAP.md) — platform intelligence roadmap (DI-3.0)
- [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — permanent engineering guardrails (DI-3.0)

It complements [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md), which remains the product constitution for rules, non-negotiables, and operational behaviour. When this document and Product Principles align on philosophy, both apply. When operational rules are needed, Product Principles wins.

---

## Platform Philosophy

**Simple Experience. Sophisticated Engine. Human Documentation. Machine Assistance.**

Evidence Vault hides investigative complexity behind a calm, human-first experience. Users should never feel they are operating professional investigation software. They should feel they are calmly documenting what happened — while the platform translates that documentation into investigation structure automatically.

The investigator always remains in control.

---

## Simplicity Above Intelligence

### Founder Principle #7 — Simplicity Above Intelligence

Evidence Vault should become increasingly intelligent without becoming increasingly complicated.

Every improvement in reasoning should reduce effort for the investigator rather than introduce new concepts to learn.

Sophisticated investigation happens inside the engine.

Simple documentation happens in the interface.

### Principle 1 — Complexity Belongs to the Engine

The following remain **internal implementation details**. Users never manage these systems directly:

- Investigation graphs
- Relationships (as engine structures)
- Confidence evaluation
- Coaching
- Health evaluation
- Simulation
- Reasoning pipelines

The presentation layer consumes their outputs — it does not expose their mechanics.

### Principle 2 — Users Document. The Platform Reasons.

The investigator's responsibility is to **document what they observed**.

Evidence Vault quietly:

- **Preserves** observations as captured
- **Organises** evidence into usable records
- **Connects** related artifacts
- **Evaluates** completeness and consistency
- **Strengthens** documentation through neutral coaching

Reasoning happens behind the scenes. Documentation happens in the interface.

### Principle 3 — Coaching Without Conclusions

Evidence Vault never tells users what happened.

Evidence Vault never determines intent.

Evidence Vault never provides legal advice.

Evidence Vault asks better investigative questions.

Examples of appropriate coaching language:

- "Would another observation strengthen this event?"
- "This evidence appears unconnected."
- "This event has limited supporting evidence."

### Principle 4 — Progressive Disclosure

The interface should remain approachable for someone documenting an incident for the first time.

Advanced reasoning should appear only when it naturally helps the user — never as prerequisite setup or mandatory workflow.

The platform grows with the investigation.

The interface never grows in complexity.

### Principle 5 — People Think In Stories. Not Investigation Graphs.

Users should never feel they are operating professional investigation software.

They should feel they are calmly documenting what happened.

Evidence Vault translates their documentation into investigation structure automatically.

Users should not need to understand graph topology, confidence models, or engine boundaries to document an incident well.

---

## Product Identity

Evidence Vault is **not investigation software**.

Evidence Vault is a **calm documentation platform powered by an intelligent investigation engine**.

Users document. The platform quietly organises, reasons, and strengthens. The investigator always remains in control.

---

## Product North Star

Evidence Vault should become **more intelligent every release**.

The interface should become **simpler every release**.

Every feature must still serve reconstruction — but intelligence grows in the engine, not in the interface. See [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) for permanent engineering guardrails.

---

## Permanent Engineering Guardrails

These principles are **permanent**. Every future sprint, feature, refactor, and design decision must be evaluated against them before implementation.

Authoritative engineering checklist and design rules: [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

### The guardrail question

Before implementing **any** feature, answer:

> **Does this make the user's thinking calmer, or does it make the software more complicated?**

If the feature increases visible complexity for the user, **redesign it**. Complexity must move into the platform engine — not into the interface.

### Engineering review checklist

Before implementing any future feature, evaluate:

1. Can this be solved inside the engine instead of adding UI?
2. Can an existing workflow accomplish this instead of creating a new one?
3. Will a first-time user immediately understand this?
4. Does this reduce cognitive load?
5. Does this preserve the feeling that the user is documenting an incident rather than operating investigation software?
6. If Apple were designing this feature, would they add another screen — or make the existing experience feel smarter?

If any answer is **No**, propose a simpler implementation before writing code.

### Design rules

Evidence Vault should always favour:

- Fewer screens
- Fewer buttons
- Fewer concepts
- Fewer decisions
- Fewer workflows

…while allowing the platform engine to become increasingly intelligent.

Never expose internal concepts unnecessarily. Examples of internal concepts: confidence graphs, investigation graphs, health engines, coaching engines, reasoning pipelines. **Expose only the outcome that helps the investigator.**

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

**Onboarding is functionally complete.** Do not continue iterating on registration screens unless user research demonstrates a genuine usability issue. Future innovation must occur inside the investigation experience — not before it.

Authoritative freeze and exception criteria: [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md).

### Engineering Rule

Do not redesign onboarding unless one of the following occurs:

1. Usability testing demonstrates measurable friction.
2. Accessibility requirements change.
3. Authentication architecture changes.

Otherwise: freeze onboarding. Focus engineering effort on investigation workflows.

### Future Priorities

Allocate future design effort toward:

- Investigation Persistence Engine
- Witness Domain
- Investigation Health Engine
- Adaptive Investigation Coaching
- Trust Package
- Investigation Reconstruction
- Timeline Intelligence
- Cross-device continuity

These systems create product differentiation. Onboarding does not.

### Decision Filter

Before accepting any new feature, ask:

> **Does this improve the investigation?**

If not, challenge whether it belongs in the product.

**Success criteria:** Future roadmap discussions prioritise investigation capability over onboarding polish. The first minute gets users into the product. The next ten minutes demonstrate why Evidence Vault exists.

---

## Platform Evolution

Evidence Vault began as a product focused on **preserving evidence**. It has evolved into an **Investigation Platform** — a place where people move from scattered observations to structured incident intelligence.

This is not a pivot away from preservation. Preservation remains foundational. The evolution recognises that **collecting evidence is only the first step** in understanding what happened.

Evidence Vault is **investigator-first**. The platform serves people who need to reconstruct incidents with rigour — whether they are individuals documenting a difficult moment or professionals building a defensible record. Every surface, workflow, and design decision should respect the investigator's role: **document what was observed** — without the product substituting its judgment for theirs.

Evidence Vault helps people **transform fragmented observations into structured incident intelligence** — through documentation, not through operating investigation machinery.

The platform:

- **Preserves** observations as they were captured
- **Reveals** relationships between preserved records
- **Reconstructs** chronology from evidence
- **Communicates** findings through structured presentation

The platform **does not determine truth**. It does not adjudicate, conclude, or declare what happened. It provides structure, integrity, and clarity so investigators can form and communicate their own understanding from preserved evidence — while keeping the experience calm and documentation-focused.

---

## Product Journey (Incident Status Lifecycle)

The product journey describes **where investigators work** — not how far they have “completed” a process. It is workspace orientation, not progress tracking.

These four stages together represent the **Incident Status** lifecycle:

```
Capture
   ↓
Organize
   ↓
Investigation
   ↓
Trust Package
```

### Capture

**Purpose:** Preserve what happened.

Capture is the moment observations enter the platform — photos, video, voice, notes, and attachments recorded before memory fades or accounts diverge. The Capture stage exists so investigators can act immediately, without prerequisite setup, categorisation, or naming.

The Capture surface is the primary entry for preservation. Speed, calm, and thumb-first ergonomics matter here because capture often happens under stress.

### Organize

**Purpose:** Organize and enrich your records.

Organize is where preserved observations become **usable records**. Investigators add context, name the incident progressively, and enrich individual items without altering what was originally captured. The platform organises and connects evidence in the background — investigators document; they do not manually manage investigation graphs.

This stage is about **structure around facts** — not conclusions. Enrichment surrounds evidence; it never replaces it.

### Investigation

**Purpose:** See the incident as a whole — without operating investigation software.

Investigation is where timeline, connections, and narrative appear as **synchronized views** of the same underlying documentation. The platform surfaces structure the investigator built through capture and context; the investigator interprets meaning. Coaching and health evaluation assist quietly inside this workspace — see [Investigation Coaching Philosophy](#investigation-coaching-philosophy).

### Trust Package

**Purpose:** Prepare a professional presentation.

Trust Package is the structured presentation layer — a canonical assembly of incident summary, timeline, evidence, relationships, reconstruction, and integrity signals prepared for review and sharing.

It is not an export format alone. It is the **presentation model** through which findings are communicated with professionalism and structural integrity — ready for PDF, print, archive, or secure sharing when the investigator is prepared.

---

## Investigation Coaching Philosophy

Evidence Vault includes an Investigation Coaching layer that assists investigators throughout the investigation process.

Investigation Coaching is not a chatbot.

It is not a legal advisor.

It does not determine what happened.

It never infers intent.

It never replaces investigator judgement.

Its role is to help investigators identify opportunities to strengthen an investigation using evidence already contained within the Evidence Vault.

Investigation Coaching represents the **Strengthen** phase of the Evidence Vault philosophy.

This is not a separate navigation stage.

It exists inside the Investigation Workspace.

The product philosophy is:

| Phase | Role |
|---|---|
| **Capture** | Preserve evidence. |
| **Evidence** | Organise evidence. |
| **Investigation** | Understand chronology, relationships and narrative. |
| **Investigation Coaching** | Strengthen the investigation through neutral, evidence-based guidance. |
| **Trust Package** | Present the investigation. |

Examples of coaching include:

- Missing observations
- Weakly supported narrative events
- Unconnected evidence
- Timeline gaps
- Investigation readiness

The coach asks better investigative questions.

It never provides investigative conclusions.

Investigation Coaching will evolve incrementally across future sprints — expanding categories, signals, and presentation — while remaining **investigator-first**. The platform may surface more opportunities to strengthen documentation; it will not become an autonomous investigator, legal advisor, or conclusion engine.

---

## The Investigation Method

The Investigation Method describes **what the platform does with documentation** — not a checklist the user must perform manually. Investigators document; the platform organises, connects, reconstructs, and prepares presentation.

```
Document observations
        ↓
Enrich with context
        ↓
Discover relationships (engine-assisted)
        ↓
Reconstruct chronology (engine-assisted)
        ↓
Communicate findings
```

| Step | User action | Platform action |
|---|---|---|
| **Document observations** | Capture what was seen, heard, or experienced | Preserve immutably; anchor timeline |
| **Enrich with context** | Add notes and supporting detail | Organise records; evaluate completeness |
| **Discover relationships** | Connect related items when ready | Maintain graph structure; surface coaching |
| **Reconstruct chronology** | Review and refine narrative | Derive timeline and narrative projections |
| **Communicate findings** | Prepare Trust Package when ready | Assemble presentation with integrity signals |

The Investigation Method is **continuous**. Investigators may move between steps as understanding grows. The platform orients; it does not force sequence or block access based on “completion.”

The Investigation Journey header across workspace surfaces reflects the **Product Journey / Incident Status lifecycle** (Capture → Organize → Investigation → Trust Package). The Investigation Method describes the **platform work** underneath calm documentation.

---

## Core Product Principles

These principles govern how Evidence Vault behaves as an Investigation Platform. They apply to product, design, and engineering decisions.

### Facts before conclusions

The platform presents preserved evidence and structured relationships first. Narrative, synthesis, and presentation follow from facts — never the reverse. Evidence Vault must not lead investigators to a conclusion the record does not support.

### Relationships before assumptions

Connected evidence reveals structure. The platform helps investigators discover how artifacts relate before they infer meaning in isolation. Relationship groups, links, and connection views exist to make structure visible — not to guess intent.

### Chronology before interpretation

Time order is sacred. The platform reconstructs when things happened from preserved evidence and anchors before it asks what they mean. Chronology is never rewritten — by users, by AI, or by the system.

### Trust through structure

Trust is not a badge applied at the end. It grows from how evidence is preserved, enriched, connected, ordered, and presented. Structural integrity — immutability, verification signals, coherent assembly — is how the platform earns confidence.

### Investigator neutrality

The platform accompanies the investigator. It preserves, organises, reveals, reconstructs, and communicates. It does not judge, adjudicate, or replace professional or personal judgment. The investigator remains the authority over what the record means.

---

## Product Principle

Evidence Vault should **continuously orient investigators** without making the experience feel like completing a form or following a tutorial.

Orientation is persistent, calm, and structural — workspace navigation and methodology guidance, not onboarding steps or gamified progress.

---

## Relationship to Product Principles

| Topic | Authoritative document |
|---|---|
| Investigation Platform philosophy (this evolution) | **This document** — `PRODUCT_PHILOSOPHY.md` |
| Investigation Coaching philosophy | **This document** — [Investigation Coaching Philosophy](#investigation-coaching-philosophy) |
| Simplicity Above Intelligence (DI-3.0) | **This document** — [Simplicity Above Intelligence](#simplicity-above-intelligence) |
| Onboarding freeze | [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) |
| Engineering guardrails (DI-3.0) | [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) |
| Product constitution, rules, non-negotiables | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) |
| Platform architecture and engines | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) |
| Workspace UX and navigation | [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) |
| Terminology and copy | [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) |

---

*Permanent Product Rule — Onboarding is not the product. Investigation capability is the priority.*
