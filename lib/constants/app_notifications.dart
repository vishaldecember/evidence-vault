/// Transient notification timing aligned with DESIGN_SYSTEM.md.
abstract final class AppNotifications {
  /// Legacy SnackBar duration — retained for short paths only.
  static const Duration errorDuration = Duration(seconds: 2);

  /// Premium auth MaterialBanner — long enough to read and act.
  static const Duration authBannerDuration = Duration(seconds: 8);

  /// Centred success confirmation — total ~900ms.
  static const Duration successAnimationDuration =
      Duration(milliseconds: 900);

  static const Duration successRingDuration = Duration(milliseconds: 500);

  static const Duration successCheckStart = Duration(milliseconds: 460);

  static const Duration successCheckEnd = Duration(milliseconds: 540);

  /// Hold with checkmark visible before fade (~250ms).
  static const Duration successFadeStart = Duration(milliseconds: 700);
}
