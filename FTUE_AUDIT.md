# First-Time Experience Audit — Sprint 6.5

**Scope:** Journey from first launch to first preserved evidence (and first context / reflection)  
**Voice reference:** `docs/LANGUAGE_SYSTEM.md` — calm, trustworthy, compassionate, never overwhelming  
**Device reference:** Motorola moto g35 5G (primary Android target)

---

## Executive Summary

Evidence Vault's **canonical product surfaces** (Library empty state, Journey language, Reflection prompts, Evidence Map empty) strongly honor the compassionate voice. The FTUE breaks down at three layers:

1. **Splash & auth** — high reading load, marketing tone, account-before-capture hierarchy  
2. **Home → Workspace handoff** — double-tap capture, capture type discarded, mock Library Insights on empty Home  
3. **Empty workspace** — ten scroll sections before first artifact, competing CTAs, disabled export buttons visible

There is **no dedicated onboarding** — philosophy (preserve → enrich → reflect) is implied in copy but never taught in sequence.

| Stage | Encouraging? | Compassionate voice? | Overwhelming? |
|-------|--------------|----------------------|---------------|
| Splash | Partial | Weak (marketing) | **Yes** — ~80–100 words pre-action |
| Auth | Neutral | Mixed | Moderate |
| Empty Home | **Yes** | **Strong** | Low (except mock insights leak) |
| First Capture | Frustrating | Good snackbars | Moderate (extra tap) |
| Empty Workspace | Guiding copy | **Strong** in sections | **Yes** — section overload |
| First Evidence Record | Informative | Good integrity copy | **Yes** — six pillars |
| First Context | **Yes** | **Strong** | Low |
| First Reflection | **Yes** | **Strong** | Low (but buried in scroll) |

---

## Journey Map

```
App launch (main.dart → SplashScreen)
    │
    ├─ Create Account ──► MainShell / Home
    ├─ Log in ──────────► Home
    └─ Google / Apple ──► Home
                              │
                    Empty Library + Capture Now (sticky)
                              │
                    Tap capture type (Photo, etc.)
                              │
                    Evidence Workspace (EMPTY — type ignored)
                              │
                    Tap capture bar AGAIN
                              │
                    "Evidence preserved." → mock artifact
                              │
                    Tap Evidence Map card
                              │
                    Evidence Record → Add Context (sticky)
                              │
                    Scroll workspace → Reflection → Add Reflection
```

**Cold start:** No session restore — every launch returns to Splash (`lib/main.dart`).

---

## Stage-by-Stage Audit

### 1. Splash Screen

**File:** `lib/screens/splash_screen.dart`

#### Copy inventory

| Element | Text |
|---------|------|
| Hero | *"Have you ever wished to have proof of what really happened?"* |
| Subline | *"Helping you enrich your most valuable asset — your truth."* |
| Banner | *"Secure every moment. Build your trusted timeline. Turn life's moments into professional reports."* |
| Feature cards | **Encrypted** / End-to-End Protection · **Time Stamped** / Trusted Date & Time · **Organised** / All your records |
| Primary CTA | **Create Account** |
| Social | **Continue with Google** · **Continue with Apple** |
| Secondary | *"Already have an account?"* **Log in** |

#### Reading effort: **High**

Seven text blocks before action: logo, hero (2 lines + subline), value banner (3 clauses), three feature cards (six micro-labels), auth stack. Estimated **80–100 words** — highest drop-off risk in FTUE.

#### Information density: **High**

Feature cards add security/product claims before the user understands what the app does. Banner conflates preservation with *"professional reports"* (export feature not built).

#### Button hierarchy

| Level | Control |
|-------|---------|
| Primary | Create Account (filled, elevated) |
| Secondary | Google / Apple (outlined) |
| Tertiary | Log in (text, shrinkWrap — fixed in 6.4 to 48dp target) |

**Issue:** Primary action is account creation, not preservation. Product value deferred until post-auth.

#### Voice alignment

| ✅ Aligned | ❌ Misaligned |
|-----------|--------------|
| *"your truth"* | *"professional reports"* — product pitch |
| *"Helping you enrich"* | **Organised / All your records** — storage language, not Library language |
| | **Encrypted / E2E** — overstated (see TRUST_AUDIT.md) |
| | Hero question — emotionally valid but dramatic vs. *quiet confidence* |

---

### 2. Onboarding

**Finding: No dedicated onboarding flow.** No routes, screens, or coach marks. FTUE = Splash + Auth only.

#### Auth paths

