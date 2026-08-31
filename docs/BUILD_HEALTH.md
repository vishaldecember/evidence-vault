# Build Health Checklist

Engineering Integrity

A healthy development environment is to engineering what preserved evidence is to the product: a trustworthy foundation. We verify the environment before changing it, and we stabilize before we optimize.

**Document:** Daily engineering health procedure  
**Companion to:** [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md)  
**Estimated time:** Five minutes or less

---

## Purpose

Evidence Vault values engineering reliability as much as evidence integrity.

A stable development environment allows engineering effort to be spent on building the product rather than recovering it. This checklist verifies that the current machine, toolchain, device, and project state match the approved engineering baseline before any sprint work begins.

**This document does not replace [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md).** The baseline records what the environment *is*. Build Health confirms the environment *still matches* that baseline today.

If a check fails, consult the baseline for version expectations and recovery procedures. Do not begin implementation until build health is restored.

---

## Reference

All version numbers, SDK levels, dependency locks, and recovery sequences are defined in [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md).

Build Health verifies the live environment against that document — not against the latest available tooling on the internet.

---

## Daily Build Health Checklist

Complete every section before starting a sprint. Mark each item as you go.

### 1. Machine Health

Verify the workstation is ready for development.

- [ ] At least **20 GB free** on the system drive (`C:\`)
- [ ] Laptop connected to **power** (recommended)
- [ ] **Stable internet connection** available
- [ ] **No pending Windows restart** required

---

### 2. Development Environment

Verify the Flutter and Android toolchain is healthy.

- [ ] Flutter installed at the path recorded in the baseline (`C:\Development\flutter`)
- [ ] `flutter doctor` reports **no critical issues** for Android development
- [ ] Environment matches [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md):
  - Flutter **3.44.6** (stable)
  - Dart **3.12.2**
  - Android SDK **36.0.0**
  - Java **OpenJDK 21.0.10** (Android Studio JBR)

**Quick command:**

```bash
flutter doctor -v
```

Acceptable warnings (non-blocking): Visual Studio not installed, KGP plugin notices, package update notifications. See the baseline for the full list.

---

### 3. Device Health

Verify the primary development device is connected.

- [ ] **Motorola moto g35 5G** connected via USB
- [ ] **USB debugging** enabled and authorized on the device
- [ ] Device appears in device list:

```bash
flutter devices
```

Expected entry: `moto g35 5G` · device ID `ZA222V9Y3V` · `android-arm64`

If the device is missing, see [Common Symptoms](#common-symptoms) before proceeding.

---

### 4. Project Health

Verify the repository is in a clean, expected state.

- [ ] Repository opens successfully at `C:\Development\evidence_vault`
- [ ] **Correct branch** checked out for the current sprint
- [ ] `flutter pub get` completes successfully
- [ ] **No unexpected dependency changes** in `pubspec.lock` (review `git status` and `git diff`)

**Quick commands:**

```bash
git status
flutter pub get
```

---

### 5. Build Health

Verify the application still compiles and runs. **Complete one of the following — not both every day.**

- [ ] `flutter build apk --debug` completes successfully

**OR**

- [ ] `flutter run` launches successfully on the Motorola device

**Quick commands:**

```bash
flutter build apk --debug
```

```bash
flutter run -d ZA222V9Y3V
```

**Note:** First Gradle build after a clean or cache clear may exceed five minutes. Allow reasonable time, but stop and investigate if there is no progress for approximately **10 minutes**.

---

### 6. Engineering Readiness

Confirm the sprint is understood before writing code.

- [ ] **Sprint objective** understood
- [ ] Relevant architecture documents reviewed for this sprint

Review only what applies. Common references:

| Document | When to review |
|---|---|
| [`PRODUCT_PRINCIPLES.md`](../PRODUCT_PRINCIPLES.md) | Product constitution — vision, mission, identity, feature decisions, and trade-offs |
| [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) | Navigation, screens, or interaction changes |
| [`LANGUAGE_SYSTEM.md`](LANGUAGE_SYSTEM.md) | User-facing copy, labels, or notifications |

---

## Engineering Rules

Permanent practices for every sprint:

1. **Build from the integrated terminal.** Do not rely on automated agents to run long-lived shell processes.
2. **Use Cursor Agent for implementation and documentation only.** Environment verification and device testing are manual.
3. **Do not allow long-running shell tasks to block development.** Set explicit timeouts; stop hung processes and investigate.
4. **Stop and investigate builds that show no progress for approximately 10 minutes.**
5. **Avoid upgrading dependencies during feature development.** Dependency changes require a dedicated sprint and baseline update.
6. **Keep the development environment stable.** Match the baseline; do not chase latest versions mid-sprint.

---

## Common Symptoms

Quick reference for the most frequent pre-sprint blockers. For full recovery sequences, see [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md) → Recovery Procedures.

| Symptom | Likely Cause | First Action |
|---|---|---|
| Gradle hangs with no output | First build, slow download, or stuck daemon | Wait briefly; then stop process and retry. Kill orphaned `java.exe` if needed. |
| Device missing from `flutter devices` | USB disconnected, debugging off, or unauthorized | Reconnect cable; confirm USB debugging prompt on device; run `flutter devices --device-timeout 30`. |
| Low disk space warnings | Insufficient free space on `C:\` | Free space to at least 20 GB; run `flutter clean` if needed. |
| Flutter lock / hung process | Stale `dart.exe` or `gradle.exe` from prior session | Stop terminal process; end orphaned processes; retry command. |
| Build cache issue | Stale artifacts after branch switch | Run `flutter clean`, then `flutter pub get`, then rebuild. |
| Package resolution failure | Corrupted `.dart_tool` or lock mismatch | Run `flutter pub get`; review `git diff pubspec.lock` for unexpected changes. |
| KGP plugin warnings | Known plugin compatibility notices | Continue if build succeeds. Documented as acceptable in the baseline. |
| `flutter doctor` Android failure | SDK path, licenses, or JDK misconfiguration | Compare output against baseline; re-run `flutter doctor --android-licenses` if needed. |

---

## Build Complete

Once the application **launches successfully on the Motorola device**, engineering may proceed with implementation.

If build health cannot be restored within a reasonable effort, stop feature work and resolve the environment first. Recovering the baseline is always higher priority than advancing a sprint on an unstable machine.

---

*This checklist complements [`DEVELOPMENT_BASELINE.md`](DEVELOPMENT_BASELINE.md). Update this document only when the daily procedure itself changes — not when toolchain versions change (update the baseline instead).*
