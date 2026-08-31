**Version:** 2.0  
**Status:** Active Engineering Reference  
**Last Updated:** July 31, 2026 (Sprint 8)

# Evidence Vault Design System

This document defines the visual identity and interaction language of Evidence Vault. It is the engineering reference that ensures every screen, component, and interaction feels like one coherent product.

This is not a Figma specification. It is a permanent design constitution for implementation. New visual patterns should be rare. When they are necessary, they must extend this system — not bypass it.

---

## Design Philosophy

Evidence Vault exists for moments when truth matters. The interface must communicate safety, clarity, and respect for what the user is preserving.

### The product should feel

- **Calm** — steady under stress; never urgent for its own sake
- **Trustworthy** — consistent, honest, and transparent in what it shows
- **Professional** — suitable for legal, workplace, and personal records alike
- **Premium** — considered details, generous space, refined restraint
- **Human** — warm without being casual; respectful of difficult moments
- **Uncluttered** — every element earns its place

### The product should never feel

- **Corporate** — cold dashboards, dense admin chrome, enterprise clutter
- **Busy** — competing actions, visual noise, stacked badges
- **Social-media inspired** — feeds, reactions, vanity metrics, infinite scroll theatrics
- **Gamified** — streaks, scores, progress bars for maturity, achievement language
- **Clinical** — sterile hospital UI, jargon-heavy labels, diagnostic tone
- **Alarmist** — red warnings, panic copy, fear-based urgency

The interface should disappear behind the user's task. Users witness and preserve. Evidence Vault quietly protects.

Product philosophy and non-negotiables live in [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md). This section defines how those principles translate into layout, priority, and interaction — not why they exist.

---

## Interaction Philosophy

These rules govern how surfaces behave. They are visual and ergonomic expressions of [`PRODUCT_PRINCIPLES.md`](PRODUCT_PRINCIPLES.md) — refer there for product rationale; apply the rules here in implementation.

### Workspace is not a dashboard

The Evidence Workspace is a **capture-and-build surface**, not an analytics console. Do not design it with metric tiles, completeness checklists, aggregate counters, or stacked verification cards. Visual density should serve preservation and enrichment — not monitoring.

See [`PRODUCT_PRINCIPLES.md` §3 — Workspace Philosophy](PRODUCT_PRINCIPLES.md).

### Reduce scrolling

Prefer compact, purposeful vertical rhythm over long scroll stacks. The Workspace should expose capture, Incident Journey, and essential actions without burying the sticky capture layer beneath excessive sections. Every additional scroll region must earn its place.

When content grows (evidence timeline, reflections), scroll within bounded areas — not by adding unrelated sections above the Action Layer.

### Evidence has visual priority

Preserved evidence previews, artifact cards, and timeline thumbnails are the visual heroes. Headers, badges, and chrome recede. On any screen, the eye should land on **what was captured** before metadata, status labels, or navigation chrome.

Typography weight, card prominence, and spacing should amplify evidence — not compete with it.

### Context belongs with evidence

Context, linked evidence, and enrichment affordances attach **to the evidence item** — in Evidence Records, context rows, and linked-evidence cards — not in detached dashboard panels. Design context as surrounding the artifact, not as a separate administrative area.

See [`PRODUCT_PRINCIPLES.md` §4 — Incident Journey Philosophy](PRODUCT_PRINCIPLES.md).

### Story is the intelligence centre

**View Story** receives the visual treatment of a reading and understanding surface: comfortable line height, clear section hierarchy, generous spacing for Timeline, Connections, Summary, and Trust Status. Do not duplicate Story-level intelligence (chronology narrative, connection graphs, trust synthesis) inside the Workspace layout.

See [`PRODUCT_PRINCIPLES.md` §7 — Story Philosophy](PRODUCT_PRINCIPLES.md).

### Trust Status replaces multiple verification cards

Communicate trust at the **incident level** through a single **Trust Status** presentation (Verification + Integrity) in View Story and Trust Package — not as scattered per-item verification cards across the Workspace.

Individual Evidence Records may show item-level integrity metadata. The Workspace must not accumulate redundant verification widgets. One calm trust summary beats many competing badges.

See [`PRODUCT_PRINCIPLES.md` §8 — Trust Philosophy](PRODUCT_PRINCIPLES.md).

### Capture is always the primary interaction

