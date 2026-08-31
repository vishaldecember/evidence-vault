**Version:** DI-3.0  
**Status:** Active — Permanent Engineering Guardrails  
**Last Updated:** August 4, 2026 (Permanent Product Rule — Onboarding Freeze)

# Evidence Vault AI Engineering Guide

This document defines **permanent engineering guardrails** for Evidence Vault. It applies to every sprint, feature, refactor, and design decision — including work assisted by AI coding tools such as Cursor.

**Philosophy only.** This increment does not modify application code. It establishes how future code should be evaluated before it is written.

Related specifications:

- [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Simplicity Above Intelligence; Founder Principle #7
- [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — product constitution; Product Identity; Product North Star
- [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) — founding vision
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — engine architecture
- [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) — product decision gates
- [`ROADMAP.md`](ROADMAP.md) — intelligence as background capability
- [`DOCS_INDEX.md`](DOCS_INDEX.md) — documentation map

> **Note:** `AI_ENGINEERING_GUIDE.md` is the authoritative home for engineering guardrails. [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) remains the product decision framework — consult both before implementation.

---

## Product Identity

Evidence Vault is **not investigation software**.

Evidence Vault is a **calm documentation platform powered by an intelligent investigation engine**.

Users document. The platform quietly organises, reasons, and strengthens. The investigator always remains in control.

---

## Product North Star

Evidence Vault should become **more intelligent every release**.

The interface should become **simpler every release**.

Intelligence grows in the engine. Simplicity grows in the experience.

---

## Founder Principle #7 — Simplicity Above Intelligence

Evidence Vault should become increasingly intelligent without becoming increasingly complicated.

Every improvement in reasoning should reduce effort for the investigator rather than introduce new concepts to learn.

Sophisticated investigation happens inside the engine.

Simple documentation happens in the interface.

Full principles: [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence).

---

## Permanent Engineering Guardrail

Before implementing **any** feature, answer this question:

> **Does this make the user's thinking calmer, or does it make the software more complicated?**

If the feature increases visible complexity for the user, **redesign it**.

Complexity must move into the platform engine — **not** into the interface.

This guardrail is non-negotiable. It applies to UI, API surfaces, navigation, copy, settings, onboarding, and AI-assisted suggestions.

---

## Onboarding Freeze

**Onboarding is not the product.** Registration is functionally complete. Do not redesign create-account / login / name-collection flows unless:

1. Usability testing demonstrates measurable friction.
2. Accessibility requirements change.
3. Authentication architecture changes.

Otherwise freeze onboarding and invest in investigation workflows (Capture, Evidence, Investigation, Trust Package, Coaching).

Authoritative rule: [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md).

Before accepting any new feature:

> **Does this improve the investigation?**

If not, challenge whether it belongs.

---

## Engineering Review Checklist

Before implementing any future feature, **Cursor and all engineers** must evaluate:

| # | Question | Required answer |
|---|---|---|
| 1 | Can this be solved inside the engine instead of adding UI? | Prefer engine when possible |
| 2 | Can an existing workflow accomplish this instead of creating a new one? | Prefer existing workflow |
| 3 | Will a first-time user immediately understand this? | Yes |
| 4 | Does this reduce cognitive load? | Yes |
| 5 | Does this preserve the feeling that the user is documenting an incident rather than operating investigation software? | Yes |
| 6 | If Apple were designing this feature, would they add another screen — or make the existing experience feel smarter? | Smarter experience, not another screen |

**If any answer is No**, propose a simpler implementation before writing code.

Document the evaluation in the sprint or PR description when the change is non-trivial.

---

## Design Rules

Evidence Vault should always favour:

- **Fewer screens**
- **Fewer buttons**
- **Fewer concepts**
- **Fewer decisions**
- **Fewer workflows**

…while allowing the platform engine to become increasingly intelligent.

### Never expose internal concepts unnecessarily

The following remain **engine-internal**. Users never manage them directly:

- Confidence graphs
- Investigation graphs
- Health engines
- Coaching engines
- Reasoning pipelines
- Relationship topology as a user-managed system
- Simulation state
- Health scoring dashboards

**Expose only the outcome that helps the investigator** — a neutral question, a gentle nudge, a clearer view of what they documented — not the machinery that produced it.

### Complexity belongs to the engine

Investigation graphs, relationships, confidence, coaching, health evaluation, simulation, and reasoning pipelines remain internal implementation details. The presentation layer consumes their outputs; it does not expose their mechanics.

### Coaching without conclusions

Engine outputs that reach the user must follow coaching language rules. Evidence Vault never tells users what happened, never determines intent, and never provides legal advice. It asks better investigative questions.

Appropriate examples:

- "Would another observation strengthen this event?"
- "This evidence appears unconnected."
- "This event has limited supporting evidence."

### Progressive disclosure

Advanced reasoning appears only when it naturally helps the user. The platform grows with the investigation. The interface never grows in complexity.

---

## Intelligence Features — Background Only

Future intelligence capabilities are **background capabilities**, not new user workflows:

| Capability | Engine | User sees |
|---|---|---|
| Investigation Coaching | Derived signals | Neutral questions when helpful |
| Investigation Health | Structured metrics | Better coaching — not a dashboard |
| Simulation | Engine projection | Contextual help — not a simulation mode |
| Trust Readiness | Trust Package advisory | Preparation guidance — not a gate |

Full roadmap: [`ROADMAP.md`](ROADMAP.md).

---

## Relationship to Product Decision Framework

[`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) evaluates **product fit** — truth, meaning, friction, integrity, progressive intelligence.

This guide evaluates **implementation simplicity** — engine vs UI, cognitive load, screen count, internal concept exposure.

**Both must pass** before implementation begins.

When the frameworks conflict, **simplicity wins in the interface; intelligence wins in the engine**. Redesign until both are satisfied.

---

## Document Hierarchy

| Topic | Authoritative document |
|---|---|
| Engineering guardrails (this guide) | **This document** — `AI_ENGINEERING_GUIDE.md` |
| Onboarding freeze / decision filter | [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) |
| Simplicity Above Intelligence | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md#simplicity-above-intelligence) |
| Product constitution | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) |
| Product decision gates | [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) |
| Platform engine architecture | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) |
| Intelligence roadmap | [`ROADMAP.md`](ROADMAP.md) |

---

*Permanent guardrails. Onboarding frozen unless research, accessibility, or auth architecture requires change.*
