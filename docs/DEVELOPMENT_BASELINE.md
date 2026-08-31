# Engineering Baseline v1.0

This document may only be updated after a verified successful build on the primary development environment.

**Date established:** 29 July 2026  
**Purpose:** Permanent engineering baseline for Evidence Vault. This document is the single source of truth for the development environment currently known to build, test, and run the application. Values were captured by automated inspection of the development machine, Flutter toolchain, Android toolchain, and project configuration files. Where a value could not be determined automatically, it is marked **To be confirmed.**

---

## Platform

| Property | Value |
|---|---|
| Operating System | Microsoft Windows 11 Pro (Build 21996) |
| CPU architecture | x64-based PC |
| Development machine | Hewlett-Packard workstation (BIOS: HP M74 Ver. 01.54) |
| Project root | `C:\Development\evidence_vault` |
| Locale | en-US |

---

## Flutter Environment

| Property | Value |
|---|---|
| Flutter version | 3.44.6 |
| Dart version | 3.12.2 |
| Flutter channel | stable |
| Framework revision | `ee80f08bbf` (2026-07-08) |
| Engine revision | `83675ed276` |
| Engine hash | `d3a3293399556a85388faf8c6f0723a7a5597aa8` |
| DevTools version | 2.57.0 |
| Flutter SDK path | `C:\Development\flutter` |
| Upstream repository | https://github.com/flutter/flutter.git |

---

## Android Environment

| Property | Value |
|---|---|
| Android SDK path | `C:\Users\HP\AppData\Local\Android\sdk` |
| Android SDK version (doctor) | 36.0.0 |
| Platform installed | android-36.1 (also: android-34, android-35, android-36) |
| Build Tools version | 36.0.0 |
| Android Studio | 2026.1.2 (build `AI-261.25134.95.2612.15822958`) |
| Android Studio JBR path | `C:\Program Files\Android\Android Studio\jbr` |
| Java version | OpenJDK 21.0.10 (JetBrains Runtime, build `21.0.10+-14961533-b1163.108`) |
| Gradle version | 9.1.0 |
| Android Gradle Plugin (AGP) | 9.0.1 |
| Kotlin version | 2.3.20 |
| Android licenses | All accepted |
| Emulator version | 36.6.11.0 (build_id 15507667) |

**Note:** `java` is not on the system PATH. Flutter uses the Android Studio bundled JDK configured at `C:\Program Files\Android\Android Studio\jbr\bin\java`.

---

## Project Baseline

Values are inherited from Flutter defaults via `flutter.compileSdkVersion`, `flutter.minSdkVersion`, `flutter.targetSdkVersion`, and `flutter.ndkVersion` in `android/app/build.gradle.kts`, as defined in Flutter 3.44.6 (`FlutterExtension.kt` / `gradle_utils.dart`).

| Property | Value |
|---|---|
| compileSdk | 36 |
| targetSdk | 36 |
| minSdk | 24 |
| NDK version | 28.2.13676358 |
| Java compatibility (app) | 17 (source/target) |
| Kotlin JVM target | 17 |
| Application ID | `com.example.evidence_vault` |
| App version | 1.0.0+1 |
| Dart SDK constraint | ^3.12.2 |

Plugin subprojects override `compileSdk` to 36 in `android/build.gradle.kts`.

---

## Core Dependencies

Locked versions from `pubspec.lock` at baseline capture. Only architecturally important packages are listed.

### Evidence capture and media

| Package | Locked version | Role |
|---|---|---|
| camera | 0.11.4 | Photo and video capture |
| record | 6.2.1 | Audio recording |
| video_player | 2.13.0 | Video playback |
| audioplayers | 6.8.1 | Audio playback |
| image_picker | 1.2.3 | Gallery and camera picker |
| file_picker | 8.3.7 | Document import |

### Storage, permissions, and platform

| Package | Locked version | Role |
|---|---|---|
| path_provider | 2.1.6 | Local filesystem paths |
| permission_handler | 11.4.0 | Runtime permissions |
| geolocator | 13.0.4 | Location metadata |
| device_info_plus | 11.5.0 | Device metadata |
| crypto | 3.0.7 | Cryptographic utilities (transitive) |
| uuid | 4.6.0 | Evidence identifier generation |

### UI and formatting

| Package | Locked version | Role |
|---|---|---|
| flutter_svg | 2.3.0 | Vector branding assets |
| intl | 0.20.3 | Date and time formatting |

### Not currently in project

The following packages were reviewed but are **not** present in `pubspec.yaml` or `pubspec.lock`:

| Package | Status |
|---|---|
| flutter_secure_storage | Not in project |
| share_plus | Not in project |
| image | Not in project (`image_picker` is used instead) |

---

## Connected Test Devices

### Primary development device (last verified)

| Property | Value |
|---|---|
| Device | Motorola moto g35 5G |
| Device ID | `ZA222V9Y3V` |
| Connection | USB debugging |
| Android version | 15 (API 35) |
| Architecture | android-arm64 |

This device was last detected successfully during active project development (`flutter devices`, `flutter run -d ZA222V9Y3V`).

### Current connection status (baseline capture)

At the time this baseline was established, the Motorola device was **not connected**. `flutter devices` reported:

- Windows (desktop)
- Chrome (web)
- Edge (web)

**To be confirmed:** Reconnect the Motorola device and verify with `flutter devices` before the next device-dependent sprint.