The sticky Capture Layer (Home) and Action Layer (Workspace) remain the most reachable, visually weighted controls on their screens. Secondary actions — View Story, Prepare Trust Package, navigation — use outlined or text styling and must not outrank capture in size, colour, or position.

After every successful capture, the interface returns focus to the working surface — never to a blocking acknowledgement that obscures the Action Layer.

See [`PRODUCT_PRINCIPLES.md` §3 and §9](PRODUCT_PRINCIPLES.md).

---

## Visual Principles

### Content first

Preserved evidence previews and artifact cards are the heroes. Chrome, decoration, and branding recede. If a visual treatment competes with evidence, remove the treatment. See [Interaction Philosophy](#interaction-philosophy).

### Calm hierarchy

One primary focal point per screen region. Headings guide; they do not shout. Related information groups visually. Unrelated information separates with space, not walls of borders.

### Trust through consistency

The same component should look and behave the same everywhere. Predictability builds confidence. Surprises erode trust — especially around integrity, verification, and sharing.

### Generous whitespace

Space is not empty. It creates breathing room, reduces anxiety, and signals that the product respects the weight of what is being documented. Prefer space over compression.

### Progressive disclosure

Show what is needed now. Reveal depth when the user seeks it. The Workspace unfolds capture first; View Story and Trust Package unfold understanding and sharing — never all at once on one screen.

### Minimal cognitive load

Every label, tap, and transition should answer an obvious question. If the user must interpret the interface, simplify the interface.

---

## Layout System

Evidence Vault uses a fixed spacing scale. All margins, padding, and gaps should derive from this scale — never arbitrary values.

| Token | Value | Intended use |
|---|---|---|
| **xxs** | 4 | Tight internal gaps: icon-to-label, badge padding, stacked caption lines |
| **xs** | 8 | Compact row spacing, inline element separation, small list gaps |
| **sm** | 12 | Related content within a group, card internal sections, form field spacing |
| **md** | 16 | Standard padding inside cards, spacing between label and value, list item gaps |
| **lg** | 24 | Section padding, screen horizontal margins, space between related blocks |
| **xl** | 32 | Major section separation, space below screen titles |
| **xxl** | 48 | Large vertical rhythm breaks, hero spacing, empty-state breathing room |
| **xxxl** | 64 | Rare: splash moments, onboarding emphasis, full-screen empty states |

### Usage rules

- **Inside components:** prefer xs–md
- **Between components in a section:** prefer md–lg
- **Between major sections:** prefer xl–xxl
- **Screen edges:** use lg (24) as the default horizontal margin on phones

When in doubt, add space. Compression signals cheapness; space signals care.

---

## Grid & Alignment

### Horizontal margins

Content on phone screens aligns to consistent left and right margins. Edge-to-edge content is reserved for previews (photos, timelines) where immersion serves understanding — never for dense forms or reading text.

### Vertical rhythm

Sections stack with predictable spacing. A screen should read top-to-bottom with a clear rhythm: header → primary content → secondary content → persistent action layer.

### Section spacing

Major sections (Library of Truth, Incident Journey, Evidence Map, Timeline, Reflection) separate with xl or greater. Subsections within a card use sm–md.

### Card spacing

Cards never touch edge-to-edge without margin. Nested cards use tighter internal padding (md) than outer containers (lg).

### Sticky Capture Layer alignment

The Home Capture Layer and Workspace Action Layer align to the same horizontal margins as scrollable content above. Sticky layers use a solid background so content scrolls beneath without visual bleed. Height is measured dynamically — never hard-coded per device in design specs.

---

## Typography

Typography communicates hierarchy through weight, size, and color — not decoration. The type system should remain readable under stress, in bright light, and with system font scaling enabled.

| Role | Weight | Intended use |
|---|---|---|
| **Display** | Bold | Rare hero moments: splash, major onboarding |
| **Page Title** | Bold / Heavy | Top-level screen identity: Home, Vault, Profile |
| **Screen Title** | Bold | Secondary screens: Evidence Record, Story, Review Package |
| **Section Title** | Semibold | Card headers, major content blocks, Library sections |
| **Body** | Regular | Primary reading text, explanations, story narrative |
| **Label** | Medium | Field names, row headers, button text, evidence type names |
| **Caption** | Regular | Timestamps, metadata, secondary hints, section captions |
| **Metadata** | Regular, muted | Integrity rows, verification details, source attribution |
| **Helper Text** | Regular, muted | Form guidance, empty-state education, inline reassurance |

### Typography rules

- **One page title per screen.** Do not stack competing headings.
- **Body text uses comfortable line height** (approximately 1.5–1.7) for reading-heavy surfaces: Story, Trust Package, Reflection.
- **Navy carries authority** for headings and labels. Grey carries supporting information.
- **Never use typography alone to imply judgment.** Status is stated plainly; it is not shouted.
- **Respect system text scaling.** Layouts must not break when users enlarge text.

---

## Color Philosophy

Color in Evidence Vault communicates trust — not excitement. Restraint is a feature.

### Palette roles

| Role | Purpose |
|---|---|
| **Primary (Blue)** | Trust, action, links, active journey stages, key affordances |
| **Navy** | Authority, headings, primary text, navigation chrome |
| **Success (Green)** | Integrity Verified, Verified, positive observational insights |
| **Warning (Amber)** | Caution without alarm; use sparingly |
| **Error (Red)** | True errors only — never for empty states or missing optional content |
| **Background (White)** | Primary canvas; calm, clean, readable |
| **Surface (Soft grey-blue)** | Cards, grouped content, subtle elevation |
| **Surface Muted** | Nested content, context blocks, insight backgrounds |
| **Border / Divider** | Structure without heaviness; low-contrast separation |

### Color rules

- **Blue communicates trust.** Use it for actions the user should feel confident taking.
- **Grey communicates structure.** Metadata, captions, and inactive states live here.
- **Green confirms preservation states** — integrity and verification — never celebration.
- **Avoid decorative color.** No gradients for decoration. No rainbow status systems.
- **Do not color-code incidents** by severity, risk, or inferred meaning.
- **Muted always beats loud.** If a state can be shown with text and spacing, do not add color.

---

## Elevation & Surfaces

Surfaces create depth without drama. Evidence Vault is not a material-design showcase.

| Surface | Use |
|---|---|
| **Background** | Screen canvas |
| **Card** | Grouped content: Library sections, workspace cards, insight cards |
| **Surface Muted** | Nested rows, context items, secondary blocks |
| **Sheet** | Bottom sheets: Add Context, Link Evidence, Reflection editor |
| **Dialog** | Confirmations and focused decisions — rare |
| **Sticky Layer** | Capture Layer (Home), Action Layer (Workspace), Add Context bar (Evidence Record) |

### Shadow rules

- Shadows are **subtle and soft** — suggest lift, not float
- Cards use layered low-opacity shadows, never harsh drop shadows
- Sticky layers use flat background fills, not shadow stacks
- Elevated buttons use a restrained primary-tinted shadow — only on primary actions

---

## Border Radius

One radius scale. No arbitrary corner values.

| Token | Intended use |
|---|---|
| **sm (~8–12)** | Thumbnails, small chips, badges |
| **md (~16–18)** | Input fields, inner rows, artifact cards, buttons |
| **lg (~24–28)** | Outer cards, Library containers, major sections |
| **full** | Circular icons, avatar placeholders, play buttons |

Nested elements use equal or smaller radius than their parent. A small row inside a large card should not have larger corners than the card itself.

---

## Buttons

Buttons express hierarchy through weight, fill, and placement — not quantity.

| Type | Use |
|---|---|
| **Primary** | One dominant action per context: Capture, Resume, Preserve |
| **Secondary (Outlined)** | Supporting actions: View Story, Prepare Trust Package |
| **Text** | Tertiary navigation: View Evidence Map, inline links |
| **Destructive** | Irreversible actions only — rare in Evidence Vault |
| **Disabled** | Reduced contrast; clearly non-interactive; never hidden without explanation |
| **Loading** | Replace label with calm progress; preserve button dimensions |

### Button rules

- **One primary action per sticky layer or modal**
- **Full-width primary buttons** on mobile for main workspace actions
- **Outlined buttons** for reading and review flows that should not compete with capture
- **Minimum height** supports comfortable touch (approximately 48–58pt)
- **Never use buttons for static information**

---

## Icons

Icons clarify meaning. They never replace essential text.

| Size | Use |
|---|---|
| **Small (16–18)** | Inline with labels: integrity check, verification badge |
| **Medium (20–24)** | Buttons, list rows, navigation |
| **Large (32–72)** | Empty states, evidence type thumbnails, preview placeholders |

### Icon rules

- **Icons accompany labels** on primary actions — especially Capture modes
- **Semantic consistency:** same icon for same concept across the app
- **Muted icons** for inactive or future stages; primary tint for active states
- **Do not use icons as decoration** in reading surfaces (Story, Trust Package)

---

## Cards

Cards are the primary unit of grouped information. Each card type has a canonical structure.

### Evidence Artifact Card

Thumbnail + type label + preserved timestamp + integrity row + context row. Optional subtle badges (verification, relationships) — used with restraint. Tappable to open Evidence Record.

### Evidence Record Section

Workspace card with section header, structured rows (label + value), read-only content. Four pillars: Evidence, Integrity, Context, Metadata — plus Linked Evidence below. Item-level integrity appears here; incident-level Trust Status appears in View Story.

### Context Card

Muted surface, context type label, preview text, timestamp. Grouped under parent evidence where possible.

### Linked Evidence Card

Relationship type, target evidence summary, preserved timestamp. Source attribution when shown in Story or Trust Package.

### Insight Card

Title + explanation. Informational tone. No alarm colors. Optional suggested action in primary text — never demanding.

### Library Insight Card

"Observed" label + factual cross-incident pattern. No ranking, no urgency.

### Trust Package / Story Section

Section title + optional caption + reading content. Dividers between major sections. No editing affordances.

### Reflection Card

Softer treatment than evidence. Title (optional) + body verbatim + timestamp. Never summarized.

### Timeline Card

Chronological node with connector line. Event type, timestamp, tap to source evidence.

### Card rules

- **One purpose per card** — do not combine unrelated sections to save space
- **Headers use Section Title typography**
- **Captions educate** — one line beneath headers where helpful
- **Omit empty sections gracefully** — never show blank card shells

---

## Empty States

Every empty state educates. Never show "No data" or a blank screen.

Each empty state includes:

1. **Title** — what this area becomes (e.g., "The Library of Truth")
2. **Short reassurance** — why it exists and that beginning is valid
3. **Primary action** — the natural next step (usually Capture)

Empty states use illustration sparingly — aspirational preview, not cartoon decoration. Tone is inviting, never accusatory.

---

## Status Indicators

`StatusBadge` (`lib/widgets/common/status_badge.dart`) is the **single source of truth** for incident state indicators across Home, Organize, Investigation, Vault, and Trust Package.

Do not invent ad-hoc status chips, coloured status labels, or Material `Chip`s for incident readiness. Use:

```dart
StatusBadge(
  status: IncidentStatus.building,
)
```

### Official statuses

| Status | Label | Palette |
|---|---|---|
| `building` | BUILDING | Soft amber fill, amber border/dot, dark amber text |
| `needsReview` | NEEDS REVIEW | Soft gold fill, golden-brown border, gold dot, golden-brown text |
| `ready` | READY | Soft emerald fill, emerald border/dot, dark green text |
| `incomplete` | INCOMPLETE | Soft red fill, red border/dot, deep red text |
| `archived` | ARCHIVED | Neutral slate (reserved) |
| `exported` | EXPORTED | Neutral slate (reserved) |
| `verified` | VERIFIED | Neutral slate (reserved) |

Only the first four have dedicated premium colour systems today. Future statuses render a calm neutral badge until palettes are added — the enum itself does not need structural changes.

### Visual specification

- Rounded rectangle, border radius **10–12** (canonical: `11`)
- Thin **1px** border
- Soft vertical gradient with a light inner highlight on the top edge
- Compact vertical padding; balanced horizontal padding
- Semi-bold, uppercase label with slightly increased letter spacing
- Small solid status colour dot on the left
- No heavy shadows; no cartoon styling; not a Material Chip

### Mapping helpers

- `IncidentStatus.resolve(journeyStage:, health:)` — preferred for live workspace surfaces
- `IncidentStatus.fromJourneyStage(...)`
- `IncidentStatus.fromReconstructionHealth(...)`
- `IncidentStatus.tryParse(...)` — legacy display strings (e.g. Trust Package cover)

### Naming note

Design-system `IncidentStatus` (badge readiness) is distinct from domain lifecycle `IncidentStatus` in `lib/domain/incident/incident_status.dart` (`draft` / `active` / …). If both are needed in one file, import the badge library with a prefix.

---

## Loading States

Loading should feel calm and honest.

- **Prefer skeleton placeholders** that match final layout shape
- **Avoid full-screen spinners** except during initial authentication or cold start
- **Preserve layout stability** — content should not jump when data arrives
- **Never block capture** with loading states longer than necessary

If something takes time, explain what is happening in plain language — never technical jargon.

---

## Motion Principles

Animation serves orientation, not entertainment.

| Principle | Meaning |
|---|---|
| **Subtle** | Small transitions; no bounce or elastic excess |
| **Predictable** | Same navigation direction, same duration family |
| **Fast** | Approximately 200–300ms for UI feedback; longer only for meaningful state change |
| **Purposeful** | Motion explains spatial relationships or confirms an action |

Never animate for decoration. Never use motion to create false urgency. Respect reduced-motion preferences.

---

## Accessibility

An accessible Evidence Vault is a more trustworthy Evidence Vault.

| Requirement | Standard |
|---|---|
| **Touch targets** | Minimum 44×44pt interactive area |
| **Contrast** | Body text and labels meet WCAG AA against their background |
| **Dynamic text** | Layouts reflow; no clipped text at large system font sizes |
| **Screen readers** | Meaningful labels on all actions; status changes announced |
| **Focus order** | Logical top-to-bottom, action-before-content in sticky layers |
| **Color independence** | Never rely on color alone for status — pair with text or icon |
| **Motion** | Honor system reduced-motion settings |

Accessibility is not a polish pass. It is part of trust.

---

## Responsive Behaviour

Evidence Vault is mobile-first. Primary reference device: standard Android phone (approximately 6.5" display).

| Context | Behaviour |
|---|---|
| **Small phones** | Maintain horizontal margins; reduce non-essential chrome; sticky layers stay reachable |
| **Large phones** | Same layout patterns; avoid stretching cards to absurd width — content stays readable |
| **Tablets** | Increase margins; optional two-column for Library browsing — future sprint |
| **Landscape** | Preserve sticky capture/action layers; scrollable content adapts; no loss of primary actions |

Layouts use flexible constraints — not fixed pixel frames. Reading surfaces cap line length for comfort where possible.

---

## Design Rules

Before shipping any new screen, answer:

- **Does this feel calm?**
- **Does this reduce cognitive load?**
- **Is this visually consistent with existing surfaces?**
- **Does this strengthen trust in preserved evidence?**

If any answer is no, redesign before implementation.

When introducing a new component, ask:

- Can an existing card or section be extended?
- Does it use the spacing scale, type roles, and color roles defined here?
- Does copy follow `LANGUAGE_SYSTEM.md`?

Default to restraint. The best interface change is often the one not made.

---

## Relationship to Other Documents

This Design System implements the philosophy defined elsewhere. It does not replace those documents — it translates them into visual and interaction rules.

| Document | Relationship |
|---|---|
| **[PRODUCT_PRINCIPLES.md](PRODUCT_PRINCIPLES.md)** | Product constitution — vision, mission, identity, philosophy, and interaction constraints |
| **[LANGUAGE_SYSTEM.md](docs/LANGUAGE_SYSTEM.md)** | Words the interface may use; design must present language consistently |
| **[UX_ARCHITECTURE.md](docs/UX_ARCHITECTURE.md)** | Screen structure, journeys, and progressive disclosure that this system visualizes |
| **[PLATFORM_ARCHITECTURE.md](docs/PLATFORM_ARCHITECTURE.md)** | Platform modules and data model that UX and design express |

When documents conflict, resolve in this order:

1. Product Principles (constitution)
2. Platform Architecture (structure)
3. UX Architecture (experience)
4. Language System (copy)
5. Design System (visual execution)

---

## Evolution

This document should evolve slowly. Changes require clear justification — a new platform, a new surface type, or a proven inconsistency that harms trust.

Version updates should note what changed and why. Arbitrary trend-chasing does not belong here.

The goal is permanence: a design language that still feels right years from now, when Evidence Vault holds records that matter for years to come.

---

*This document is the permanent visual and interaction reference for Evidence Vault. All screens, components, and interactions must conform to these principles before new patterns are introduced.*