| Path | Destination | Success message |
|------|-------------|-----------------|
| Create Account | Home | *"Account created successfully. Welcome to Evidence Vault."* |
| Sign In | Home | *"Signed in successfully. Welcome back."* |
| Google / Apple | Home | *"Signed in with Google/Apple."* |

#### Create Account copy highlights

- *"Create your secure vault"*
- *"Organize life's moments into trusted timelines and professional reports…"*
- *"Your information is encrypted and never shared."*
- CTA: **Continue** (label mismatch with Splash **Create Account**)

#### Login copy highlights

- *"Welcome back"*
- *"Sign in to access your secure vault and trusted timelines."*

#### Evaluation

| Dimension | Assessment |
|-----------|------------|
| Reading effort | Moderate — cleaner than Splash |
| Information density | Acceptable on forms; reassurance line adds trust claim |
| Button hierarchy | Clear: Continue / Sign In primary |
| Discoverability | User learns nothing about Capture → Workspace → Library arc |

**Voice drift:** *"successfully"*, *"Welcome"* — slightly celebratory; LANGUAGE_SYSTEM prefers *Preserved* over *Completed*.

---

### 3. Empty Library (Home)

**Files:** `library_of_truth_section.dart`, `home_body.dart`, `home_dashboard_mock.dart`

#### Canonical empty copy ✅

- **The Library of Truth**
- *"Every library begins with one piece of truth."*
- *"Enrich it as your story unfolds."*
- `LibraryPreviewIllustration` — faded aspirational incidents (non-interactive)

#### Home hero ✅

- *"Preserve your truth now."*
- *"Protect what matters later."*

#### Capture Now section ✅

- **Capture Now**
- *"Focus on the moment. Evidence Vault remembers the rest."*
- Five equal-weight tiles: Photo · Video · Voice · Note · File

**Strong compassionate alignment** on Library and Capture headings.

#### Critical FTUE bug: Mock Library Insights on empty Home

```dart
// home_dashboard_mock.dart
static List<LibraryIncidentSummary> libraryIncidents = [];  // → empty Library UI ✓
static List<LibraryIncidentRecord> libraryIncidentRecords = activeLibraryIncidentRecords;  // 3 mock incidents
```

`HomeBody` generates **Library Insights** from `libraryIncidentRecords` regardless of `libraryIncidents` being empty. First-time users see cross-incident patterns referencing *"Harbour Office"*, *"Alex Morgan"* while Library shows empty state.

**Impact:** Breaks trust and contradicts empty-state intent.

#### Reading effort / density

| Above fold (approx.) | Content |
|---------------------|---------|
| Logo | Decorative |
| Hero | 2 lines |
| Library section | 3 lines + illustration |
| Library Insights | 1–3 cards (should not appear) |
| Capture Now | Heading + subline + 5 buttons |

**Moderate** without insights leak; **confusing** with insights present.

---

### 4. First Capture

**Files:** `home_screen.dart`, `quick_capture_section.dart`, `evidence_workspace_screen.dart`

#### What happens today

```dart
// home_screen.dart — all capture types identical
void _handleCaptureTap(BuildContext context, QuickCaptureType type) {
  // TODO(Sprint 4): Route to the appropriate capture mode, then land in workspace.
  AppNavigation.openEvidenceWorkspace(context);
}
```

| Step | User experience |
|------|-----------------|
| 1 | Tap **Photo** (or any type) on Home |
| 2 | Navigate to **empty** Workspace — **capture type discarded** |
| 3 | Tap again in sticky **Capture evidence** bar |
| 4 | Mock artifact created → snackbar *"Evidence preserved."* |

**Friction:** Two taps for first value moment. No camera, picker, or real capture (Sprint 4). User's Home intent (Photo vs Voice) is lost.

#### Snackbar copy ✅

*"Evidence preserved."* — calm, factual, matches LANGUAGE_SYSTEM.

#### Button hierarchy on Home

All five capture tiles are **equal visual weight** — no single *"start here"* primary. Sticky layer helps discoverability but not hierarchy.

#### Evidence Map from Home

`_handleViewEvidenceMap` shows *"Evidence Map coming in Sprint 5"* — only available when `libraryIncidents` has in-progress items; hidden on true empty Home.

---

### 5. Empty Workspace (First Visit)

**File:** `workspace_body.dart`

#### Visible scroll stack (empty state)

