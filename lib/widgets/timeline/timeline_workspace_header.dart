import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Header for the dedicated Timeline Workspace.
class TimelineWorkspaceHeader extends StatelessWidget {
  const TimelineWorkspaceHeader({
    super.key,
    required this.incidentName,
    required this.timelineAnchorCount,
    required this.supportingEvidenceCount,
    required this.relationshipGroupCount,
  });

  final String incidentName;
  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final int supportingEvidenceCount;

  static String anchorCountLabel(int count) {
    if (count == 1) {
      return '1 Primary Evidence';
    }
    return '$count Primary Evidence';
  }

  static String supportingCountLabel(int count) {
    if (count == 1) {
      return '1 additional evidence';
    }
    return '$count additional evidence';
  }

  static String groupCountLabel(int count) {
    if (count == 1) {
      return '1 Relationship Group';
    }
    return '$count Relationship Groups';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIncidentName = incidentName.trim().isEmpty
        ? 'Untitled Incident'
        : incidentName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Timeline Workspace', style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          resolvedIncidentName,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          anchorCountLabel(timelineAnchorCount),
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          supportingCountLabel(supportingEvidenceCount),
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          groupCountLabel(relationshipGroupCount),
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'What happened, and in what order?',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
