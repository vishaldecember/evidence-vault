# UX Architecture

**Last Updated:** August 10, 2026 (Sprint 6C — Workspace / Capture Cockpit canonical flows)

This document defines the complete user experience architecture for Evidence Vault. It is the canonical UX specification that every future screen, interaction, animation, and workflow must follow.

The UX Architecture aligns with the Product Constitution (`PRODUCT_PRINCIPLES.md`), the Platform Architecture (`PLATFORM_ARCHITECTURE.md`), and the Capture Cockpit source of truth ([`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md)). Where product principles define *why* and *what*, this document defines *how users experience* incident reconstruction — including **navigation architecture** for Home, Incident Workspace, and Capture Cockpit.

Evidence Vault is designed around two primary principles:

**Efficiency** — Capture evidence with the fewest possible decisions. Capture Now opens Cockpit immediately on a new incident; Continue Preserving returns to the real Workspace without detours.

**Effectiveness** — Connect and organise evidence automatically so the user can focus on documenting reality. Workspace and Cockpit share one `incidentId`; evidence accumulates on one timeline.

**The user should never think about software while documenting an incident.**

**Source-of-truth rule:** Before changing Home capture routing, Workspace navigation, Cockpit navigation, CaptureSession lifecycle, incident creation, incident recovery, evidence persistence, or modality switching, consult this document and [`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md). If code conflicts with these documents, identify the conflict explicitly — do not silently redefine the architecture to match legacy code.

---

## 1. UX Philosophy

The UX philosophy translates product principles into experience design. Every screen and interaction must reflect these foundations.

### Capture-First Workflow

Users capture first. Naming, categorizing, tagging, and structuring happen after evidence exists—not before. The interface must never block capture with forms, mandatory fields, or organizational decisions. Organization is a service the platform provides; it is not a prerequisite for the user.

The primary journey begins at **Home** with capture—not with incident setup, categorization, or administrative screens.

### Progressive Documentation

Incidents evolve over minutes, hours, days, or weeks. Users may pause, resume, enrich, and supplement without starting over. The experience supports incomplete records that mature over time. Early capture is always valid; later enrichment adds meaning without rewriting history.

### One Incident = One Truth Record

The experience presents one incident as one coherent truth record. Users never manage multiple overlapping containers for the same event. The interface does not suggest merging incidents or linking them without explicit, deliberate user action.

### Zero Friction

Every tap, screen, and decision is evaluated for necessity. The path from opening the application to capturing evidence must be the shortest credible path. Friction that does not serve preservation, verification, or trust is removed.

### Trust Before Automation

Automation serves the user; it never obscures what happened. Automatic incident creation, verification, and organization must be visible and explainable. Users should feel that the platform protects their record—not that it acts invisibly on their behalf in ways they cannot understand.

---

## 2. Navigation Philosophy

The application is centered around **Incidents**.

Not files.  
Not folders.  
Not projects.

Everything begins with evidence capture — but capture has two distinct product states:

| State | Surface | Role |
|---|---|---|
| **Incident State** | **Incident Workspace** | Persistent environment for a real/current incident — identity, timeline, sticky capture, organize / investigation / trust |
| **Active Capture State** | **Capture Cockpit** | Immersive Photo / Video / Voice capture **on** an existing `incidentId` |

The Workspace is **never** an empty capture staging screen. Cockpit does **not** own incident creation.

Navigation should minimize cognitive load. Users orient by *what they are documenting*, not by *where files are stored*. The primary navigation surfaces are:

| Surface | Role |
|---|---|
| **Home** | Capture Now (new incident → Cockpit) and Continue Preserving (existing Workspace) |
| **Vault** | Library of Truth — long-term access to preserved incidents |
| **Profile** | Account, security, preferences, and support |

Deep navigation into an incident occurs through the **Incident Workspace**—the persistent environment where a truth record is built. **Capture Cockpit** is a temporary focused layer entered from Home Capture Now (Photo/Video/Voice) or from the Workspace sticky bar.

Understanding and sharing occur through **View Story** and **Trust Package** respectively—not within a Workspace dashboard.

### Canonical capture navigation (authoritative)

These three flows are the only primary journeys for capture entry. Competing direct-camera paths must not redefine them.

#### Flow 1 — Capture Now

```
Home
  ↓
Capture Now
  ↓
Create / establish NEW incident
  ↓
Open Capture Cockpit (selected Photo / Video / Voice)
  ↓
Capture evidence
  ↓
DONE / EXIT
  ↓
SAME Incident Workspace (same incidentId; evidence already present)
```

The user must **not** first land in an empty Workspace. Note / File from Capture Now open Workspace only (Workspace capture actions — not Cockpit).

#### Flow 2 — Continue Preserving

```
Home
  ↓
Continue Preserving
  ↓
EXISTING Incident Workspace
```

Do **not** automatically open Capture Cockpit. The Workspace already contains the incident’s existing evidence.

#### Flow 3 — Workspace sticky capture

```
Incident Workspace
  ↓
Sticky Capture Bar → Photo / Video / Voice
  ↓
Capture Cockpit (same incidentId)
  ↓
Capture additional evidence
  ↓
DONE / EXIT
  ↓
SAME Incident Workspace
```

Note → Workspace note capture. File → Workspace file capture. Neither enters Cockpit.

---

## 3. Primary User Journey

The complete Evidence Vault experience follows a single primary journey. Each stage has a defined purpose. Capture Now inserts Cockpit between Home and Workspace for Photo / Video / Voice; the Workspace remains the persistent incident home.

```
Home
  ↓
Capture Now → New Incident → Capture Cockpit
  (or Continue Preserving → Existing Workspace)
  ↓
Incident Workspace
  ↓
View Story
  ↓
Trust Package
```

Authentication precedes this journey. Pause, resume, finalize, and archival are operational states—not steps in the primary flow.

### Home

The user's entry point for immediate action. Primary affordance: **Capture Now**. Secondary: **Continue Preserving** for an existing incident. No incident administration or analytics appear here.

### Capture Now / Capture Cockpit

**Capture Now** means: *I am starting a NEW incident and want to capture immediately.*

For Photo / Video / Voice: the platform establishes a new `incidentId` and CaptureSession, then opens **Capture Cockpit**. Evidence captured in Cockpit belongs to that `incidentId`. DONE / EXIT opens the **same** Incident Workspace — never an empty staging screen first.

For Note / File: Capture Now establishes the new incident and opens Workspace only (Workspace capture actions).

### Continue Preserving

**Continue Preserving** means: *I am returning to an existing incident.* Home opens that Incident Workspace only — no automatic Cockpit.

### Incident Workspace

The persistent working surface for a real/current incident — timeline, sticky capture, progressive naming, and entries to Story / Trust Package. Sticky Photo / Video / Voice re-enter Cockpit for the **same** `incidentId`. Chronology as narrative and Trust Status belong in View Story—not as Workspace dashboards.

### View Story

The intelligence centre. The user intentionally enters Story to understand *what happened*—through Timeline, Connections, Summary, and Trust Status. Story is read-oriented; active Photo / Video / Voice capture remains in Cockpit; Workspace remains the incident home.

### Trust Package

The shareable output. The user assembles or reviews a trusted incident report for formal use. Trust Packages represent evidence; they never modify it. Available at any journey stage.

---

## 4. Home

### Purpose

**Immediate evidence capture.**

Home exists to answer one question: *What do you need to preserve right now?* It is not an analytics dashboard, file browser, or incident administration screen.

### Layout

#### Top

| Element | Content |
|---|---|
| **Logo** | Evidence Vault brand mark |
| **Headline** | Preserve your truth now. |
| **Subheadline** | Protect what matters later. |

The headline pair communicates urgency of capture and long-term value of preservation. Tone is calm and confident—not alarmist.

#### Middle — Capture Now (Quick Capture)

Five capture actions, presented as premium, thumb-friendly controls:

| Action | Purpose | Destination |
|---|---|---|
| **Photo** | Capture still image evidence | New incident → **Capture Cockpit** (Photo) → Same Workspace |
| **Video** | Capture motion evidence | New incident → **Capture Cockpit** (Video) → Same Workspace |
| **Voice** | Capture audio recording | New incident → **Capture Cockpit** (Voice) → Same Workspace |
| **Note** | Capture text evidence | New incident → **Incident Workspace** (Note on Workspace) |
| **Attachment** / File | Import file evidence | New incident → **Incident Workspace** (File on Workspace) |

**No "Create Incident" button.**  
**No forms.**  
**No mandatory categorization.**  
**No empty Workspace before Cockpit** for Photo / Video / Voice.

Tapping Capture Now begins documenting immediately. Incident identity is established silently before Cockpit (or before Workspace for Note / File). The interface communicates through layout and copy that capture *is* the start—not a step toward starting.

#### Bottom Section — Continue Preserving

When a paused or in-progress incident exists, a card presents:

| Element | Purpose |
|---|---|
| **Paused / active Incident** | Title or identifier of the existing record |
| **Evidence Count** | Number of evidence items already captured |
| **Continue Preserving / Resume** | Single action to open the **existing Incident Workspace** (no auto-Cockpit) |

When no such incident exists, this section may be absent or show a calm empty state—never a call to manually create an incident.

#### Bottom Navigation

| Tab | Destination |
|---|---|
| **Home** | Home |
| **Vault** | Library of Truth |
| **Profile** | Profile and account settings |

### Why This Minimizes Friction

- **One tap to Capture Now** — Photo / Video / Voice enter Cockpit on a new incident without empty Workspace staging
- **Continue Preserving is Workspace-only** — return to real evidence without forced Cockpit
- **No empty incident containers as a user-facing step** — structure is established from Capture Now / first capture action
- **Resume is visible but not mandatory** — paused work is accessible without dominating the screen
- **Three-tab navigation** — simple mental model: act, preserve, account
- **No scrolling required on standard mobile viewports** — capture actions remain immediately visible

---

## 5. Automatic Incident Creation

### Experience

The user never creates an incident through a dedicated “New Incident” form or confirmation dialog.

**Capture Now** establishes a new `incidentId` (and CaptureSession) **before** Capture Cockpit opens for Photo / Video / Voice — silently, without a creation screen. Note / File Capture Now establish the incident then open Workspace.

When the first evidence is preserved, the platform also ensures:

| Created Object | User Visibility |
|---|---|
| **Incident ID** | Assigned silently; same id across Cockpit, Workspace, Vault, and recovery |
| **CaptureSession** | Internal grouping / recovery concept — never exposed as a user workflow |
| **Evidence Chain / timeline** | Initialized as evidence accumulates |
| **Verification Record** | Captured automatically at moment of recording |
| **Capture Timestamp** | Recorded and displayed in evidence context |

The user’s first conscious awareness of an “incident” after Capture Now Photo / Video / Voice is typically **Capture Cockpit** already open on that incident — then the **Incident Workspace** with captured evidence present. They must never be shown an empty Workspace staging screen first.

### Why This Supports Stress-Free Documentation

- **Removes a decision point** at the moment stress is highest
- **Prevents empty Workspace staging** that users must populate before capturing
- **Aligns software behavior with reality** — documentation begins when something is worth preserving
- **Preserves one incidentId** from Capture Now through Cockpit through Workspace
- **Reduces fear of "doing it wrong"** — there is no incorrect way to start because starting *is* capturing

---

## 6. Capture Modes and Capture Cockpit

### Capture Cockpit (Photo / Video / Voice)

Photo, Video, and Voice share **Capture Cockpit** — the immersive Active Capture State. Full contract: [`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md).

| Mode | Behavior |
|---|---|
| **Photo** | Cockpit opens in Photo; live camera surface; capture into current `incidentId`. DONE / EXIT → same Incident Workspace. |
| **Video** | Cockpit opens in Video; record / preview within Cockpit. DONE / EXIT → same Incident Workspace. |
| **Voice** | Cockpit opens in Voice; record within Cockpit. DONE / EXIT → same Incident Workspace. |

Cockpit characteristics (locked): immersive capture; translucent modality controls; tilted preview currently **-5°**; orange four-sided preview border; Photo/Video/Voice switching; evidence belongs to the `incidentId` with which Cockpit was opened.

Cockpit does **not** create incidents, replace incidents, own naming / organization / investigation / Trust Package, contain Note or File, or become the persistent Workspace.

### Workspace-only capture (Note / File)

| Mode | Behavior |
|---|---|
| **Text Note** | Workspace note sheet; saves into current incident timeline. Does **not** enter Cockpit. |
| **Attachment** / File | Workspace file picker; imports into current incident timeline. Does **not** enter Cockpit. |

### Rules

- **Only one Cockpit modality is primary at a time**, with intentional Photo / Video / Voice switching inside Cockpit.
- **Incident Workspace is the hub; Cockpit is the focused capture layer** for Photo / Video / Voice — not a competing persistent home.
- **Completing Cockpit returns to the same Incident Workspace** (Capture Now: the newly established incident’s Workspace).
- **Primary Capture Now and Workspace Photo / Video / Voice journeys must not bypass Cockpit** through competing direct-camera navigation.
- Capture modes must handle permissions gracefully. Denial is explained calmly with a path to settings—not with technical jargon or blame.

---

## 7. Incident Workspace (Evidence Workspace)

The **Incident Workspace** is **Incident State** — the persistent environment for a real/current incident. Purpose: **capture and build** that incident.

It is **never** an empty capture staging screen.

### Purpose

To show what has been preserved for this `incidentId`, append new evidence (via Cockpit or Workspace Note/File), enrich in place, and enter Story / Trust Package — without analytics dashboards or trust summaries that belong in View Story.

### Essential Components

| Component | Role |
|---|---|
| **Sticky capture bar** | Photo / Video / Voice → Capture Cockpit; Note / File → Workspace capture |
| **Evidence timeline** | Authoritative chronological view; cumulative evidence count for the incident |
| **Name Incident** | Progressive naming — optional, never blocking capture |
| **View Story** | Entry to understanding (Timeline, Connections, Summary, Trust Status) |
| **Prepare Trust Package** | Entry to sharing a trusted report |

The Workspace does **not** host analytics cards, aggregate counters, evidence completeness checklists, or file-manager patterns.

### Layout

#### Information Layer

Scrollable content above the sticky capture layer:

- Workspace Header
- View Story and Prepare Trust Package actions
- **Incident Status** (living evidence timeline + maturity stages)
- Evidence Map (relationship overview — optional review surface)
- Reflection (when present)

Chronological narrative and **Trust Status** are presented in **View Story**, not as dashboard widgets in the Workspace.

#### Action Layer (Sticky)

Anchored at the bottom for thumb-first capture:

- **Name Incident** (above sticky bar when present)
- **Sticky capture bar** — Photo / Video / Voice → Cockpit; Note / File on Workspace

The Action Layer is the primary interaction surface during documentation. Returning from Cockpit must retain prior evidence and show newly captured items on the same timeline.

### Name Incident Interaction

Progressive naming companion attached to the top edge of the Sticky Capture Layer.

| Behaviour | Rule |
|---|---|
| **Trigger** | Appears only after evidence exists; auto-expands once on first successful capture |
| **Optional** | Never blocks capture; user may collapse and continue |
| **Placeholder** | *Name this incident... e.g. Workplace Harassment* — disappears on focus |
| **Persistence** | User-entered title preserved; drawer remains available for editing |

Naming is secondary to capture. The drawer must never feel like a required form or modal.

### Incident Status

**Incident Status** visualizes incident maturity and shows preserved evidence as a **living evidence timeline**—real previews in capture order, not numbered badges or aggregate counters. The workflow stages Capture → Organize → Investigation → Trust Package are the Incident Status lifecycle.

The Journey is **not** a progress bar, completion indicator, or gamification element.

##### Journey Stages

Three permanent stages:

| Stage | Meaning |
|---|---|
| **EMPTY** | Evidence has been captured |
| **BUILDING** | Evidence has context or linked evidence |
| **RICH** | Primary evidence enriched with sufficient context |

Users may prepare a Trust Package at any stage. The journey guides quality but never blocks progress.

The active stage is determined by domain rules—not by the UI. No percentages, scores, or rewards are displayed.

##### Living Evidence Timeline

- Evidence appears left-to-right in capture order; wraps to additional rows as needed
- Every captured item remains visible — nothing hidden behind "+N" or "N preserved"
- Tapping a preview opens that **Evidence Record** — not View Story
- Large libraries scroll within the evidence area; journey stages below remain accessible

### Relationship Engine (Workspace Interaction)

Users do **not** draw relationship lines. The system creates relationships;
users inspect reasons and refine Primary / Supporting designation in Investigation.

Relationship types are internal. The interface never asks users to classify
relationships manually.

Sprint 5C pipeline:

```
Capture → Evidence → Evidence Collections (Organize)
  → Primary Evidence → Supporting Evidence → Relationships
  → Investigation Graph → Memory Recall (Vault) → Risk Coach (Investigation)
```

- **EvidenceCollection** answers “what belongs together?” (CollectionEngine / Organize)
- **Relationship** answers “how are these connected?” (`RelationshipEngine`)
- **Supporting Evidence** answers “what strengthens this evidence?”
- **Memory Recall** answers “what have I forgotten that may matter?” (deterministic library signals; AI provider reserved)
- **Risk Coach** answers “what might need attention / what may be missing?” (deterministic investigation signals; AI provider reserved)

The Relationship Engine powers the Investigation **Graph** tab, Connections,
Timeline hierarchy, and Trust Package sections. Linking never modifies original evidence.

### Memory Recall (Vault)

Memory Recall is an **incident memory system**, not a journal or social feed.
Vault hierarchy: This Month → Memory Recall (0–3 cards) → Recent Incidents.
Every card has an explainable reason and references real incident data only.
MVP uses `DeterministicMemoryRecallProvider` (library maturity, age, unresolved,
unreviewed evidence). `RELATED_INCIDENT` / `RECURRING_CONTEXT` are reserved until
library summaries carry reliable cross-incident graph signals. AI recall and
“Whisper” are future seams on `MemoryRecallProvider` — not implemented.

### Risk Coach (Investigation)

Risk Coach is a **calm attention surface**, not legal/medical/financial advice
and not a task manager or chatbot.
It lives in the Investigation Workspace (alongside Investigation Coach).
MVP uses `DeterministicRiskAssessmentProvider` reading Investigation Graph,
Evidence Collections, maturity, and optional Memory Recall / library hints.
`AIRiskAssessmentProvider` is reserved. Dismiss/reviewed preferences are local only.

### Trust Status

**Trust Status** (Verification and Integrity) is communicated at the **incident level** in **View Story** and **Trust Package**—not as a dashboard card in the Workspace.

Individual evidence stores technical metadata in Evidence Records. The Workspace does not surface per-file trust dumps during capture.

### Thumb-First Workspace

The Evidence Workspace is designed around the principle of continuous evidence capture rather than continuous reading.

After every capture, users naturally perform one of two actions:

- Continue documenting the incident
- Review previously captured evidence

Because continuing capture is the highest-frequency interaction, capture actions should remain within the natural thumb-reachable area of the screen whenever practical.

The workspace separates content into two layers (Information Layer and Action Layer) as defined above.

#### Action Layer Contents

- Name Incident drawer (when evidence exists)
- Continue Capturing
- Photo · Video · Voice Note · Text Note · File Attachment

The Action Layer should remain visually anchored near the bottom of the screen to minimize thumb travel and encourage uninterrupted documentation.

### Progressive Intelligence

Evidence Vault is intentionally designed to reveal intelligence progressively rather than all at once.

The interface should remain almost invisible while users are documenting reality, becoming increasingly helpful only as users intentionally move from capture to understanding.

This behaviour is divided into three experience levels.

#### Level 1 — Capture

Primary objective:

Preserve reality with the least possible friction.

Characteristics:

- No interruptions
- No mandatory confirmations
- No AI suggestions
- No decision fatigue
- Fast transitions back to the workspace
- Primary focus is uninterrupted evidence capture

The Action Layer exists solely to help users continue preserving reality.

#### Level 2 — Enrichment

This level begins only after the user intentionally chooses to enrich an incident.

Examples include:

- Adding a text note
- Recording a voice note
- Attaching a document
- Relating evidence

At this stage, the application may provide lightweight contextual assistance.

Examples:

- Relate this note to the latest evidence?
- Relate to existing evidence?
- Create standalone evidence?

Suggestions should reduce effort but must never interrupt the user's workflow or assume relationships automatically.

#### Level 3 — Understanding

This level begins only when the user intentionally enters **View Story** or **Prepare Trust Package**:

- View Story (Timeline, Connections, Summary, Trust Status)
- Trust Package preview and assembly
- Evidence Map (relationship overview)
- Evidence Record (single-artifact review)

At this stage, the application may provide deeper assistance including:

- Pattern recognition
- Timeline understanding
- Relationship visualisation
- Trust Package generation
- Missing evidence suggestions
- AI-supported insights (clearly labeled)

AI exists to help users understand preserved truth.

It must never modify, reinterpret, or invent evidence.

#### UX Principle

The deeper users move into understanding an incident, the more intelligent the application becomes.

During capture, Evidence Vault is nearly invisible.

During enrichment, it becomes quietly helpful.

During review and reporting, it becomes intelligently supportive.

The application should never interrupt capture in order to demonstrate intelligence.

Instead, intelligence should appear only when users intentionally seek greater understanding.

### Role Over Time

The workspace is where incidents evolve over hours, days, or weeks. It is the same environment for first capture and hundredth enrichment. Consistency builds trust and reduces relearning.

---

## 8. Evidence Chain

The **Evidence Chain** is the immutable chronological record of evidence within an incident.

During **capture and build**, the Workspace shows preserved evidence through the **Incident Status living timeline**—not as a separate chronological dashboard.

The authoritative chronological presentation for understanding is **View Story → Timeline**, derived from the Evidence Chain.

### Properties

| Property | UX Implication |
|---|---|
| **Chronological** | Items appear in capture order, earliest to latest (with supplementary items clearly marked) |
| **Immutable** | No reorder controls, no delete-without-trace, no edit of capture timestamps |
| **Unique per Incident** | One chain per truth record; the chain is not shared across incidents |

Every evidence item appears in capture order. Supplementary evidence appears after original chronology and is visually distinguished so users understand it was added later—not that history changed.

### Why Chronology Is Preserved

Chronology is the narrative skeleton of a truth record. When accounts are questioned, the *sequence* of documentation often matters as much as individual items. Reordering or hiding items would undermine trust and defensibility.

The UX must never suggest that chronology is flexible. Drag-and-drop reorder, bulk hide, or silent removal are prohibited in the experience specification.

---

## 9. Reviewing an Incident

When users are actively documenting reality, the interface prioritizes **capture and build**.

When users intentionally seek understanding, they enter **View Story**—the intelligence centre powered by the Evidence Chain and Relationship Engine.

| View (within Story) | Purpose |
|---|---|
| **Timeline** | Chronological reconstruction; capture order; timestamps |
| **Connections** | How evidence relates — powered by the Relationship Engine |
| **Summary** | Narrative synthesis of the incident |
| **Trust Status** | Incident-level Verification and Integrity |

Users may also open the **Evidence Map** from the Workspace for a relationship overview, or an **Evidence Record** for single-artifact review.

The Timeline answers *when* something was captured. Connections answer *how* evidence relates. Neither replaces the other.

**Time tells us when something happened. Relationships tell us why it mattered. Evidence Vault preserves both.**

Tapping an artifact opens the **Evidence Record**—the permanent home of that preserved item. See [Section 10: Evidence Record](#10-evidence-record).

---

## 10. Evidence Record

### Definition

An **Evidence Record** is the permanent home of one preserved Evidence Artifact.

It is not a media viewer.

It is not an editor.

It is not a file details page.

It is the place where preserved evidence, integrity, context, and metadata come together to create understanding.

The Evidence Record is opened from the Evidence Map when a user intentionally reviews a single artifact. It uses smooth Material transitions and presents a scrollable, archival view—not a transactional editing surface.

### Architectural Model

Every Evidence Record answers four questions. These four questions are **permanent architectural pillars** of every Evidence Record. Future features should strengthen one of these pillars rather than introduce unrelated sections.

#### 1. What was preserved?

**Answered by: Evidence**

The preserved artifact itself—photo, video, voice recording, note, or document—displayed read-only at the top of the record. The evidence preview and Evidence Information section (type, preserved status, timestamp, source) answer this question. The artifact is never editable within the Evidence Record.

#### 2. Can I trust it?

**Answered by: Integrity**

A dedicated Integrity section confirms that the original evidence remains unchanged. Integrity Verified status, preservation confirmation, and future verification affordances (hash, chain of custody, verification history) belong here. Trust is visible—not assumed.

#### 3. What helps me understand it?

**Answered by: Context**

Contextual material added around the preserved evidence—notes, voice, photos, documents, links, witnesses—displayed chronologically when present. Context enriches understanding without modifying the original artifact. When empty, the record communicates that adding context is available and additive.

#### 4. Where did it come from?

**Answered by: Metadata**

Compact capture metadata: capture date, device, location, file size, duration, resolution, and other attribution fields—displayed only when available. Metadata supports defensibility and understanding of provenance without dominating the record.

### Layout Order

The Evidence Record follows a fixed vertical hierarchy:

```
Workspace navigation
  ↓
Evidence preview
  ↓
Evidence Information
  ↓
Integrity
  ↓
Context
  ↓
Metadata
  ↓
Sticky Add Context action
```

This order reflects the four pillars: evidence first, trust second, understanding third, provenance fourth. The sticky **Add Context** action remains persistent at the bottom—it is the primary enrichment affordance.

### Interaction Principle

Evidence Records are **observational**.

They are designed for reading, understanding, and preserving trust—not for modifying preserved artifacts.

Primary actions should **enrich the record** rather than modify the preserved evidence. The canonical primary action is **Add Context**. Actions that imply editing, replacing, or deleting preserved evidence are prohibited in the Evidence Record experience.

### Language Rules

Within and around Evidence Records, the product must never use:

- Edit Evidence
- Replace Evidence
- Modify Evidence

Use instead:

| Preferred Language | Purpose |
|---|---|
| **Add Context** | Primary enrichment action |
| **View Record** | Navigation to the Evidence Record |
| **Integrity Verified** | Trust confirmation |
| **Context Enriched** | Context has been added around evidence |
| **Evidence Record** | The screen and concept name |
| **Preserved** | Evidence status—not "saved" or "uploaded" |

Language must align with [`docs/LANGUAGE_SYSTEM.md`](LANGUAGE_SYSTEM.md).

### Relationship to Other Surfaces

| Surface | Role |
|---|---|
| **Evidence Map** | Overview of all artifacts; entry point to individual Evidence Records |
| **Evidence Record** | Permanent home of one artifact; four-pillar understanding model |
| **Capture Cockpit** | Active Capture State for Photo / Video / Voice; returns to same Incident Workspace |
| **Incident Workspace** | Persistent Incident State — timeline, sticky capture, Story / Trust Package entry |

The Evidence Record is not a substitute for the Evidence Workspace. It is the deepest single-artifact view within the review layer (Progressive Intelligence Level 3 — Understanding).

### Future Readiness

Reserve architectural extension points within the four-pillar model. These extend the **understanding** of the record. They **never alter** the preserved evidence.

| Extension | Pillar Strengthened |
|---|---|
| **Relationships** | Context — how this evidence connects to other evidence |
| **Reflection** | Context — wisdom preserved around the artifact |
| **Chain of Custody** | Integrity — verification and custody history |
| **AI Analysis** | Context — interpretive assistance, clearly labeled |
| **Verification History** | Integrity — audit trail of integrity checks |

Future sections must map to one of the four pillars. Unrelated utility sections (sharing settings, file management, edit tools) do not belong in the Evidence Record.

---

## 11. Progressive Documentation

Incidents may evolve over hours, days, or weeks. The UX supports this through explicit capabilities.

| Capability | Experience |
|---|---|
| **Pause** | User suspends active documentation. Incident remains in Paused state. Home surfaces Continue Preserving. |
| **Resume** | User returns to Evidence Workspace with full context restored. |
| **Enrich** | User adds annotations, titles, categories, tags, and descriptions after capture. Additive only. |
| **Finalize** | User declares the record complete for its purpose. Core evidence locked; workspace communicates finality. |
| **Supplement** | User adds evidence after initial documentation period. Items marked supplementary; chronology preserved. |

Progressive documentation means the platform never punishes incomplete records. A single photo captured in urgency is a valid start. A fully annotated record captured over weeks is a valid end. The journey between is supported without resetting or shaming the user.

---

## 12. Finalize Incident

### Experience

Finalizing is a deliberate, calm action—not an irreversible panic button.

When the user finalizes:

- **Chronology is preserved** — the Evidence Chain remains intact and ordered
- **Supplementary evidence may still be permitted** per product policy—finalization locks core record integrity, not necessarily all future enrichment
- **The incident is prepared for sharing** — Trust Package assembly becomes a primary affordance
- **Status transitions to Finalized** — workspace and Vault reflect the new state clearly

### Finalizing a Record vs. Ending an Event

| Concept | Meaning |
|---|---|
| **Finalizing a Record** | The user declares documentation complete for its intended purpose. Software state changes. |
| **Ending an Event** | Real-world events may continue or evolve. Finalization does not claim the world stopped. |

The UX must never imply that finalizing means "nothing else can ever happen." Copy and flows distinguish *documentation completeness* from *physical-world closure*. Users finalize records; they do not close reality.

---

## 13. Library of Truth

The **Vault** is the permanent repository of Truth Records.

### Purpose

**Permanent repository of Truth Records.**

The Vault is not a file manager. It does not organize by folder hierarchy or arbitrary file names. It preserves history—incidents, their evidence chains, verification, and reports—so truth remains accessible over time.

### Sections

| Section | Content |
|---|---|
| **Paused Incidents** | Incidents awaiting resume; quick path back to Evidence Workspace |
| **Finalized Incidents** | Completed truth records ready for review and reporting |
| **Archived Incidents** | Long-term preserved records in the Library of Truth |
| **Search** | Find incidents and evidence by title, date, category, and relevant metadata |
| **Filters** | Narrow by status, date range, category, verification state |
| **Reports** | Access and generate Trust Packages from preserved incidents |
| **Verification** | Review verification status and integrity across evidence |

### Experience Tone

Browsing the Vault should feel like entering a library—not a storage drive. Records have titles, statuses, and meaning. History is respected. Nothing is presented as disposable clutter.

---

## 14. Profile

The **Profile** surface manages account identity, security, and preferences. It is separate from incident documentation to keep Home and Workspace focused on capture and preservation.

| Area | Purpose |
|---|---|
| **Account** | Name, email, identity management |
| **Security** | Password, session management, account protection |
| **Biometrics** | Fingerprint, face, or device biometric unlock where supported |
| **Settings** | Application behavior and display preferences |
| **Notifications** | Alert preferences for sync, reminders, and account events |
| **Subscription** | Plan, billing, and feature entitlements where applicable |
| **Privacy** | Data handling preferences, permission transparency |
| **Export Preferences** | Default formats and options for report and data export |
| **Help** | Guidance, support access, documentation links |
| **About** | Application version, legal notices, product information |

Profile must not become a secondary incident management screen. Documentation belongs in Home, Workspace, and Vault—not in account settings.

---

## 15. AI Experience

AI operates as an **assistant**, not an authority.

### AI May

| Capability | UX Requirement |
|---|---|
| **Generate summaries** | Labeled as AI-generated; references source evidence |
| **Generate reports** | Structured output with traceability to Evidence Chain |
| **Create timelines** | Derived from capture chronology; gaps acknowledged |
| **Identify possible similarities** | Presented as suggestions for user review—not automatic links |
| **Generate reconstructions** | Clearly marked as interpretive; confidence expressed |

### AI Must Never

- Replace user judgement
- Present unsupported claims as fact
- Modify evidence or chronology
- Link incidents without explicit user action

### Transparency Requirements

- **AI always explains confidence** — uncertain outputs say so
- **AI always references supporting evidence** — generated content links to source items
- **AI output is visually distinct** from captured evidence and verification data

Users must always understand what AI produced versus what was captured from reality.

---

## 16. UX States

Every state in the application must feel **calm**, **simple**, and **trustworthy**.

| State | Experience |
|---|---|
| **Empty State** | Reassuring, not accusatory. Home invites capture; Vault explains that preserved records will appear. No guilt for empty libraries. |
| **Active Incident** | Focused workspace energy. Capture bar available. Status shows Active. Progress feels natural. |
| **Paused Incident** | Restful pause—not abandonment. Continue Preserving on Home offers gentle return. |
| **Finalized Incident** | Sense of completion and preservation. Trust Package affordances prominent. No pressure to edit core evidence. |
| **Archived Incident** | Historical dignity. Accessible but clearly long-term storage. |
| **No Search Results** | Clear, helpful. Suggest broadening criteria. Never imply user error. |
| **Offline** | Capture continues where possible. Sync status visible. No alarming blocking unless truly required. |
| **Syncing** | Subtle progress indication. Automatic saving communicated. User not asked to manage sync manually. |
| **Error** | Plain language. Recovery path offered. Retry when appropriate. Never blame the user. |
| **Loading** | Brief, purposeful. Skeleton or progress that respects user time. Never indefinite spinner without context. |

States must never use alarm colors, aggressive copy, or interrupt capture unless safety or integrity requires it.

---

## 17. Interaction Principles

| Principle | Application |
|---|---|
| **Large touch targets** | Minimum comfortable tap areas for capture and primary actions |
| **Minimal taps** | Shortest path to capture, resume, and finalize |
| **Automatic saving** | User never manually saves evidence or incident state |
| **Clear feedback** | Every action confirms success or explains failure calmly |
| **No unnecessary dialogs** | Confirm only irreversible or high-stakes actions |
| **Consistent animations** | Same transitions for same context changes everywhere |
| **Progressive disclosure** | Detail on demand; simplicity by default |
| **Thumb-friendly navigation** | Primary actions within natural thumb reach on mobile |
| **Evidence Records are observational** | Single-artifact views enrich understanding; they never modify preserved evidence |

Interactions are evaluated against stress context: if it feels cumbersome during calm review, it will fail during urgent capture.

---

## 18. Motion Principles

Animation serves orientation—not decoration.

| Principle | Description |
|---|---|
| **Fast** | Transitions complete quickly; capture never waits on animation |
| **Purposeful** | Motion indicates navigation direction, hierarchy, or state change |
| **Never distracting** | No gratuitous effects during capture or review of sensitive evidence |
| **Context changes explained** | Entering workspace, capture mode, or Vault feels directionally consistent |
| **Capture modes animate consistently** | Photo, video, voice, note, attachment share enter/exit patterns |
| **Navigation feels natural** | Tab changes and back navigation preserve spatial mental model |

Motion must reduce disorientation. If animation causes uncertainty about where evidence went or what changed, it fails.

---

## 19. Accessibility Principles

Accessibility is a **core requirement**, not a later enhancement.

| Principle | Requirement |
|---|---|
| **Readable typography** | Sizes and weights support comfortable reading under stress |
| **High contrast** | Text and controls meet contrast standards for clarity |
| **Screen reader support** | All capture actions, evidence items, and statuses are announced meaningfully |
| **Large touch areas** | Targets accommodate motor difficulty and gloved use |
| **Clear labels** | Icons paired with text; ambiguous symbols avoided for primary actions |
| **Simple language** | Plain words over technical or legal jargon in primary flows |

An accessible Evidence Vault is a more trustworthy Evidence Vault—for every user, in every moment.

---

## 20. UX Non-Negotiables

These UX rules are permanent.

1. **Capture before categorization.** Organization follows evidence; it never precedes it.
2. **Never interrupt evidence capture.** No dialogs, ads, or unrelated prompts during recording.
3. **Never require unnecessary decisions.** Every required choice must serve preservation or trust.
4. **Never silently modify evidence.** Changes are visible, auditable, and user-initiated.
5. **Never hide chronology.** The evidence timeline is always accessible and honestly ordered.
6. **Always preserve trust.** Transparency over cleverness; clarity over compression.
7. **Always prioritize clarity.** If a user must read twice, the design has failed.
8. **Evidence Records are observational.** Single-artifact views serve reading and understanding; primary actions enrich context—they never modify preserved evidence.
9. **Workspace is Incident State — never empty staging.** Capture Now Photo/Video/Voice go New Incident → Cockpit → Same Workspace.
10. **Continue Preserving opens existing Workspace only** — no automatic Cockpit.
11. **Cockpit never creates or replaces an incident** — Note/File stay Workspace-only.
12. **Primary Photo/Video/Voice journeys must not bypass Cockpit** via competing direct-camera paths.

Full invariant list: [`CAPTURE_COCKPIT_ARCHITECTURE.md`](CAPTURE_COCKPIT_ARCHITECTURE.md).

Violations of these rules require explicit product constitution amendment—not informal exception.

---

## 21. Future UX

The following concepts belong to **future releases**. They are not part of Version 1 UX scope but are reserved for coherent expansion.

| Future Concept | Intended Experience Direction |
|---|---|
| **Incident Reconstruction** | Visual or narrative reconstruction clearly labeled as derived |
| **Collaborative Incidents** | Multi-user documentation with defined roles |
| **Secure Sharing** | Controlled disclosure flows with audit and consent |
| **Organization Workspaces** | Team or enterprise containers above individual Vault |
| **Professional Review** | Third-party or expert review workflows on preserved records |
| **Cross-Incident Insights** | Pattern views that never auto-link; user confirms all relationships |
| **Evidence Record Extensions** | Relationships, reflection, chain of custody, AI analysis, verification history—each strengthens a pillar without modifying evidence |

Future UX must inherit all non-negotiables and domain rules. Expansion adds capability; it does not relax trust.

---

## 22. UX Mission Statement

Evidence Vault should feel **calm during stressful moments**.

The interface should **disappear behind the user's task**. Users document reality—the scene, the conversation, the document, the moment. Evidence Vault quietly preserves, organizes, and gives meaning to that reality without demanding attention for itself.

Users capture. The platform protects. The Library preserves. Trust Packages represent—never replace.

**Time tells us when something happened. Relationships tell us why it mattered. Evidence Vault preserves both.**

Design decisions are measured by a single question: *Does this help someone preserve truth when it matters most?*

**When people need evidence most, they should remember the event—not how to use the application.**

---

*This document is the permanent UX specification for Evidence Vault. All screens, interactions, animations, and workflows must conform to these definitions and principles.*