| # | Section | First-visit note |
|---|---------|------------------|
| 1 | Workspace Header | *"Evidence Workspace / Your incident lives here."* |
| 2 | View Story | **Disabled** |
| 3 | Prepare Trust Package | **Disabled** |
| 4 | Incident Journey | 4 stages, current: **EMPTY** |
| 5 | Incident Overview | 0 Artifacts, 0 Enrichments, 0 Connections |
| 6 | Evidence Map | Canonical empty + guidance |
| 7 | Incident Timeline | Empty + **Capture Evidence** button |
| 8 | Reflection | Compassionate empty + **Add Reflection** |
| 9 | Enrich Your Record | 5 rows × *"Not yet"* |
| 10 | Incident Status | Draft |
| + | Sticky capture bar | 5 mode buttons |

**Total: 10 sections + sticky bar** before first artifact.

#### Reading effort: **Very high**

Multiple sections repeat the same invitation to capture (Timeline button + sticky bar + Evidence Map empty). Disabled Story/Trust Package buttons add visual noise. Completeness checklist (*"Not yet"* × 5) resembles a task manager — LANGUAGE_SYSTEM warns against progress/completion framing.

#### Journey stage

`currentStage` hardcoded to `JourneyStage.empty` in workspace screen — **never advances** when user preserves evidence.

#### What works ✅

- Evidence Map empty (`evidence_map_empty.dart`): *"Every library begins with one piece of truth."* / *"Preserve your first piece of evidence below."*
- Incident Journey canonical stage copy
- Sticky capture bar always visible

---

### 6. First Evidence Record

**File:** `evidence_record_screen.dart`

#### Entry

Tap artifact in Evidence Map → **Evidence Record**

#### Sections (scroll order)

| # | Section | First visit |
|---|---------|-------------|
| 1 | Evidence + metadata | Type, timestamp, source |
| 2 | Integrity | *"Preserved / Original evidence remains unchanged."* |
| 3 | Verification | Not Verified |
| 4 | Context timeline | Empty state |
| 5 | Linked Evidence | Empty + Link button |
| 6 | Metadata detail | Device, capture date |

#### Sticky primary: **Add Context** ✅

Clear hierarchy — one obvious next step for enrichment.

#### Evaluation

| Dimension | Assessment |
|-----------|------------|
| Reading effort | High — six sections, no first-visit orientation |
| Information density | High for emotional first capture |
| Button hierarchy | **Strong** — Add Context sticky primary |
| Discoverability | Requires finding Evidence Map → tapping card |

**Missing:** Gentle first-visit line — *"This is your preserved artifact. You can enrich it without changing it."*

---

### 7. First Context

**Files:** `add_context_sheet.dart`, `context_timeline_section.dart`

#### Add Context sheet ✅

- **Add Context**
- *"Context enriches this evidence without changing the original."*
- Options: Note · Voice · Photo · Video · Document (equal tiles)

#### Context timeline empty ✅

- *"No additional context yet."*
- *"Every piece of context helps build a richer understanding without changing the preserved evidence."*

#### After selection

Snackbar: *"Relationship created. Context preserved."*

#### Discoverability

| From | Findable? |
|------|-----------|
| Evidence Record | **Yes** — sticky Add Context |
| Workspace / Evidence Map | **No** — must open record first |
| Insights | Suggests after first artifact (`rule_based_insight_engine.dart`) |

**Strong voice; hidden path** until user discovers Evidence Record.

---

### 8. First Reflection

**Files:** `reflection_section.dart`, `reflection_editor_sheet.dart`

#### Empty state ✅ (exemplary compassionate voice)

- **Reflection** — *"What this experience taught you."*
- Prompt: *"What did you learn when you looked back?"*
- *"Sometimes understanding comes with time."*
- *"When you're ready, record what this experience taught you."*
- CTA: **Add Reflection**

#### Editor sheet ✅

- Title optional, body required
- Save toast: *"Reflection Added"* (canonical term)

#### Evaluation

| Dimension | Assessment |
|-----------|------------|
| Voice | **Best-in-app** for FTUE compassion |
| Reading effort | Low within section |
| Discoverability | **Weak** — ~8th workspace section; easy to miss |
| Timing | No deferral — shown before first capture, may feel premature |

**Recommendation:** Defer Reflection section until ≥1 artifact — *"When you're ready"* applies to timing, not just copy.

---

## Cross-Cutting Evaluation

### Reading effort (journey total)

| Phase | Words (est.) | Effort |
|-------|--------------|--------|
| Splash | 80–100 | High |
| Auth | 40–60 | Moderate |
| Home empty | 30–50 + insights | Moderate–High |
| Workspace empty | 100+ across sections | **Very High** |
| Evidence Record | 60+ | High |
| Context sheet | 20 | Low |
| Reflection | 40 | Low |

**Cumulative:** A motivated user reads **300+ words** before first context action.

### Information density

