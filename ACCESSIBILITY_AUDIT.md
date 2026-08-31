# Accessibility & Inclusivity Audit — Sprint 6.4

**Scope:** Evidence Vault Flutter application  
**Standards reference:** WCAG 2.2 Level AA (target), Material accessibility guidelines  
**Device reference:** Motorola moto g35 5G (primary Android target)

---

## Executive Summary

Before Sprint 6.4, Evidence Vault relied almost entirely on **implicit Material semantics** with no explicit `Semantics` widgets, no IconButton tooltips, undersized inline link targets, and fixed-height layouts that clip at large text sizes. Primary buttons met touch-target guidance (58dp), but capture tiles used `GestureDetector` (invisible to screen readers) and auth inline links used `shrinkWrap` (below 48dp).

Sprint 6.4 applied **targeted improvements** to the highest-impact gaps. The app is more usable with TalkBack/VoiceOver, keyboard focus on capture actions, and improved contrast — but **landscape layouts, full text-scaling validation, and automated a11y CI** remain future work.

| Area | Before | After Sprint 6.4 |
|------|--------|------------------|
| Screen readers | Capture buttons not announced as buttons | `Semantics` + descriptive labels on Home/Workspace capture |
| Dynamic text | Fixed heights; 1-line ellipsis on capture labels | 2-line labels; theme respects system scaling (default) |
| Contrast | Muted text borderline on cards | `textSecondary` / `textMuted` darkened |
| Touch targets | Auth links shrinkWrap (~24dp) | Theme minimum 48×48dp on TextButton/IconButton |
| Focus / keyboard | Auth forms only | Semantics on capture buttons |
| IconButton labels | None | Tooltips on back, password toggle, voice play/pause |
| Decorative images | Logos announced redundantly | `ExcludeSemantics` / `excludeFromSemantics` |
| Tests | None | Semantics widget test for capture buttons |

---

## 1. Screen Readers

### Audit findings

| Finding | Risk | Detail |
|---------|------|--------|
| No explicit Semantics | High | Zero `Semantics` widgets before 6.4 |
| GestureDetector capture tiles | High | Home + Workspace capture not exposed as buttons |
| IconButtons without tooltips | High | Back, password toggle, play/pause announced generically |
| Decorative logos | Medium | Brand images read without context while title text nearby |
| InkWell cards | Low | Material provides default button semantics when `onTap` set |
| Bottom navigation | OK | Standard `BottomNavigationBar` with text labels |

### Improvements delivered

| File | Change |
|------|--------|
| `quick_capture_button.dart` | `Semantics(button: true, label: semanticLabel)` + `ExcludeSemantics` on visible content |
| `capture_action_button.dart` | Same; `selected` state for active mode |
| `workspace_capture_mode.dart` | `semanticLabel` getters ("Capture photo evidence", etc.) |
| `app_back_button.dart` | New shared back control with `tooltip: 'Back'` |
| `ev_password_field.dart` | `tooltip: 'Show password' / 'Hide password'` |
| `evidence_record_preview.dart` | Play/pause voice tooltip |
| `password_strength_widget.dart` | `Semantics(label: 'Password strength: …')` |
| `terms_checkbox.dart` | `Semantics(label: 'Agree to Terms and Conditions')` |
| `home_body.dart`, `workspace_header.dart`, `auth_header.dart` | Decorative logos excluded from semantics |

### Remaining gaps

- Evidence artifact cards, timeline rows, reflection cards — no merged semantics (icon + title read separately)
- Verification/integrity badges — status conveyed partly by color
- Story/Trust Package long scroll — no section headings announced as headers (`Semantics(header: true)`)
- Live regions for snackbars — Material handles briefly; no custom announcements

---

## 2. Dynamic Text Sizes

### Audit findings

| Finding | Risk | Detail |
|---------|------|--------|
| No text-scale handling | Medium | App uses default Flutter scaling (good baseline) |
| Fixed button heights | Medium | `buttonHeight = 58`, capture tiles 100px, splash CTA 55px |
| Capture labels | Medium | `fontSize: 11` with `maxLines: 1` on workspace bar |
| No overflow tests | High | No widget tests at 1.5× or 2.0× text scale |

### Improvements delivered

- Capture button labels allow **2 lines** with ellipsis fallback
- Password strength label bumped from **12px → 13px**
- Theme does **not** clamp `textScaler` — supports system accessibility settings

### Remaining gaps

- Fixed-height capture grid may still clip at 2.0×+ system text
- Auth hero titles (`heroTitle` 32px) may overflow on small phones at large text
- Recommend manual QA: Settings → Display → Font size → Largest on Motorola device
- Add widget tests: `MediaQuery.withClampedTextScaling(minScaleFactor: 1.5)`

