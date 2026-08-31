import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import 'capture_action_button.dart';

/// Horizontal capture action buttons (Photo, Video, Voice, Note, File).
class CaptureBar extends StatelessWidget {
  const CaptureBar({
    super.key,
    required this.activeMode,
    required this.onModeSelected,
    this.embedded = false,
    this.captureDisabled = false,
  });

  final WorkspaceCaptureMode? activeMode;
  final ValueChanged<WorkspaceCaptureMode> onModeSelected;

  /// When true, omits outer card decoration — used inside [ContinueCapturingSection].
  final bool embedded;

  /// When true, capture actions are temporarily disabled.
  final bool captureDisabled;

  static const _modes = WorkspaceCaptureMode.values;
  static const double _disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final bar = IgnorePointer(
      ignoring: captureDisabled,
      child: Opacity(
        opacity: captureDisabled ? _disabledOpacity : 1,
        child: Row(
          children: [
            for (var index = 0; index < _modes.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xs),
              CaptureActionButton(
                mode: _modes[index],
                isActive: activeMode == _modes[index],
                onTap: () => onModeSelected(_modes[index]),
              ),
            ],
          ],
        ),
      ),
    );

    if (embedded) {
      return bar;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: AppDecorations.captureLayerShadows,
      ),
      child: bar,
    );
  }
}
