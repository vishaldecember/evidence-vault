# Product Decision Framework

This framework defines how future product decisions are evaluated so that Evidence Vault remains faithful to its vision, philosophy, and long-term identity.

It must be consulted before introducing any new feature, workflow, AI capability, or user interaction. This document aligns with the Product Constitution ([`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md)), the Engineering Guardrails ([`AI_ENGINEERING_GUIDE.md`](../AI_ENGINEERING_GUIDE.md)), the UX Architecture ([`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md)), the Platform Architecture ([`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md)), and the Design System ([`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md)).

Every product decision should strengthen the core purpose of Evidence Vault rather than increase feature count.

**Both frameworks must pass before implementation:** this document evaluates product fit; [`AI_ENGINEERING_GUIDE.md`](../AI_ENGINEERING_GUIDE.md) evaluates implementation simplicity.

---

## The North Star

The authoritative North Star is defined in [`PRODUCT_PRINCIPLES.md` § Product North Star](../PRODUCT_PRINCIPLES.md).

Every feature must answer: **Does this help the user preserve, enrich, connect, or understand the truth more naturally?**

And the permanent engineering guardrail (DI-3.0): **Does this make the user's thinking calmer, or does it make the software more complicated?**

See [`AI_ENGINEERING_GUIDE.md`](../AI_ENGINEERING_GUIDE.md) for the full engineering review checklist.

---

## Decision Gate 1 — Does it Preserve Truth?

Ask:

Does this feature help users preserve reality more accurately?

If not, it probably does not belong.

---

## Decision Gate 2 — Does it Give Meaning to Truth?

Ask:

Does this help users understand, organise, or relate evidence without changing its authenticity?

Meaning should emerge through relationships, chronology, and context—not through modification of evidence.

---

## Decision Gate 3 — Does it Reduce Friction?

Evidence Vault should reduce the effort required to document reality.

Features should remove decisions rather than introduce them.

---

## Decision Gate 4 — Does it Respect Integrity?

Evidence must remain immutable.

No feature should alter timestamps, metadata, or captured content.

---

## Decision Gate 5 — Is Intelligence Progressive?

AI should appear only when users intentionally seek understanding.

Capture should remain interruption-free.

---

## Decision Gate 6 — Is It Unmistakably Evidence Vault?

Every proposed feature should pass two questions.

### Question 1

Could this feature exist in any other application?

If the answer is yes, continue to Question 2.

### Question 2

What makes this implementation unmistakably Evidence Vault?

The answer should demonstrate how the feature strengthens one or more of the following:

- Preservation of truth
- Integrity of evidence
- Progressive understanding
- Evidence relationships
- Evidence Chain
- Evidence Map
- Trust Package assembly
- Reduction of user effort
- Progressive Intelligence

If the feature cannot be distinguished from a generic implementation found in camera, notes, journaling, document management or productivity applications, it should be redesigned before implementation.

The objective is not to build more features.

The objective is to build features that only Evidence Vault would build.

---

## Product Hierarchy

Evidence Vault is built in three layers.

### Layer 1 — Capture

Preserve reality.

### Layer 2 — Organisation

- Chronology
- Relationships
- Evidence Chain
- Evidence Map
- Verification

### Layer 3 — Insight

- Trust Packages
- Pattern Detection
- AI-supported understanding

---

## Product Rule

When choosing between:

- more features
- greater clarity

always choose clarity.

---

## Decision Gate 5 — Does It Preserve the Documentation Experience?

Ask:

Does this preserve the feeling that the user is documenting an incident — rather than operating investigation software?

Features should:

- Favour fewer screens, buttons, concepts, decisions, and workflows
- Solve problems inside the engine when possible instead of adding UI
- Expose only outcomes that help the investigator — not internal engine concepts
- Pass the engineering review checklist in [`AI_ENGINEERING_GUIDE.md`](../AI_ENGINEERING_GUIDE.md)

If any checklist answer is **No**, propose a simpler implementation before writing code.

---

## Final Principle

Evidence Vault is not a camera application.

It is not a notes application.

It is not a journaling application.

It is a system for preserving truth and allowing its meaning to emerge over time.

Every future decision should strengthen that identity.

## Product Identity Test

When evaluating any future idea, always ask:

"Could this exist in any other app?"

If the answer is yes, ask:

"What makes it unmistakably Evidence Vault?"

Only when that answer is clear should implementation begin.

---

*This framework governs all current and future product decisions for Evidence Vault. When in doubt, return to this document.*
