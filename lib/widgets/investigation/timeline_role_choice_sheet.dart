import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/evidence/evidence_temporal_intent.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_bottom_sheet.dart';

/// Quiet, skippable timeline-role choice from the Evidence Inspector.
class TimelineRoleChoiceSheet extends StatelessWidget {
  const TimelineRoleChoiceSheet({
    super.key,
    required this.prompt,
  });

  static const Key sheetKey = Key('timeline_role_choice_sheet');
  static const Key chronologicalKey = Key('timeline_role_choice_chronological');
  static const Key contextKey = Key('timeline_role_choice_context');
  static const Key skipKey = Key('timeline_role_choice_skip');

  final String prompt;

  static Future<EvidenceTemporalIntent?> open(
    BuildContext context, {
    required String prompt,
  }) {
    return showAppBottomSheet<EvidenceTemporalIntent>(
      context: context,
      builder: (context) => TimelineRoleChoiceSheet(prompt: prompt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetInsets(
      child: Column(
        key: sheetKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BottomSheetHandle(),
          const SizedBox(height: AppSpacing.md),
          Text(prompt, style: AppTextStyles.heading.copyWith(fontSize: 18)),
          const SizedBox(height: AppSpacing.md),
          _ChoiceRow(
            key: chronologicalKey,
            title: EvidenceInspectorSemantics.timelineRoleChronological,
            caption: EvidenceInspectorSemantics.timelineRoleChronologicalCaption,
            onTap: () => Navigator.of(context).pop(
              EvidenceTemporalIntent.chronological,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ChoiceRow(
            key: contextKey,
            title: EvidenceInspectorSemantics.timelineRoleContext,
            caption: EvidenceInspectorSemantics.timelineRoleContextCaption,
            onTap: () => Navigator.of(context).pop(
              EvidenceTemporalIntent.context,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: skipKey,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(EvidenceInspectorSemantics.timelineRoleSkip),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.label.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
