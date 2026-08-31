import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/incident_overview_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'workspace_card.dart';

/// Presents a concise snapshot of what the incident currently contains.
///
/// Informational only — no analysis, charts, percentages, or progress bars.
/// Extension points reserved for timeline, AI insights, missing context,
/// reflection readiness, and export readiness.
class IncidentOverviewCard extends StatelessWidget {
  const IncidentOverviewCard({
    super.key,
    required this.summary,
  });

  final IncidentOverviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return WorkspaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSectionHeader(
            title: 'Incident Overview',
            caption: 'What this incident currently contains.',
          ),
          const SizedBox(height: AppSpacing.md),
          _OverviewRow(
            label: 'Evidence',
            value: summary.evidenceLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OverviewRow(
            label: 'Context',
            value: summary.contextLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OverviewRow(
            label: 'Linked Evidence',
            value: summary.linkedEvidenceLabel,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OverviewRow(
            label: 'Journey',
            value: summary.journeyLabel,
            emphasizeValue: true,
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.label,
    required this.value,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.label.copyWith(
              fontSize: 14,
              fontWeight: emphasizeValue ? FontWeight.w600 : FontWeight.w500,
              color: emphasizeValue ? AppColors.primary : AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
