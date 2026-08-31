# Capture Cockpit Architecture

**Status:** Active — Sprint 6C Architecture Source-of-Truth  
**Last Updated:** August 10, 2026  
**Authority:** Dedicated source of truth for Capture Cockpit and its relationship to Incident Workspace.

Related:

- [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) — Workspace = Incident State; Cockpit = Active Capture State
- [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) — navigation architecture; three canonical flows
- [`DOMAIN_MODEL.md`](DOMAIN_MODEL.md) — Incident, CaptureSession, Evidence
- [`EVIDENCE_RECOVERY_ARCHITECTURE.md`](EVIDENCE_RECOVERY_ARCHITECTURE.md) — incident identity across recovery
- [`DOCS_INDEX.md`](../DOCS_INDEX.md) — documentation map

---

## Source-of-truth rule

Before changing any of the following, consult this document and [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md):

- Home capture routing
- Workspace navigation
- Cockpit navigation
- CaptureSession lifecycle
- incident creation
- incident recovery
- evidence persistence
- modality switching

If existing code conflicts with these documents, **identify the conflict explicitly** before implementation. Do **not** silently change the architecture to match legacy code.

---

## A. Purpose

**Capture Cockpit** is the focused immersive environment used when the user is actively capturing **Photo**, **Video**, or **Voice**.

It is **Active Capture State** — not incident management, not a persistent home, and not a staging Workspace.

Cockpit exists so investigators can preserve reality under stress with:

- an immersive live camera / microphone surface
- translucent modality controls
- premium immersive presentation
- background evidence capture pipeline

All evidence captured in Cockpit belongs to the **`incidentId` with which Cockpit was opened**.

---

## B. Workspace vs Cockpit distinction

Evidence Vault has two distinct states:

| State | Surface | Meaning |
|---|---|---|
| **Incident State** | **Incident Workspace** | Persistent environment for a real/current incident |
| **Active Capture State** | **Capture Cockpit** | Temporary immersive Photo / Video / Voice capture |

### Incident Workspace

The Workspace always represents a real/current incident and therefore must contain either:

- evidence captured during the current Capture Now → Cockpit flow, or
- evidence already belonging to an existing incident

The Workspace is **NEVER** an empty capture staging screen.

The Workspace contains:

- incident identity
- previously captured evidence
- newly captured evidence
- chronological evidence timeline
- organization / investigation / trust capabilities as applicable
- sticky capture actions (Photo / Video / Voice → Cockpit; Note / File on Workspace)

### Capture Cockpit

The Cockpit operates **ON** an existing incident.

The Cockpit does **NOT** own incident creation.

---

## C. Canonical flows

### Flow 1 — Home → Capture Now

Capture Now means: *I am starting a NEW incident and want to capture immediately.*

```
HOME
  ↓
CAPTURE NOW
  ↓
CREATE / ESTABLISH NEW INCIDENT
  ↓
OPEN CAPTURE COCKPIT
  ↓
Photo / Video / Voice
  ↓
Capture evidence
  ↓
DONE / EXIT
  ↓
SAME INCIDENT WORKSPACE
```

Rules:

- User must **not** first land in an empty Workspace
- Evidence captured in Cockpit belongs to the same `incidentId` that becomes the Workspace incident
- No duplicate incident may be created during this flow
- Note / File Capture Now open Workspace only (not Cockpit)

### Flow 2 — Home → Continue Preserving

Continue Preserving means: *I am returning to an existing incident.*

```
HOME
  ↓
CONTINUE PRESERVING
  ↓
EXISTING INCIDENT WORKSPACE
```

Do **NOT** automatically open Capture Cockpit. The Workspace already contains the incident’s existing evidence.

### Flow 3 — Workspace → Sticky Capture Bar

```
INCIDENT WORKSPACE
  ↓
STICKY CAPTURE BAR
  ↓
Photo / Video / Voice
  ↓
CAPTURE COCKPIT
  ↓
Capture additional evidence
  ↓
DONE / EXIT
  ↓
SAME INCIDENT WORKSPACE
```

Rules:

- `incidentId` remains unchanged
- All previous evidence remains visible
- New evidence is appended to the same timeline
- Evidence count is cumulative

---

## D. Incident identity contract

### Capture Now

```
new incidentId
    ↓
CaptureSession
    ↓
Capture Cockpit
    ↓
Evidence
    ↓
Workspace
```

The same `incidentId` must survive the entire journey.

