import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Entry point to the Investigation Workspace from the Incident Workspace.
class ReconstructionCanvasSummary extends StatelessWidget {
  const ReconstructionCanvasSummary({
    super.key,
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    this.onOpenReconstruction,
  });

  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final VoidCallback? onOpenReconstruction;

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
                  'Investigation Workspace',
                  style: AppTextStyles.emphasisLabel.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _OpenReconstructionButton(onPressed: onOpenReconstruction),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$timelineAnchorCount Primary Evidence • '
            '$relationshipGroupCount Relationship Groups',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _OpenReconstructionButton extends StatelessWidget {
  const _OpenReconstructionButton({this.onPressed});

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
        'Reconstruction →',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
