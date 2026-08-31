**Version:** 1.0  
**Status:** Active — Permanent Development Guidelines  
**Last Updated:** August 4, 2026 (Onboarding Freeze)

# Evidence Vault Development Guidelines

Permanent product and engineering rules that govern what Evidence Vault builds next.

Related:

- [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — engineering review checklist and design rules
- [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) — Simplicity Above Intelligence
- [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engines
- [`ROADMAP.md`](ROADMAP.md) — intelligence and investigation priorities
- [`docs/DEVELOPMENT_BASELINE.md`](docs/DEVELOPMENT_BASELINE.md) — toolchain baseline

---

# Permanent Product Rule

## Onboarding is not the product.

The purpose of onboarding is to:

- establish trust
- create an account
- get users into their investigation as quickly as possible

Once onboarding is complete, engineering effort should shift toward improving the **investigation experience**.

Evidence Vault's competitive advantage is created inside:

- Capture
- Evidence
- Investigation
- Trust Package
- Investigation Coaching

—not during account creation.

**Onboarding is functionally complete.** Do not continue iterating on registration screens unless user research demonstrates a genuine usability issue. Future innovation must occur **inside** the investigation experience — not before it.

---

## Engineering Rule — Freeze Onboarding

Do **not** redesign onboarding unless one of the following occurs:

1. Usability testing demonstrates measurable friction.
2. Accessibility requirements change.
3. Authentication architecture changes.

Otherwise:

**Freeze onboarding.**  
Focus engineering effort on investigation workflows.

Allowed maintenance (not redesign): security patches, auth provider configuration, critical bug fixes that block account creation or session restore.

---

## Future Priorities

Allocate future design and engineering effort toward:

- Investigation Persistence Engine
- Witness Domain
- Investigation Health Engine
- Adaptive Investigation Coaching
- Trust Package
- Investigation Reconstruction
- Timeline Intelligence
- Cross-device continuity

These systems create product differentiation.  
**Onboarding does not.**

---

## Decision Filter

Before accepting any new feature, ask:

> **Does this improve the investigation?**

If not, challenge whether it belongs in the product.

Complementary guardrail ([`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md)):

> **Does this make the user's thinking calmer, or does it make the software more complicated?**

---

## Success Criteria

- Future roadmap discussions naturally prioritise investigation capability over onboarding polish.
- The first minute gets users into the product.
- The next ten minutes demonstrate why Evidence Vault exists.

---

*Permanent rule. Onboarding frozen unless research, accessibility, or authentication architecture requires change.*
