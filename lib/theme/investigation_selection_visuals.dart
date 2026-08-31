import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Shared visual language for investigation selection across canvas segments.
abstract final class InvestigationSelectionVisuals {
  static const selectionColor = AppColors.primary;
  static const selectionDuration = AppMotion.medium;
  static const selectionCurve = AppMotion.enter;

  static const double timelineBorderWidth = 1.5;
  static const double narrativeBorderWidth = 3;
  static const double connectionsBorderWidth = 2;
}
