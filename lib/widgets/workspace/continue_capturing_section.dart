import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import 'capture_bar.dart';
import 'capture_section_header.dart';
import 'incident_identity_drawer.dart';

/// Capture actions for the workspace Action Layer (sticky, thumb-first).
class ContinueCapturingSection extends StatelessWidget {
  const ContinueCapturingSection({
    super.key,
    required this.activeMode,
    required this.onModeSelected,
    this.identityDrawer,
  });

  final WorkspaceCaptureMode? activeMode;
  final ValueChanged<WorkspaceCaptureMode> onModeSelected;

  /// Name Incident extension — top edge of the Capture card when set.
  final Widget? identityDrawer;

  @override
  Widget build(BuildContext context) {
    return _CaptureEvidenceCard(
      identityDrawer: identityDrawer,
      activeMode: activeMode,
      onModeSelected: onModeSelected,
    );
  }
}

/// Unified Capture card with optional Name Incident extension on top.
class _CaptureEvidenceCard extends StatelessWidget {
  const _CaptureEvidenceCard({
    this.identityDrawer,
    required this.activeMode,
    required this.onModeSelected,
  });

  final Widget? identityDrawer;
  final WorkspaceCaptureMode? activeMode;
  final ValueChanged<WorkspaceCaptureMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: AppDecorations.captureLayerShadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (identityDrawer != null)
            SizedBox(
              height: IncidentIdentityDrawer.collapsedTabHeight,
              child: identityDrawer!,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CaptureSectionHeader(),
                const SizedBox(height: AppSpacing.xs),
                CaptureBar(
                  activeMode: activeMode,
                  onModeSelected: onModeSelected,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
