**Version:** 2.3  
**Status:** Documentation Map — Product Architecture Freeze  
**Last Updated:** August 10, 2026 (Sprint 6C — Capture Cockpit / Workspace source-of-truth)

# Evidence Vault Documentation Index

This index maps every markdown document in the repository and defines **one authoritative home** per concept. Updated for the **Product Architecture Freeze** milestone.

When documents conflict, resolve in this order:

1. [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — product constitution (vision, mission, identity, philosophy, rules)
2. [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) — permanent engineering guardrails (DI-3.0)
3. [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) — platform engine architecture (DI-1.4)
4. [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) — sprint implementation and repository wiring
5. [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) — user experience specification; navigation architecture (canonical Capture Now / Continue Preserving / Workspace flows)
6. [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) — Capture Cockpit source of truth; Workspace vs Cockpit invariants
7. [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) — terminology and copy
8. [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) — visual and interaction standards
9. Engineering and audit documents — operational reference only

---

## Authoritative Homes

| Concept | Authoritative document | Section |
|---|---|---|
| **Why Evidence Vault exists** (vision manifesto) | [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | Full manifesto; Founder Principle #7 (DI-3.0) |
| **Vision** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | § 1. Product Vision |
| **Mission** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | § 1. Product Vision → Mission |
| **Product Philosophy** | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | Platform evolution, Simplicity Above Intelligence, Investigation Method |
| **Simplicity Above Intelligence** (DI-3.0) | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | Simplicity Above Intelligence; Founder Principle #7 |
| **Onboarding freeze** | [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) | Onboarding is not the product; investigation-first priorities |
| **Founder Manifesto** *(nearest equivalent)* | [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | Founder Principle #7; founding vision |
| **Engineering guardrails** (DI-3.0) | [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) | Guardrail question; engineering review checklist; design rules |
| **Product Vision** *(nearest equivalent)* | [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) + [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | Manifesto + Platform Philosophy |
| **Product Identity** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | Product Identity |
| **Product Category** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | Product Category |
| **Product North Star** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | Product North Star |
| **Product constitution** (rules, non-negotiables) | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | § 2–§ 10, Non-Negotiables |
| **Incident Reconstruction Platform** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | Product Category; § 1 |
| **Library of Truth** (user experience) | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | § 2; Product Identity |
| **Capture Engine** (platform core) | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | § 1. Capture Engine |
| **Evidence Engine** (platform core) | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | § 2. Evidence Engine |
| **Relationship Engine** (platform core) | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | § 3. Relationship Engine |
| **Narrative Engine** (platform core) | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | § 4. Narrative Engine |
| **Trust Package Engine** (platform core) | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | § 5. Trust Package Engine |
| **Platform Services** | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | Platform Services |
| **Enrichment Engine** *(legacy name)* | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Maps to Evidence Engine — see DI-1.4 |
| **Story Engine** *(legacy name)* | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Maps to Narrative Engine — see DI-1.4 |
| **Trust Engine** *(legacy name)* | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Maps to Trust Package Engine — see DI-1.4 |
| **Primary Evidence / Enrichment hierarchy** | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Domain Hierarchy |
| **Incident Status maturity model** | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Incident Status Model |
| **Evidence Workspace** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) § 3 + [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) | Incident State — persistent incident environment |
| **Capture Cockpit** | [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) | Active Capture State — Photo / Video / Voice only |
| **Capture Now / Continue Preserving flows** | [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) § 2–§ 4 + [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) | Canonical Home capture navigation |
| **Investigation Platform philosophy** | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | Product Journey; Investigation Method |
| **Incident Status** (maturity model) | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) Incident Status Model + [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) § 4–§ 5 |
| **View Story** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) § 7 + [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) | Intelligence centre (Story Engine) |
| **Trust Status** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | § 8 |
| **Trust Package** | [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) § 3 + [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) § 4 Trust Engine | Shareable report |
| **Investigation Engine** (reconstruction pipeline) | [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) | Investigation pipeline; Timeline vs Narrative |
| **Platform data model** | [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) | Bounded contexts; object responsibilities |
| **Platform engine architecture** | [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | Core engines; future extensions; intelligence roadmap (DI-3.0) |
| **Platform intelligence roadmap** | [`ROADMAP.md`](ROADMAP.md) | Coaching, Health, Simulation, Trust Readiness as background capabilities (DI-3.0) |
| **Backend architecture** (Firebase) | [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) | MVP-0.9.3.1 — ownership, sync, delete, Firebase stack |
| **Firestore data model** | [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) | Collection schemas, fields, relationships |
| **Firebase Storage structure** | [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) | Evidence file paths, trust package exports |
| **Authentication flow** | [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) | Auth lifecycle — email, Google, Apple (future) |
| **Firebase developer setup** | [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) | Project setup, packages, FlutterFire CLI onboarding |
| **Auth session foundation** | [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md) | MVP-0.9.3.3A — AuthService, session restore, validation |
| **Backend implementation roadmap** | [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) | Phased Firebase integration plan |
| **Investigation Coaching philosophy** | [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | Investigation Coaching Philosophy (DI-2.0) |
| **Investigation Health Engine** | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | SIC-2.1A — structured health metrics (domain service) |
| **Participant domain** | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Epic 2 Sprint 2.1 — participants as first-class entities |
| **Platform implementation wiring** | [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | Repositories; Sprint 9.x detail |
| **User-facing vocabulary** | [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) | Standard Vocabulary |
| **Visual system** | [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Full design constitution |
| **Interaction philosophy** | [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Interaction Philosophy |
| **Reachability ergonomics** | [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Reachability Principles |
| **Feature decision gates** | [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) | Decision Gates |
| **Engineering environment** | [`docs/DEVELOPMENT_BASELINE.md`](docs/DEVELOPMENT_BASELINE.md) | Baseline |
| **Daily build verification** | [`docs/BUILD_HEALTH.md`](docs/BUILD_HEALTH.md) | Checklist |
| [`PLATFORM_BASELINE_v1.0.md`](PLATFORM_BASELINE_v1.0.md) | Platform Baseline — pre-backend snapshot (Sprint 8) |
| [`SPRINT_8.5_UX_REFINEMENT.md`](SPRINT_8.5_UX_REFINEMENT.md) | Post-baseline UX refinements (Sprint 8.5) |

---

## Document Catalogue

### Product & Architecture (active specifications)

| Document | Responsibility |
|---|---|
| [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | **Platform manifesto (DI-3.0).** Why Evidence Vault exists; Founder Principle #7 — Simplicity Above Intelligence. |
| [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) | **Platform architecture (DI-3.0).** Five core engines + Platform Services; intelligence as background capability; extension model. |
| [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) | **Product philosophy (DI-3.0).** Calm documentation experience; Simplicity Above Intelligence; Investigation Coaching Philosophy. |
| [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) | **Permanent engineering guardrails (DI-3.0).** Guardrail question; engineering review checklist; design rules; intelligence as background capability. Required before any implementation. |
| [`DEVELOPMENT_GUIDELINES.md`](DEVELOPMENT_GUIDELINES.md) | **Permanent development guidelines.** Onboarding freeze; investigation-first priorities; decision filter (*Does this improve the investigation?*). |
| [`ROADMAP.md`](ROADMAP.md) | **Platform intelligence roadmap (DI-3.0).** Coaching, Health, Simulation, Trust Readiness — always background capabilities, never new user workflows. |
| [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) | **Backend architecture (MVP-0.9.3.1).** Firebase stack, ownership model, sync/delete strategy, risks. |
| [`FIRESTORE_DATA_MODEL.md`](FIRESTORE_DATA_MODEL.md) | **Firestore schema (MVP-0.9.3.1).** users, incidents, evidence, participants, relationships, narrativeEvents, trustPackages. |
| [`STORAGE_STRUCTURE.md`](STORAGE_STRUCTURE.md) | **Firebase Storage layout (MVP-0.9.3.1).** Evidence binaries and export paths. |
| [`AUTHENTICATION_FLOW.md`](AUTHENTICATION_FLOW.md) | **Authentication architecture (MVP-0.9.3.1).** Email, Google, Apple; no anonymous users. |
| [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md) | **Firebase developer onboarding (MVP-0.9.3.2).** Project setup, packages, FlutterFire CLI, validation checklist. |
| [`BACKEND_ROADMAP.md`](BACKEND_ROADMAP.md) | **Backend implementation phases (MVP-0.9.3.2).** Phase 0–8 from architecture to production. |
| [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | **Single source of truth (v3.1 / DI-3.0).** Vision, Mission, Product Identity, Product Category, Core Beliefs, Product North Star, simplicity guardrails, non-negotiables. |
| [`docs/INVESTIGATION_ENGINE.md`](docs/INVESTIGATION_ENGINE.md) | **Investigation Engine (DI-1.3).** Domain reconstruction pipeline; layer purposes; UI-independent workflow; Timeline records history / Narrative explains history. |
| [`docs/DOMAIN_MODEL.md`](docs/DOMAIN_MODEL.md) | **Domain architecture (DI-1.5).** Bounded contexts within Incident; CaptureSession; Workspace/Cockpit as presentation surfaces; Timeline Events vs Narrative Events. |
| [`docs/CAPTURE_COCKPIT_ARCHITECTURE.md`](docs/CAPTURE_COCKPIT_ARCHITECTURE.md) | **Capture Cockpit source of truth (Sprint 6C).** Workspace vs Cockpit; canonical flows; incident identity; Note/File boundary; non-negotiable invariants. |
| [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | **Implementation architecture (v2.1).** Repository wiring, sprint history, legacy four-engine naming. Canonical platform engines: [`PLATFORM_ARCHITECTURE.md`](../PLATFORM_ARCHITECTURE.md) (DI-1.4). |
| [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) | **UX specification + navigation architecture.** Canonical Capture Now / Continue Preserving / Workspace sticky flows; Workspace Incident State; Cockpit Active Capture State. |
| [`docs/EVIDENCE_RECOVERY_ARCHITECTURE.md`](docs/EVIDENCE_RECOVERY_ARCHITECTURE.md) | **Evidence recovery.** Local commit barrier; same-`incidentId` recovery invariant; hydration; auth boundaries. |
| [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) | **Decision framework.** Product decision gates; must be used together with [`AI_ENGINEERING_GUIDE.md`](AI_ENGINEERING_GUIDE.md) for implementation. |

### Language & Design (active specifications)

| Document | Responsibility |
|---|---|
| [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) | **Language architecture (v2.0).** Standard vocabulary, deprecated terms, voice, canonical Journey copy, Trust Package language. |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | **Full design system (v2.0).** Colours, typography, spacing, components, Interaction Philosophy. |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | **Reachability supplement.** Thumb-zone rules only. Root `DESIGN_SYSTEM.md` is authoritative for visual system. |

### Engineering

| Document | Responsibility |
|---|---|
| [`backend/README.md`](backend/README.md) | Backend implementation root pointer (future Firebase rules, functions). |
| [`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md) | Firebase backend overview — MVP-0.9.3.1 architecture blueprint. |
| [`docs/DEVELOPMENT_BASELINE.md`](docs/DEVELOPMENT_BASELINE.md) | Engineering baseline — toolchain versions and recovery. |
| [`docs/BUILD_HEALTH.md`](docs/BUILD_HEALTH.md) | Daily pre-sprint health checklist. |
| [`PLATFORM_BASELINE_v1.0.md`](PLATFORM_BASELINE_v1.0.md) | **Platform Baseline v1.0** — official pre-backend snapshot at Architecture Freeze. Read with Sprint 8.5 notes for current UX state. |
| [`SPRINT_8.5_UX_REFINEMENT.md`](SPRINT_8.5_UX_REFINEMENT.md) | **Sprint 8.5** — post-baseline UX refinement and product finalization log. |
| [`README.md`](README.md) | Flutter project stub — not product documentation. |

### Vision & philosophy documents

| Document | Status |
|---|---|
| [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | **Active (DI-3.0).** Platform manifesto — why Evidence Vault exists; Founder Principle #7. |
| [`PRODUCT_MANIFESTO.md`](PRODUCT_MANIFESTO.md) | **Retired.** Content merged into `PRODUCT_PRINCIPLES.md`. Redirect stub only. |

### Retired philosophy documents (redirect stubs)

### Quality Audits (Sprint 6.x historical snapshots)

| Document | Responsibility |
|---|---|
| [`V1_READINESS_REPORT.md`](V1_READINESS_REPORT.md) | Sprint 6.6 release-readiness audit. Pre-freeze references. |
| [`FTUE_AUDIT.md`](FTUE_AUDIT.md) | Sprint 6.5 first-time user experience audit. |
| [`TRUST_AUDIT.md`](TRUST_AUDIT.md) | Sprint 6.3 trust and security audit. |
| [`PERFORMANCE_REPORT.md`](PERFORMANCE_REPORT.md) | Sprint 6.2 performance report. |
| [`ACCESSIBILITY_AUDIT.md`](ACCESSIBILITY_AUDIT.md) | Sprint 6.4 accessibility report. |

---

## Architecture Freeze — Consolidation Summary

### Authoritative document recommendation

**Product constitution:** [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — rules, non-negotiables, operational behaviour.

**Platform vision (non-technical):** [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) — why Evidence Vault exists (DI-1.5).

**Investigation Platform philosophy:** [`PRODUCT_PHILOSOPHY.md`](PRODUCT_PHILOSOPHY.md) through [`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md) and [`ROADMAP.md`](ROADMAP.md) — DI-1.1 through DI-3.0 documentation increments.

`PRODUCT_MANIFESTO.md` was merged into `PRODUCT_PRINCIPLES.md` at Architecture Freeze and remains a redirect stub. `EVIDENCE_VAULT_MANIFESTO.md` was similarly retired in July 2026 and **revived as an active vision document** in DI-1.5 with a distinct non-technical purpose.

### Documents updated (Architecture Freeze)

| Document | Change |
|---|---|
| [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) | v3.0 — added Mission, Product Identity, Product Category, Core Beliefs; expanded Vision; single source for all philosophy |
| [`PRODUCT_MANIFESTO.md`](PRODUCT_MANIFESTO.md) | Retired → redirect stub with section mapping |
| [`EVIDENCE_VAULT_MANIFESTO.md`](EVIDENCE_VAULT_MANIFESTO.md) | Retired → redirect stub with document history |
| [`DOCS_INDEX.md`](DOCS_INDEX.md) | v2.0 — Architecture Freeze map; updated authoritative homes |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Removed Product Manifesto from document hierarchy |
| [`docs/BUILD_HEALTH.md`](docs/BUILD_HEALTH.md) | References Product Principles only for philosophy |
| [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) | Deprecated *Evidence Management/Collection Platform* terms |
| [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | v2.1 — Sprint 8.5 Enrichment Engine domain model; four platform engines |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Clarified relationship to root design system |

### Documents merged

| Source | Into | Content preserved |
|---|---|---|
| `PRODUCT_MANIFESTO.md` | `PRODUCT_PRINCIPLES.md` | We Believe, Mission, Vision, Promise, Product Identity, North Star |
| `EVIDENCE_VAULT_MANIFESTO.md` | `PRODUCT_PRINCIPLES.md` | Why We Exist, Reflection belief, Measure of Success, technology-as-companion belief |

### Documents retired

| Document | Treatment |
|---|---|
| `PRODUCT_MANIFESTO.md` | Redirect stub — do not extend |
| `EVIDENCE_VAULT_MANIFESTO.md` | Revived DI-1.5 — active platform manifesto (distinct from Architecture Freeze stub) |

### Terminology verification

| Term | Status |
|---|---|
| Incident Reconstruction Platform | ✅ Canonical category across all active specs |
| Evidence Management Platform | ✅ Deprecated in Language System |
| Evidence Collection Platform | ✅ Deprecated in Language System |
| Library of Truth (experience) | ✅ Consistent in Principles, Platform Architecture, Language System |
| Enrichment Engine (platform core) | ✅ Canonical in Platform Architecture v2.1 |
| Relationship Engine (platform core) | ✅ Consistent in Principles §6, Platform Architecture §2, UX Architecture |
| Story Engine / Trust Engine | ✅ Canonical in Platform Architecture v2.1; ⚠️ Principles uses View Story / Trust Package naming |
| Enrichment vs Context terminology | ⚠️ Platform Architecture v2.1 updated; Language System and Principles need review |

### Cross-document consistency (verified)

| Document | Aligns with Product Principles |
|---|---|
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | ✅ Interaction Philosophy references §3, §4, §7, §8, §9 |
| [`docs/UX_ARCHITECTURE.md`](docs/UX_ARCHITECTURE.md) | ✅ References Product Principles and Platform Architecture |
| [`docs/PLATFORM_ARCHITECTURE.md`](docs/PLATFORM_ARCHITECTURE.md) | ✅ Incident Reconstruction Platform; Relationship Engine as core |
| [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md) | ✅ References Product Principles for definitions |
| [`docs/PRODUCT_DECISION_FRAMEWORK.md`](docs/PRODUCT_DECISION_FRAMEWORK.md) | ✅ North Star points to Product Principles |

---

## Sprint 8 Refactor — Prior Documentation Changes

| Action | Documents |
|---|---|
| **Created** | `DOCS_INDEX.md` |
| **Replaced** | `docs/DOMAIN_MODEL.md` → `docs/PLATFORM_ARCHITECTURE.md` |
| **Major v2.0 updates** | `PRODUCT_PRINCIPLES.md`, `docs/UX_ARCHITECTURE.md`, `DESIGN_SYSTEM.md`, `docs/LANGUAGE_SYSTEM.md` |
| **Reference fixes** | `docs/PRODUCT_DECISION_FRAMEWORK.md`, `docs/BUILD_HEALTH.md` |

---

## Quick Reference — Standard Product Language

| Term | Meaning |
|---|---|
| **Evidence Vault** | The product |
| **Library of Truth** | The user experience — long-term incident collection |
| **Incident Reconstruction Platform** | The category — not storage, management, or collection |
| **Enrichment Engine** | Platform core that measures reconstruction quality and drives Incident Status |
| **Relationship Engine** | Platform core that connects evidence (user action: Link Evidence) |
| **Story Engine** | Platform core that builds incident narrative (user-facing: View Story) |
| **Trust Engine** | Platform core that evaluates integrity and assembles Trust Package |
| **Primary Evidence** | Core incident records: Photo, Video, File, Witness |
| **Enrichment** | Supporting information attached to primary evidence; Context is one type |
| **Trust Status** | Incident-level Verification + Integrity in View Story |
| **Trust Package** | Shareable trusted incident report |

Full vocabulary: [`docs/LANGUAGE_SYSTEM.md`](docs/LANGUAGE_SYSTEM.md)

---

*Consult this index before adding documentation. Platform vision belongs in `EVIDENCE_VAULT_MANIFESTO.md`. Platform engine architecture belongs in `PLATFORM_ARCHITECTURE.md`. Backend architecture belongs in `BACKEND_ARCHITECTURE.md`. Engineering guardrails belong in `AI_ENGINEERING_GUIDE.md`. Operational constitution belongs in `PRODUCT_PRINCIPLES.md`.*