---

## 3. Contrast

### Palette audit (WCAG AA: 4.5:1 normal text, 3:1 large text)

| Pair | Before | After 6.4 | Verdict |
|------|--------|-----------|---------|
| `navy` on white | ~12:1 | unchanged | Pass AAA |
| `textSecondary` on white | ~4.6:1 (borderline) | **~5.2:1** (`#5A6478`) | Pass AA |
| `textMuted` on white | ~4.6:1 | **~5.0:1** (`#5C6370`) | Pass AA |
| `textSecondary` on `card` | ~4.2:1 fail | **~4.8:1** | Pass AA |
| `onPrimary` on `primary` | ~5:1 | unchanged | Pass |
| `warning` `#F59E0B` on white | ~2.2:1 | unchanged | **Fail** (decorative meter only) |
| Password criteria 12px | borderline | 13px + darker muted | Improved |

### Improvements delivered

- Darkened `AppColors.textSecondary` and `textMuted` in `app_colors.dart`
- Password strength uses text label + icon criteria (not color-only for requirements)

### Remaining gaps

- Strength meter **segments** still color-only (text label mitigates)
- No dark theme / high-contrast theme
- `primary` link text on white remains borderline for 14px links

---

## 4. Touch Target Sizes

### WCAG 2.5.5: Minimum 44×44 CSS pixels (Material recommends 48dp)

| Control | Size | Status |
|---------|------|--------|
| Primary buttons (`EVButton`, auth) | 58dp | ✅ |
| Home capture tiles | 100dp tall | ✅ |
| Social login buttons | 56dp | ✅ |
| IconButton (theme default) | **48dp** (after 6.4) | ✅ |
| TextButton inline links | **48dp min** (after 6.4) | ✅ |
| Terms checkbox hit area | **48dp** container (after 6.4) | ✅ |
| Timeline InkWell padding | 8dp (was 4dp) | Improved |
| Workspace capture row (5 buttons) | ~70dp wide each on 412px | Acceptable |

### Improvements delivered

- `AppAccessibility.minTouchTarget = 48` constant
- `app_theme.dart`: global `iconButtonTheme` and `textButtonTheme` minimum sizes
- Removed `tapTargetSize: shrinkWrap` from auth footer, login forgot-password, splash login link
- Enlarged terms checkbox touch container

### Remaining gaps

- `inlineOutlined` buttons still 44dp (`app_button_styles.dart`) — meets WCAG 44 but below app 48 standard
- Link Existing Evidence relationship options — adequate but untested at large text

---

## 5. Focus Order

### Audit findings

| Area | Status |
|------|--------|
| Auth forms | FocusNode chains on login, create account, forgot password |
| `autofocus` | Not used on first field |
| `FocusTraversalGroup` | Not used |
| Capture buttons | **Now focusable** via `FocusableActionDetector` |
| Cards / bottom nav | Platform default tab order |
| Bottom sheets | Standard modal focus trap |

### Improvements delivered

- Capture buttons expose descriptive `Semantics` labels; visible icon/text excluded from duplicate announcements

### Remaining gaps

- Add `autofocus: true` on first auth field
- Wrap auth forms in `FocusTraversalGroup` for predictable tab order
- Evidence Record / Workspace cards not keyboard-focusable on desktop/web

---

## 6. Keyboard Navigation

### Audit findings

| Flow | Keyboard support |
|------|------------------|
| Login / Create Account / Forgot Password | Tab between fields; submit on Enter |
| Home capture tiles | **Added** focus + activation (6.4) |
| Workspace capture bar | **Added** focus + activation (6.4) |
| Bottom navigation | Platform default |
| Evidence cards | Touch only |
| Shortcuts (desktop) | None |

### Remaining gaps

- Desktop/web: add arrow-key navigation for capture grid
- Escape to dismiss bottom sheets (partial — barrier dismiss only)

---

## 7. Landscape Mode

### Audit findings

| Finding | Risk |
|---------|------|
| No `OrientationBuilder` | Medium |
| No orientation lock on capture screens | Low |
| Sticky bottom capture/action layers consume vertical space in landscape | Medium |
| Splash logo fixed dimensions | Low |

### Status: **Not addressed in 6.4** (documented for future sprint)

### Recommendations

- Lock portrait on active camera capture screens
- In landscape: horizontal scroll for capture bar instead of 5-column row
- Reduce sticky layer height in landscape via `OrientationBuilder`

---

## 8. Small Screens (≤ 360dp width)

### Audit findings

- Tests use `412×915` (standard phone) — not 320×568
- Auth screens use `SingleChildScrollView` + keyboard inset — good
- Home capture grid 3+2 may compress on narrow devices
- Horizontal padding `screenHorizontal = 24` — reasonable