### Workspace continuation

```
existing incidentId
    ↓
Capture Cockpit
    ↓
additional Evidence
    ↓
same incidentId
    ↓
same Workspace
```

There must be **no silent incident replacement or duplication**.

Domain relationships: [`DOMAIN_MODEL.md`](DOMAIN_MODEL.md). Recovery: [`EVIDENCE_RECOVERY_ARCHITECTURE.md`](EVIDENCE_RECOVERY_ARCHITECTURE.md).

---

## E. Capture modalities

Capture Cockpit supports **ONLY**:

- Photo
- Video
- Voice

Cockpit characteristics (locked for current design):

- immersive capture experience
- live camera / microphone surface
- translucent modality controls
- premium immersive presentation
- tilted preview currently settled at **-5 degrees**
- orange four-sided preview border
- Photo / Video / Voice modality switching inside Cockpit
- background evidence capture pipeline
- evidence belongs to the `incidentId` passed into Cockpit

---

## F. Entry / exit rules

### Legitimate primary Cockpit entry paths

| Entry | Behavior |
|---|---|
| **A. Home Capture Now** (Photo / Video / Voice) | Creates / establishes new incident → opens Cockpit |
| **B. Workspace sticky Photo / Video / Voice** | Opens Cockpit for the **current** incident |

### Exit

Exiting Cockpit (DONE / close) returns to the exact Workspace / incident from which it was opened — except Capture Now, where exit opens the **newly created** incident’s Workspace (same `incidentId` used in Cockpit).

Cockpit does **not** own Workspace navigation beyond returning control to the incident Workspace flow.

---

## G. Evidence continuity

- Timeline is the authoritative visual representation of the incident’s accumulated evidence
- Evidence count is cumulative for the incident
- Returning from Cockpit retains all previous evidence and shows newly captured items
- CaptureSession remains an internal grouping / recovery concept — not a user-facing session manager

---

## H. Note / File boundary

| Action | Home |
|---|---|
| **Note** | Workspace capture action — does **not** enter Cockpit |
| **File** / Attachment | Workspace capture action — does **not** enter Cockpit |

Note and File are **never** Cockpit modalities.

---

## I. Legacy-path policy

For the **primary** user journeys there must be only the legitimate Cockpit entry paths in §F.

There must **not** be a competing legacy direct-camera path for:

- Home Capture Now Photo / Video / Voice
- Workspace sticky Photo / Video / Voice

If legacy direct camera / video / voice code exists elsewhere (for example secondary Organize / Investigation surfaces that still call `ContinuousCaptureSession.open` and bypass Cockpit), document it as a **legacy / secondary path**. Do **not** silently redefine the primary architecture to match it.

Known secondary / legacy reference (do not treat as canonical Capture Now / Workspace sticky flow):

- `EvidenceWorkspaceContent` → `ContinuousCaptureSession.open` (bypasses Capture Cockpit)

---

## J. Non-negotiable invariants

1. Workspace represents an actual Incident, never an empty capture staging state.
2. Capture Cockpit represents active capture, not incident management.
3. Capture Now creates a new Incident before opening Cockpit.
4. Capture Now: Home → New Incident → Cockpit → Same Incident Workspace.
5. Continue Preserving: Home → Existing Incident Workspace.
6. Continue Preserving does not automatically open Cockpit.
7. Workspace: Photo/Video/Voice → Cockpit → Same Workspace.
8. Cockpit never creates a new Incident.
9. Cockpit never changes incident identity.
10. All evidence captured in Cockpit belongs to the incidentId with which Cockpit was opened.
11. Exiting Cockpit returns to the exact Workspace from which it was opened, except for Capture Now where it returns to the newly created incident's Workspace.
12. Note/File are Workspace capture actions, not Cockpit modalities.
13. Timeline is the authoritative visual representation of the incident's accumulated evidence.
14. Evidence count is cumulative for the incident.
15. Recovery must preserve incident identity across logout/login, restart, crash recovery and offline hydration.
16. Primary Capture Now and Workspace Photo/Video/Voice journeys must not bypass Cockpit through competing direct-camera navigation.

---

## Cockpit does NOT

- create an Incident
- replace an Incident
- create a new CaptureSession as a replacement identity for an existing Workspace incident
- own incident naming
- own organization
- own investigation
- own trust package
- contain Note capture
- contain File attachment capture
- become the persistent Workspace
- change incident identity
