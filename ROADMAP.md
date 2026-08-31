**Version:** DI-3.1  
**Status:** Active — Platform Intelligence Roadmap  
**Last Updated:** August 4, 2026 (Permanent Product Rule — Onboarding Freeze)

# Evidence Vault Platform Roadmap

This document describes how **future intelligence capabilities** evolve on the Evidence Vault platform. It is a philosophy and planning document — not a sprint backlog.

**Governing principle:** Evidence Vault should become increasingly intelligent without becoming increasingly complicated. Every improvement in reasoning should reduce effort for the investigator rather than introduce new concepts to learn.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Simplicity Above Intelligence; Founder Principle #7
- [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) — founding vision and manifesto
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — engine architecture and extension model
- [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — permanent engineering guardrails (DI-3.0)
- [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) — onboarding freeze and decision filter
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map

---

# Permanent Product Rule

## Onboarding is not the product.

Onboarding is **functionally complete**. Its only job is trust, account creation, and fastest path into investigation. Competitive advantage is created inside Capture, Organize, Investigation, Trust Package, and Investigation Coaching — not registration screens.

Do not redesign onboarding unless usability testing shows measurable friction, accessibility requirements change, or authentication architecture changes. Otherwise **freeze onboarding**.

Full rule: [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md).

### Future Priorities (investigation first)

Roadmap and design effort prioritise:

- Investigation Persistence Engine
- Witness Domain
- Investigation Health Engine
- Adaptive Investigation Coaching
- Trust Package
- Investigation Reconstruction
- Timeline Intelligence
- Cross-device continuity

**Decision filter:** Does this improve the investigation? If not, challenge whether it belongs.

**Success criteria:** Roadmap discussions prioritise investigation capability over onboarding polish. The first minute gets users into the product. The next ten minutes demonstrate why Evidence Vault exists.

---

## Platform Philosophy

**Simple Experience. Sophisticated Engine. Human Documentation. Machine Assistance.**

Investigators document what they observed. Evidence Vault quietly preserves, organises, connects, evaluates, and strengthens the investigation behind the scenes. The investigator always remains in control.

---

## Intelligence Features — Always Background Capabilities

Future intelligence features **never become additional user workflows**. They remain **background capabilities** consumed by the presentation layer when they naturally help the investigator.

| Capability | What it is (engine) | What the user experiences |
|---|---|---|
| **Investigation Coaching** | Rule-based and evidence-bound coaching signals derived from engine state | Neutral questions in the Investigation Workspace — dismissible, non-blocking |
| **Investigation Health** | Structured health metrics and findings (SIC-2.1A foundation) | Better coaching and readiness signals — not a health dashboard to manage |
| **Simulation** | Engine-level what-if projection against the incident record | Contextual assistance when reconstruction benefits — not a standalone simulation mode |
| **Trust Readiness** | Derived evaluation of Trust Package completeness and integrity | Preparation guidance before communication — never a gate on export or assembly |

Users never manage investigation graphs, confidence models, health scoring, coaching rules, reasoning pipelines, or simulation state directly. These systems remain internal implementation details.

---

## Roadmap Commitments

### 1. Complexity belongs to the engine

Investigation graphs, relationships, confidence, coaching, health evaluation, simulation, and reasoning pipelines remain inside the platform. The interface consumes their outputs — it does not expose their mechanics.

### 2. Users document. The platform reasons.

The investigator's responsibility is to document what they observed. Reasoning happens behind the scenes. Documentation happens in the interface.

### 3. Coaching without conclusions

Evidence Vault never tells users what happened. It never determines intent. It never provides legal advice. It asks better investigative questions.

Examples:

- "Would another observation strengthen this event?"
- "This evidence appears unconnected."
- "This event has limited supporting evidence."

### 4. Progressive disclosure

The interface remains approachable for someone documenting an incident for the first time. Advanced reasoning appears only when it naturally helps. The platform grows with the investigation. The interface never grows in complexity.

### 5. People think in stories. Not investigation graphs.

Users should never feel they are operating professional investigation software. They should feel they are calmly documenting what happened. Evidence Vault translates documentation into investigation structure automatically.

---

## Capability Evolution Paths

### Investigation Coaching

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

Coaching lives **inside** the Investigation Workspace. It is not a standalone stage, chat surface, or mandatory workflow.

### Investigation Health

```
SIC-2.1A  Foundation — structured health metrics and findings (domain service)
    ↓
Future    Consumed by coaching and readiness layers — surfaced as
          neutral guidance, not scores or grades
    ↓
Future    Expanded finding categories — still internal; never a user-managed system
```

Health evaluation informs coaching and readiness. It does not become a separate investigation step.

### Simulation

```
Future    Engine-level projection against preserved evidence
    ↓
Future    Contextual "what-if" assistance during reconstruction —
          progressive disclosure only
```

Simulation assists reconstruction. It does not introduce a parallel investigation pipeline or require users to learn simulation concepts before documenting.

### Trust Readiness

```
Future    Derived readiness evaluation against Trust Package completeness
    ↓
Future    Advisory signals before communication — integrated into
          Trust Package workspace, not a separate readiness workflow
```

Readiness informs preparation. It never blocks Trust Package assembly or export.

---

## What This Roadmap Does Not Include

This roadmap does **not** authorise:

- New user-facing workflows for intelligence features
- Mandatory setup or configuration of coaching, health, or simulation systems
- Dashboards where users manage investigation graphs or confidence models
- Autonomous truth determination, intent inference, or legal advice
- Interface complexity that grows with engine sophistication

When in doubt, apply Founder Principle #7: **Simplicity Above Intelligence**.

---

## Permanent Engineering Guardrails

These principles are **permanent**. Every future sprint, feature, refactor, and design decision must be evaluated against them before implementation.

Authoritative home: [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md).

> **Does this make the user's thinking calmer, or does it make the software more complicated?**

If the feature increases visible complexity for the user, **redesign it**. Complexity must move into the platform engine — not into the interface.

Before implementing any feature, evaluate the six-question engineering review checklist in [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md). If any answer is **No**, propose a simpler implementation before writing code.

---

## Document Hierarchy

| Topic | Authoritative document |
|---|---|
| Simplicity Above Intelligence | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence) |
| Founder Principle #7 | [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) |
| Onboarding freeze / decision filter | [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) |
| Engineering guardrails | [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) |
| Engine architecture and extensions | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) |
| Investigation Coaching philosophy | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#investigation-coaching-philosophy) |
| Sprint implementation detail | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) |

---

*DI-3.1 — Onboarding freeze. Intelligence roadmap prioritises investigation capability.*