```
HIGH ████████████ Splash, Empty Workspace, Evidence Record
MED  ██████       Auth, Home (without insights)
LOW  ███          Context sheet, Reflection section
```

### Button hierarchy summary

| Screen | Primary | Problem |
|--------|---------|---------|
| Splash | Create Account | Preservation not primary |
| Home | 5 equal capture tiles | No single "start here" |
| Workspace empty | Timeline Capture + sticky bar + Reflection | **Three competing primaries** |
| Evidence Record | Add Context (sticky) | Clear ✅ |
| Context sheet | 5 equal options | Acceptable for choice |
| Reflection | Add Reflection | Clear but buried |

### Discoverability matrix

| Capability | Without guidance | Path |
|------------|------------------|------|
| Capture | ✅ Yes | Home sticky Capture Now; Workspace sticky bar |
| Evidence Map | ⚠️ Partial | Workspace scroll; Home link stub/hidden |
| Evidence Record | ⚠️ After capture | Evidence Map → tap card |
| Add Context | ❌ No | Evidence Record sticky only |
| Reflection | ❌ Weak | Deep workspace scroll |
| Link Evidence | ❌ No | Evidence Record, needs ≥2 artifacts |
| View Story / Trust Package | Visible, disabled | May confuse new users |
| Vault tab | ✅ Yes | Placeholder only |

---

## Compassionate Voice Scorecard

| Surface | Score | Notes |
|---------|-------|-------|
| Library empty | ✅ Strong | Canonical LANGUAGE_SYSTEM |
| Home hero + Capture Now | ✅ Good | Calm, guiding |
| Evidence Map empty | ✅ Strong | Matches Library language |
| Reflection empty | ✅ **Exemplary** | Acknowledge, reassure, no pressure |
| Journey card | ✅ Good | Maturity framing, not gamified |
| Workspace snackbars | ✅ Good | *"Evidence preserved."*, *"Context preserved."* |
| Splash + Auth | ❌ Weak | Marketing, reports, encryption claims |
| Completeness card | ⚠️ Mixed | *"Not yet"* × 5 feels like checklist |
| Mock Library Insights | ❌ Breaks trust | Fake data on empty Home |
| Auth success toasts | ⚠️ Minor | *"successfully"*, *"Welcome"* |

---

## Friction Points (Prioritized)

| P | Issue | Impact |
|---|-------|--------|
| **P0** | Mock Library Insights on empty Home | Contradicts empty Library; confuses first-time users |
| **P0** | Double-tap capture (Home → empty Workspace → capture again) | Abandonment before first artifact |
| **P1** | Workspace section overload (10 sections pre-capture) | Overwhelming; violates *never overwhelming* objective |
| **P1** | Splash reading load + marketing copy | Drop-off before auth |
| **P1** | Disabled Story/Trust Package visible when empty | Visual noise |
| **P2** | Journey stage never advances from EMPTY | User progress not reflected |
| **P2** | Context path hidden from workspace | Discoverability gap |
| **P2** | Reflection shown before first capture | Premature; adds scroll |
| **P2** | No onboarding teaching preserve → enrich → reflect | Philosophy implied, not guided |
| **P3** | Auth celebratory toasts | Minor voice drift |
| **P3** | Capture type discarded from Home | Loses user intent |
| **P3** | Evidence Map Home handler stub | Dead end if enabled |

---

## Recommended Refinements

Prioritized by impact, voice alignment, and implementation risk. **No code changes in Sprint 6.5** — recommendations for Sprint 4+ and polish passes.

### P0 — Fix before external FTUE testing

| # | Refinement | Files | Rationale |
|---|------------|-------|-----------|
| 1 | **Hide Library Insights when `libraryIncidents` is empty** | `home_body.dart`, `home_dashboard_mock.dart` | Empty Home must not show fake cross-incident data |
| 2 | **Single-tap first capture:** pass `QuickCaptureType` → Workspace → auto-`preserveEvidence` on land | `home_screen.dart`, `app_navigation.dart`, `evidence_workspace_screen.dart` | One tap to first artifact; honor user's type choice |
| 3 | **Collapse empty workspace** to: Header → Journey → Evidence Map → (sticky capture). Hide Overview, Completeness, Status, Reflection, disabled Story/Trust until ≥1 artifact | `workspace_body.dart` | Progressive disclosure; *never overwhelming* |

### P1 — Voice & hierarchy polish

