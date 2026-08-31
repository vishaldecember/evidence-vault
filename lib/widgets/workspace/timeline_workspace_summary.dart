import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Read-only entry point to the dedicated Timeline Workspace.
class TimelineWorkspaceSummary extends StatelessWidget {
  const TimelineWorkspaceSummary({
    super.key,
    required this.timelineAnchorCount,
    required this.supportingEvidenceCount,
    this.onViewTimeline,
  });

  final int timelineAnchorCount;
  final int supportingEvidenceCount;
  final VoidCallback? onViewTimeline;

  static String summaryLabel({
    required int timelineAnchorCount,
    required int supportingEvidenceCount,
  }) {
    final anchorLabel = timelineAnchorCount == 1
        ? '1 Primary Evidence'
        : '$timelineAnchorCount Primary Evidence';
    final supportingLabel = supportingEvidenceCount == 1
        ? '1 additional evidence'
        : '$supportingEvidenceCount additional evidence';

    return '$anchorLabel • $supportingLabel';
  }

  @override
  Widget build(BuildContext context) {
    if (timelineAnchorCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.card(
        backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.55),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Timeline',
                  style: AppTextStyles.emphasisLabel.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ViewTimelineButton(onPressed: onViewTimeline),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            summaryLabel(
              timelineAnchorCount: timelineAnchorCount,
              supportingEvidenceCount: supportingEvidenceCount,
            ),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ViewTimelineButton extends StatelessWidget {
  const _ViewTimelineButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Timeline →',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
