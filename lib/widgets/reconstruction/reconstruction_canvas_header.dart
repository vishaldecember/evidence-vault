import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/journey_stage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/status_badge.dart';

/// Incident summary header for the Reconstruction Canvas.
class ReconstructionCanvasHeader extends StatelessWidget {
  const ReconstructionCanvasHeader({
    super.key,
    required this.incidentName,
    required this.journeyStage,
    required this.relationshipGroupCount,
    required this.timelineAnchorCount,
    required this.primaryEvidenceCount,
  });

  final String incidentName;
  final JourneyStage journeyStage;
  final int relationshipGroupCount;
  final int timelineAnchorCount;
  final int primaryEvidenceCount;

  @override
  Widget build(BuildContext context) {
    final resolvedName = incidentName.trim().isEmpty
        ? 'Untitled Incident'
        : incidentName.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppDecorations.card(
        backgroundColor: AppColors.surfaceMuted.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            resolvedName,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                status: IncidentStatus.fromJourneyStage(journeyStage),
              ),
              _StatChip(
                label: 'Groups',
                value: '$relationshipGroupCount',
              ),
              _StatChip(
                label: 'Primary',
                value: '$timelineAnchorCount',
              ),
              _StatChip(
                label: 'Primary',
                value: '$primaryEvidenceCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