| # | Refinement | Files | Suggested copy |
|---|------------|-------|----------------|
| 4 | Soften Splash banner | `splash_screen.dart` | *"Evidence is preserved. Context is enriched. Your Library grows."* |
| 5 | Replace feature card **Organised / All your records** | `splash_screen.dart` | **Preserved / Your Library grows** |
| 6 | Defer or soften **Encrypted / E2E** card until crypto ships | `splash_screen.dart` | **Protected / On your device** (per TRUST_AUDIT) |
| 7 | Auth success messages | `create_account_screen.dart`, `login_screen.dart` | *"Your vault is ready."* / *"Signed in."* — not *"successfully"* |
| 8 | Hide disabled **View Story** / **Prepare Trust Package** until evidence exists | `workspace_body.dart` | Remove visual noise for FTUE |
| 9 | Single primary on Home: optional hero **Preserve Now** above type grid | `quick_capture_section.dart` | Clear hierarchy for first visit |

### P2 — Journey progression & discoverability

| # | Refinement | Files | Rationale |
|---|------------|-------|-----------|
| 10 | Advance `JourneyStage` EMPTY → BUILDING on first `preserveEvidence` | `evidence_workspace_screen.dart` | Reflect user progress |
| 11 | Show Reflection section only when `evidence.isNotEmpty` | `workspace_body.dart` | *"When you're ready"* — timing, not just words |
| 12 | After first artifact, surface **Add Context** hint on Evidence Map card or Insights | `evidence_map_section.dart`, insight engine | Guide enrichment without coach marks |
| 13 | First Evidence Record orientation line | `evidence_record_screen.dart` | *"This is your preserved artifact. Context can be added without changing it."* |
| 14 | Replace snackbar *"Reflection Added"* with *"Reflection preserved."* | `evidence_workspace_screen.dart` | LANGUAGE_SYSTEM consistency |

### P3 — Future onboarding (Sprint 7+)

| # | Refinement | Rationale |
|---|------------|-----------|
| 15 | **3-step first-run overlay** (optional, dismissible): (1) Capture preserves truth (2) Context enriches (3) Reflection comes when ready | Teach arc without blocking |
| 16 | **Skip auth for local-first trial** (product decision) | Let user preserve before account — reduces Splash friction |
| 17 | Wire real capture (camera/picker) before marketing FTUE | Mock double-tap erodes trust |
| 18 | Session restore — skip Splash for returning users | Respect repeat visits |
| 19 | Landscape-aware Home capture grid | Motorola rotation usability |

---

## Ideal First-Time Arc (Target State)

```
Splash (minimal copy, 1 hero line)
    → Auth (optional / deferred)
    → Home
        Hero: "Preserve your truth now."
        Library: empty (no fake insights)
        ONE tap: Capture Photo → Workspace with artifact already preserved
            Workspace (collapsed):
                Journey (BUILDING)
                Evidence Map (1 card)
                Sticky capture
            Tap card → Evidence Record
                Sticky: Add Context
            (Reflection appears later, when ready)
```

**Reading budget target:** <150 words from launch to first preserved artifact.

---

## Manual QA Script (Motorola)

1. Cold launch → count words before first tap; note marketing tone  
2. Create account → Home: confirm Library empty **and** no Library Insights  
3. Tap **Photo** → confirm one tap yields preserved artifact (after P0 #2)  
4. Empty workspace: count visible sections; note disabled buttons  
5. Tap Evidence Map card → Evidence Record → **Add Context** sheet copy  
6. Add context → confirm snackbar and timeline update  
7. Scroll to Reflection → evaluate timing (too early?)  
8. Re-read all empty-state copy aloud — does it feel like a companion or software?

---

## Test Coverage Gaps

| Scenario | Covered? |
|----------|----------|
| Navigation to Home / Workspace | ✅ `main_shell_navigation_test.dart` |
| First capture preserves evidence | ✅ Widget test |
| Empty Library without insights | ❌ Not tested |
| Single-tap Home → preserve | ❌ Not tested |
| Collapsed empty workspace | ❌ Not tested |
| FTUE copy regression | ❌ Not tested |

---

## Conclusion

Evidence Vault's **Reflection empty state**, **Library empty state**, and **Context sheet** are model implementations of the compassionate voice. The FTUE journey fails the *never overwhelming* objective at **Splash** (reading load), **Home** (mock insights leak), and **empty Workspace** (section overload). The highest-impact refinements are: **clear fake insights on empty Home**, **single-tap capture to first artifact**, and **progressive disclosure** collapsing the empty workspace to three guiding sections.

Until P0 refinements ship, treat external FTUE testing as **internal UX review only** — the double-tap capture path and mock insights will skew user feedback.

---

*Sprint 6.5 — First-Time Experience. Audit and recommended refinements; documentation only.*
