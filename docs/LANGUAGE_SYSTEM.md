**Version:** 2.0  
**Status:** Active Language Reference  
**Last Updated:** July 31, 2026 (Sprint 8)

# Language System

The Language System defines the vocabulary, grammar, writing principles, naming conventions, and semantic philosophy used throughout Evidence Vault.

It is the single source of truth for every word the product presents to users. This document aligns with the Product Constitution ([`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md)), the UX Architecture ([`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md)), the Platform Architecture ([`PLATFORM_ARCHITECTURE.md`](PLATFORM_ARCHITECTURE.md)), the Design System ([`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md)), and the Product Decision Framework ([`PRODUCT_DECISION_FRAMEWORK.md`](PRODUCT_DECISION_FRAMEWORK.md)).

Product philosophy and structural rules live in those documents. This document governs **how terms appear in copy** — labels, notifications, empty states, and reports.

Language is part of the product architecture.

---

## Purpose

Evidence Vault is not a gallery, notes application, or cloud storage product.

It is an **Incident Reconstruction Platform** — software that helps people preserve, enrich, connect, and understand moments that matter, and share trusted incident reports when ready.

Every word inside the product should reinforce reconstruction—not filing, sorting, or hoarding media.

See [`PRODUCT_PRINCIPLES.md` §1 — Product Vision](../PRODUCT_PRINCIPLES.md) for the full product definition.

---

## Core Language Philosophy

Truth is preserved.

Evidence is captured.

Context is enriched.

Integrity is protected.

Meaning emerges over time.

The Library grows.

The product should always communicate that evidence becomes more valuable as additional context is preserved around it.

---

## Product Voice

The voice of Evidence Vault should feel:

- Calm
- Trustworthy
- Objective
- Human
- Respectful
- Confident

Never dramatic.

Never sensational.

Never marketing driven.

Never manipulative.

The compassionate voice is defined fully in [Compassionate System Voice](#compassionate-system-voice).

---

## Compassionate System Voice

Evidence Vault never speaks like software.

It never sounds robotic.

It never celebrates incidents.

It never judges users.

It quietly accompanies people through experiences that may be emotional, stressful, joyful, unexpected, or life-changing.

Its language should always:

- Acknowledge
- Reassure
- Guide
- Respect

Every sentence should help users feel that they are not preserving evidence alone.

The product should feel like a calm and trustworthy companion.

### Voice Writing Principles

Evidence Vault should:

- Speak with quiet confidence.
- Prefer encouragement over instruction.
- Prefer guidance over warnings.
- Prefer clarity over cleverness.
- Prefer empathy over excitement.

Avoid dramatic language, gamification, congratulatory language, pressure, and urgency unless genuinely necessary.

These principles extend the general [Writing Principles](#writing-principles) and [Product Voice](#product-voice) above—they do not replace them.

### Language to Avoid

Never use language such as:

- Congratulations!
- Awesome!
- Great job!
- Level Up
- Achievement
- Completed
- Mission Accomplished
- 100%
- Finished

### Language to Prefer

Instead prefer language such as:

- Preserved
- Enriched
- Building
- Rich
- Supported
- Journey
- Context
- Library
- Truth

---

## Writing Principles

Use:

- Short sentences.
- Plain English.
- Active voice.
- Clear verbs.
- Minimal words.

Avoid:

- Technical jargon.
- Marketing language.
- Legal terminology unless required.
- Long explanations.
- Complex grammar.

---

## Linguistic Principles

Prefer verbs that describe action and maturity rather than nouns describing state.

Examples:

| Preferred | Avoid |
|---|---|
| Context Enriched | Context |
| Integrity Verified | Verification (when describing a single artifact) |
| Last Preserved | Last Modified |
| Capture Evidence | Create File |
| Link Evidence | Create Relationship |
| Prepare Trust Package | Generate Report |
| Trust Status | Verification Card |

Evidence Vault should describe what is happening rather than simply naming objects.

---

## Standard Vocabulary

These terms are **canonical product language**. Use them consistently in all user-facing copy. Full product definitions live in [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md)—this section defines **labels, usage, and alternatives to avoid**.

### Evidence Vault

The product name. Always capitalize both words.

Use for: app title, onboarding, settings, documentation, and system messages that refer to the product itself.

Avoid: *EvidenceVault* (unless required by a platform identifier), *the vault* as a generic noun, *EV* in user-facing copy.

### Incident Reconstruction Platform

The product category — what Evidence Vault **is**, not a screen label.

Use for: marketing context, onboarding explanation, App Store descriptions, and documentation that positions the product.

Avoid: *storage app*, *evidence manager*, *evidence management platform*, *evidence collection platform*, *file vault*, *cloud backup*, *incident dashboard*.

Do not use as a navigation label or button.

### Library of Truth

The user's long-term collection of incidents.

Use for: the Library screen title, empty states, and copy about browsing, searching, or resuming incidents across time.

Avoid: *My Files*, *Archive*, *Folder*, *Storage*, *Gallery*.

See [`PRODUCT_PRINCIPLES.md` §2](../PRODUCT_PRINCIPLES.md).

### Incident Status

The living canvas inside the workspace that answers: *"What have I captured so far?"* (formerly labeled Incident Journey in UI).

Use for: the Incident Status section header, enrichment maturity badges, and copy about visual maturity of preserved evidence.

The primary workflow navigation stages — **Capture → Organize → Investigation → Trust Package** — together represent the Incident Status lifecycle.

Avoid: *Progress*, *Completion*, *Task list*, *Evidence count*, *Dashboard*, *Incident Journey* (deprecated UI label).

See [`PRODUCT_PRINCIPLES.md` §4 and §5](../PRODUCT_PRINCIPLES.md).

### Relationship Engine

The system that connects evidence through **Link Evidence**. Relationship types are internal — users never classify them.

Use for: developer documentation, AI prompts, and internal product copy when explaining how Connections, Evidence Map, and Trust Package sections are powered.

User-facing action label: **Link Evidence** — not *Create Relationship*, *Add Connection*, or *Classify Link*.

Avoid exposing relationship type names (Supports, Contradicts, etc.) as required user choices.

See [`PRODUCT_PRINCIPLES.md` §6](../PRODUCT_PRINCIPLES.md).

### Trust Status

The incident-level trust summary in **View Story** and **Trust Package**. Combines **Verification** and **Integrity** for the whole record.

Use for: Story section header, Trust Package trust summary, and copy about whether a record is defensible.

Avoid: multiple scattered *Verification* cards in the Workspace, per-file trust dashboards, *Trust Score*, *Confidence Rating*.

See [`PRODUCT_PRINCIPLES.md` §8](../PRODUCT_PRINCIPLES.md).

### Verification

One dimension of **Trust Status** — whether documentation is complete and attributable at the incident level.

Use for: Trust Status rows, Trust Package sections, and explanatory copy about completeness.

Distinguish from **Integrity Verified** (item-level authenticity confirmation on a single Evidence Record).

Avoid: *Verified ✓* badges scattered across the Workspace, *100% complete*, gamified completeness meters.

### Integrity

One dimension of **Trust Status** — whether preserved evidence remains authentic and unaltered.

Use for: Trust Status rows, Evidence Record integrity metadata, and Trust Package integrity sections.

Item-level confirmation label: **Integrity Verified** — not *Integrity Passed* or *Checksum OK*.

Avoid: alarmist language, red warnings for normal states, technical hash terminology in primary UI.

### Trust Package

The shareable, trusted incident report assembled from preserved evidence.

Use for: navigation (*Prepare Trust Package*), screen titles, export copy, and sharing flows.

Avoid: *Professional Report*, *PDF Export*, *Document*, *Report Generator*, *Summary Export*.

Users may prepare a Trust Package at any journey stage.

See [`PRODUCT_PRINCIPLES.md` §3 and §8](../PRODUCT_PRINCIPLES.md).

---

## Deprecated Terminology

Replace outdated labels with standard vocabulary:

| Deprecated | Use instead |
|---|---|
| Evidence Management Platform | Incident Reconstruction Platform |
| Evidence Collection Platform | Incident Reconstruction Platform |
| Professional Report | Trust Package |
| Generate Report | Prepare Trust Package |
| Report | Trust Package (when referring to the product output) |
| Create Relationship | Link Evidence |
| Relationship type (user-facing) | *(internal only — user action is Link Evidence)* |
| Verification card / Integrity card (Workspace) | Trust Status (in View Story) |
| Progress / Completion / Done (Journey) | Journey Stage / Building / Rich |
| REFLECTIVE (Journey stage) | *(removed — three stages only: EMPTY, BUILDING, RICH)* |
| Storage / Upload / Save (evidence) | Preserve / Capture |
| Dashboard (Workspace) | Evidence Workspace / Capture and build |
| Create Incident | *(first capture creates the incident automatically)* |

---

## Product Vocabulary

Use consistently across UI, notifications, and documentation:

**Product & collection**

- Evidence Vault
- Incident Reconstruction Platform *(category — not a screen label)*
- Library of Truth

**Capture & build**

- Capture
- Preserve
- Evidence
- Evidence Workspace
- Incident Journey
- Journey Stage
- Current Stage

**Enrichment & connection**

- Context
- Context Enriched
- Add Context
- Link Evidence
- Relationship Engine *(internal / explanatory copy)*

**Understanding & trust**

- View Story
- Timeline
- Connections
- Summary
- Trust Status
- Verification
- Integrity
- Integrity Verified

**Sharing**

- Trust Package
- Prepare Trust Package

**Artifacts**

- Evidence Record
- Voice Note
- Attachment
- Evidence Map

**Concepts**

- Incident
- Truth
- Meaning

Avoid replacing these words with generic alternatives.

### Incident Journey Language

The Incident Journey visualizes maturity—not completion.

**Use:**

- Incident Journey
- Journey Stage
- Current Stage
- EMPTY / BUILDING / RICH

**Never use:**

- Progress
- Completion
- Percent Complete
- Task Progress
- Finished
- Done
- REFLECTIVE *(retired stage)*

See also [Compassionate System Voice](#compassionate-system-voice) and [`PRODUCT_PRINCIPLES.md` §5](../PRODUCT_PRINCIPLES.md).

### View Story Language

**View Story** is the intelligence centre — where users understand *what happened*.

**Use:**

- View Story *(action and screen entry)*
- Timeline, Connections, Summary, Trust Status *(section names within Story)*

**Never use:**

- Dashboard
- Analytics
- Insights Hub

Chronology as narrative belongs in View Story—not in the Workspace Incident Journey.

See [`PRODUCT_PRINCIPLES.md` §7](../PRODUCT_PRINCIPLES.md).

---

## Canonical Product Copy

The following copy is **permanent product language** unless intentionally revised through product design.

Future UX, engineering, and AI features must reference these messages—not create variations, paraphrases, or alternatives without an explicit language review.

### Product Language Principle

Evidence is preserved.

Context is enriched.

Stories become richer.

Truth is reconstructed with confidence.

### Incident Journey Stages

Three permanent maturity states. Do not rewrite or paraphrase these stage messages.

#### EMPTY

Every library begins with one piece of truth.

#### BUILDING

Your truth is taking shape.

#### RICH

Your Library of Truth is ready.

---

## Evidence Language

Evidence is never:

- Edited
- Modified
- Rewritten
- Corrected
- Replaced

Evidence may be:

- Captured
- Preserved
- Viewed
- Protected
- Linked
- Referenced

Evidence remains immutable.

Item-level integrity confirmation uses **Integrity Verified** — not *Verified* alone, which belongs to **Trust Status → Verification** at the incident level.

---

## Context Language

Context may be:

- Added
- Enriched
- Expanded
- Connected
- Linked
- Explained
- Related

Context exists to increase understanding without changing evidence.

The canonical enrichment action is **Add Context**.

---

## Library Language

The Library of Truth:

- Begins
- Grows
- Expands
- Remembers
- Protects
- Preserves

Avoid:

- Stores
- Keeps
- Saves
- Archives

Except where archival workflows genuinely exist (e.g., incident lifecycle **Archived** status).

---

## Interface Grammar

Prefer:

- Capture Now
- Capture Evidence
- Last Preserved
- Context Enriched
- Integrity Verified
- Evidence Preserved
- Link Evidence
- View Story
- Prepare Trust Package
- Trust Status
- Library of Truth
- Evidence Map

Avoid:

- Create
- Edit
- Modify
- Update
- Save
- Upload
- Generate Report
- Professional Report

unless technically unavoidable.

---

## Empty States

Every empty state should educate.

Never show:

- No Data
- Nothing Here
- Empty

Instead explain:

- What this area becomes.
- Why it exists.
- What the user should naturally do next.

For the Incident Journey **EMPTY** stage and Library introductions, use the [Canonical Product Copy](#canonical-product-copy).

Example (Library of Truth):

**The Library of Truth**

Every library begins with one piece of truth.

Enrich it as your story unfolds.

---

## Notifications

Examples:

- Evidence Preserved.
- Context Enriched.
- Link Added.
- Integrity Verified.

Avoid:

- Upload Complete.
- File Saved.
- Changes Updated.
- Relationship Created *(prefer Link Added)*.
- Reflection Added *(prefer Reflection preserved.)*

---

## AI Language

AI never speaks with certainty.

Use:

- AI suggests...
- AI identified possible relationships...
- AI detected similar evidence...

Avoid:

- AI concluded...
- AI proved...
- AI confirmed...

The human always remains the final decision maker.

Relationship types inferred by AI remain internal — present suggestions, not classifications the user must adopt.

See [`PRODUCT_PRINCIPLES.md` §10](../PRODUCT_PRINCIPLES.md).

---

## Trust Package Language

Trust Packages are the shareable output of incident reconstruction.

Sections should always separate:

- Evidence
- Context
- Connections *(from the Relationship Engine)*
- AI Observations
- Trust Status *(Verification and Integrity)*
- User Statements

These sections must never be merged.

Trust Packages remain factual, chronological, and objective. They **represent** evidence—they never modify it.

Avoid *report* when *Trust Package* is the intended product term.

---

## Language Evolution Policy

Every new feature must first define its vocabulary before implementation.

Before introducing a new label ask:

- Does it reinforce preservation and reconstruction?
- Does it build trust?
- Does it align with [Standard Vocabulary](#standard-vocabulary)?
- Does it remain consistent with this Language System?
- Does it honor the [Compassionate System Voice](#compassionate-system-voice)?

If not, reconsider the wording.

See also [Language Consistency](#language-consistency).

---

## Evidence Vault Dictionary

Concise lexical definitions for copywriters and engineers. For product philosophy and structural rules, see [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md).

### Standard terms

| Term | Lexical definition |
|---|---|
| **Evidence Vault** | The product — an Incident Reconstruction Platform for preserving and understanding truth |
| **Incident Reconstruction Platform** | Product category: preserve, enrich, connect, understand, and report incidents — not file storage |
| **Library of Truth** | The user's long-term collection of incidents and their preserved records |
| **Incident Journey** | Workspace visualization of what has been captured; reflects maturity, not task completion |
| **Relationship Engine** | System powering evidence connections; user action is Link Evidence; types are internal |
| **Trust Status** | Incident-level summary combining Verification and Integrity |
| **Verification** | Trust Status dimension: documentation completeness and attributability |
| **Integrity** | Trust Status dimension: evidence authenticity and unaltered preservation |
| **Trust Package** | Shareable trusted incident report assembled from preserved evidence |

### Supporting terms

**Evidence** — An immutable record captured by the user.

**Evidence Record** — The permanent home of one preserved artifact; read and enrich, never edit.

**Evidence Workspace** — The capture-and-build surface; not a dashboard.

**Context** — Information that increases understanding without changing evidence.

**Context Enriched** — Additional notes, voice, files, links, or evidence have increased meaning around existing evidence.

**Integrity Verified** — A single artifact's integrity has been successfully validated.

**Evidence Map** — Visual overview of how evidence relates; entry point to Evidence Records and powered by the Relationship Engine.

**Relationship** — A meaningful connection between two or more pieces of evidence, created through Link Evidence.

**Incident** — A collection of related evidence representing a real-world event or ongoing situation.

**View Story** — The intelligence centre where Timeline, Connections, Summary, and Trust Status help users understand what happened.

**Journey Stage** — One of three maturity states: EMPTY, BUILDING, or RICH. Messages in [Canonical Product Copy](#canonical-product-copy).

**Preserve** — To securely capture and protect evidence without altering its original content.

**Capture** — The act of creating new evidence through photo, video, audio, notes, or attachments.

**Meaning** — Understanding that emerges as evidence becomes enriched and connected.

**Truth** — The objective representation of events supported by preserved evidence.

---

## Language Consistency

Whenever future features introduce copy for any of the following, developers and designers must consult this document **before** introducing new user-facing language:

- Notifications
- AI assistance
- Evidence Map
- Incident Journey
- View Story and Trust Status
- Trust Package
- Library of Truth
- Link Evidence
- Sharing
- Onboarding
- Empty states
- System messages

The Language System is part of the Evidence Vault architecture—not a stylistic preference.

New copy must align with [Standard Vocabulary](#standard-vocabulary), [Compassionate System Voice](#compassionate-system-voice), [Canonical Product Copy](#canonical-product-copy), and the [Evidence Vault Dictionary](#evidence-vault-dictionary).

---

## Future Language Governance

This document governs:

- UI copy
- Button labels
- Navigation
- Notifications
- Trust Packages
- Evidence exports
- AI prompts
- AI responses
- Documentation
- Developer naming
- API terminology

Future features must follow this language system.

---

## Golden Rule

Evidence Vault should never sound like a gallery, cloud drive, notes application, task manager, or analytics dashboard.

Its language should always reinforce the philosophy:

**Evidence is preserved.**

**Context is enriched.**

**Stories become richer.**

**Truth is reconstructed with confidence.**

---

*This document is the canonical language architecture of Evidence Vault. Consult it before introducing any new user-facing terminology.*