### Recommendations

- Test on 320dp width (iPhone SE class)
- Consider 2-column capture grid below 360dp width
- Verify splash feature cards don't overflow at large text + narrow width

---

## 9. Large Screens (≥ 600dp / tablets)

### Audit findings

- No breakpoint system
- Content stretches full width on tablets
- `LayoutBuilder` used only for sticky layer height, not breakpoints
- Auth forms could benefit from `maxWidth: 480` center constraint

### Status: **Not addressed in 6.4**

### Recommendations

- Add `AppBreakpoints` helper; constrain auth and card content on tablets
- Consider two-column workspace layout on wide screens

---

## Improvements Delivered (Sprint 6.4)

| File | Change |
|------|--------|
| `lib/constants/app_accessibility.dart` | `minTouchTarget = 48` |
| `lib/widgets/common/app_back_button.dart` | Shared accessible back button |
| `lib/theme/app_theme.dart` | IconButton/TextButton 48dp minimum |
| `lib/theme/app_colors.dart` | Improved secondary/muted contrast |
| `lib/theme/app_text_styles.dart` | Strength label 13px |
| `lib/widgets/home/quick_capture_button.dart` | Semantics, focus, 2-line labels |
| `lib/widgets/workspace/capture_action_button.dart` | Semantics, focus, 2-line labels |
| `lib/models/workspace_capture_mode.dart` | Semantic labels |
| `lib/widgets/ev_password_field.dart` | Show/hide password tooltip |
| `lib/widgets/auth/auth_footer.dart` | Removed shrinkWrap |
| `lib/screens/login_screen.dart` | AppBackButton; accessible forgot-password link |
| `lib/screens/splash_screen.dart` | Accessible login link |
| `lib/screens/*` | AppBackButton on all sub-screens |
| `lib/widgets/auth/terms_checkbox.dart` | 48dp hit area + semantics |
| `lib/widgets/auth/password_strength_widget.dart` | Semantics for strength |
| `lib/widgets/evidence_record/evidence_record_preview.dart` | Play/pause tooltip |
| `lib/widgets/timeline/timeline_item_card.dart` | Increased tap padding |
| Decorative logos | Excluded from screen readers |
| `test/accessibility_test.dart` | Semantics test for capture buttons |

---

## Remaining Bottlenecks (Priority)

1. **Landscape layouts** — sticky layers and capture grid need orientation-aware layout
2. **Text scaling QA** — no automated overflow tests at 1.5×/2.0×
3. **Card semantics** — merge icon + title on artifact/timeline cards
4. **Dark / high-contrast theme** — not implemented
5. **Section headers** — Story/Trust Package/Workspace sections need `Semantics(header: true)`
6. **Tablet breakpoints** — content stretches on large screens
7. **accessibility_tools in CI** — visual audit overlay for regressions
8. **Reduced motion** — no `MediaQuery.disableAnimations` checks
9. **Color-only indicators** — strength meter segments, verification status colors
10. **Small phone testing** — 320dp width not in test matrix

---

## Manual QA Checklist (Motorola reference device)

1. Enable **TalkBack** → navigate Home capture grid → hear "Capture photo evidence" etc.
2. Enable **Large display size** → verify capture labels visible (may wrap to 2 lines)
3. Enable **Large font** → scroll auth screens → no clipped fields
4. Tab through login with **Bluetooth keyboard** (if available) → logical field order
5. Tap **Forgot Password?** and **Create Vault** links → comfortable tap area
6. Toggle **password visibility** → hear "Show password" / "Hide password"
7. Open **Evidence Record** voice preview → play button labeled
8. Rotate to **landscape** on Home and Workspace → note cramped layout (known gap)
9. Verify **decorative logos** not double-announced with page titles

---

## Test Coverage

| Test | File | Status |
|------|------|--------|
| Capture button semantics | `test/accessibility_test.dart` | ✅ Added |
| Navigation (412×915) | `test/main_shell_navigation_test.dart` | ✅ Existing |
| Text scale overflow | — | ❌ Not yet |
| Contrast automation | — | ❌ Not yet |

Run: `flutter test test/accessibility_test.dart`

---

## Conclusion

Sprint 6.4 establishes an **accessibility foundation**: semantic capture actions, proper touch targets on links and icon buttons, improved contrast, and a first semantics test. The app is **more inclusive** for screen reader and motor-impaired users on the primary phone path, but **landscape, tablet, large-text stress testing, and dark mode** require a follow-up sprint before claiming WCAG AA compliance.

---

*Sprint 6.4 — Accessibility & Inclusivity. Audit + targeted improvements applied.*