---

## Known Working Commands

Commands verified during baseline capture or prior validated development sessions on this machine.

| Command | Status | Notes |
|---|---|---|
| `flutter pub get` | Verified | Resolves dependencies successfully |
| `flutter doctor -v` | Verified | Android toolchain healthy; Visual Studio absent (Windows desktop builds not configured) |
| `flutter devices` | Verified | Lists available targets |
| `flutter test test/widget_test.dart test/onboarding_navigation_test.dart` | Verified | 7 tests passed (2026-07-29) |
| `flutter run -d ZA222V9Y3V` | Partially verified | Device detected and debug launch initiated; first `assembleDebug` Gradle build may take extended time |
| `flutter build apk --debug` | **To be confirmed.** | Not completed during baseline capture |

---

## Known Warnings

The following warnings are currently acceptable and do not block development.

### Kotlin Gradle Plugin (KGP) plugin warnings

During Android builds, Flutter may emit warnings that these plugins apply KGP in a way that may be incompatible with future Flutter versions:

- `camera_android_camerax`
- `device_info_plus`
- `record_android`

These are informational. Do not treat them as build failures unless Gradle actually fails.

### Package update notifications

`flutter pub get` reports that 29 packages have newer versions incompatible with current dependency constraints. This is expected. **Do not upgrade packages during feature development** unless a dedicated dependency sprint is approved.

### Flutter upgrade notification

Flutter may report that a newer stable version is available. The baseline intentionally pins the environment documented above. Do not upgrade Flutter during feature development without a dedicated environment sprint.

### Visual Studio not installed

`flutter doctor` reports Visual Studio is not installed. This affects Windows desktop builds only. Android development is unaffected.

---

## Engineering Rules

Permanent rules for Evidence Vault development:

1. **Never upgrade packages during feature development.** Dependency changes require a dedicated sprint and baseline update.
2. **Stabilize before optimizing.** Confirm builds and tests pass before performance or refactor work.
3. **One architectural change per sprint.** Avoid combining environment, dependency, and feature changes in the same sprint.
4. **Cursor Agent implements code only.** Environment execution and device verification are performed manually from the integrated terminal.
5. **Never let Cursor wait indefinitely for shell operations or screenshots.** Long-running commands (Gradle builds, device screenshots) should be run manually with explicit timeouts.
6. **Verify builds manually on the Motorola device.** Widget tests alone do not replace on-device verification.
7. **Do not delete Gradle caches unless troubleshooting specifically requires it.** Cache deletion is a recovery action, not routine maintenance.
8. **Do not modify Gradle, Flutter configuration, or dependencies** unless the sprint objective explicitly requires it.
9. **Consult `docs/LANGUAGE_SYSTEM.md` before changing user-facing copy.**
10. **Update this document** whenever the development environment changes intentionally.
11. **Freeze onboarding.** Do not redesign registration / login / name-collection unless usability testing shows measurable friction, accessibility requirements change, or authentication architecture changes. Invest in investigation workflows. See [`../DEVELOPMENT_GUIDELINES.md`](../DEVELOPMENT_GUIDELINES.md).
12. **Decision filter:** Before accepting a feature, ask: *Does this improve the investigation?* If not, challenge whether it belongs.

---

## Recovery Procedures

Concise recovery sequences for common issues encountered during development.

### Flutter build hangs

1. Stop the running terminal process (`Ctrl+C`).
2. Confirm no orphaned `java.exe` or `dart.exe` Gradle daemons remain (Task Manager if needed).
3. Re-run the command manually from the integrated terminal.
4. If the hang persists on first build, allow additional time for Gradle dependency download.
5. Do not delete Gradle caches unless the steps below for cache corruption apply.

### Gradle cache corruption

1. Stop all Gradle and Flutter build processes.
2. Run `flutter clean` from the project root.
3. Run `flutter pub get`.
4. Retry the build manually.
5. Only if failures persist: delete `%USERPROFILE%\.gradle\caches` as a last resort, then rebuild. Expect a long re-download.

### Device not detected

1. Confirm USB debugging is enabled on the Motorola device.
2. Reconnect the USB cable and accept the debugging authorization prompt on the device.
3. Run `flutter devices --device-timeout 30`.
4. If still missing, verify `adb devices` using `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
5. Restart ADB: `adb kill-server` then `adb start-server`.

### Low disk space

1. Check free space on `C:\` (project, Flutter SDK, Android SDK, and Gradle cache all reside here).
2. Run `flutter clean` to remove project build artifacts.
3. Avoid deleting Gradle or Android SDK caches unless troubleshooting requires it.
4. **To be confirmed:** Minimum free disk threshold for reliable Gradle builds on this machine.

### Stale Flutter lock / hung test or run process

1. Stop the terminal process (`Ctrl+C`).
2. End orphaned `dart.exe`, `java.exe`, or `gradle.exe` processes if they remain.
3. Delete `C:\Development\evidence_vault\.dart_tool\package_config.json` only if `flutter pub get` fails with lock errors — prefer `flutter pub get` first.
4. Re-run the intended command manually.

---

## Version History

| Version | Date | Summary |
|---|---|---|
| v1.0 | 29 July 2026 | Initial engineering baseline established from automated environment inspection |

---

*This document is the canonical development environment reference for Evidence Vault. Update it whenever the toolchain, SDK levels, or verified commands change.*
