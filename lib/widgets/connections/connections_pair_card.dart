import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/connections_presentation.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';
import '../timeline/timeline_evidence_labels.dart';
import '../workspace/living_evidence_preview.dart';

/// Structural or suggested evidence pair in Connections.
class ConnectionsPairCard extends StatelessWidget {
  const ConnectionsPairCard({
    super.key,
    required this.pair,
    required this.onEvidenceTap,
  });

  final ConnectionsPairView pair;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceTap;

  @override
  Widget build(BuildContext context) {
    final suggested = pair.isSuggested;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onEvidenceTap(pair.from),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: DecoratedBox(
          decoration: AppDecorations.card(
            backgroundColor: AppColors.background,
          ).copyWith(
            border: Border.all(
              color: suggested
                  ? AppColors.border
                  : AppColors.navy.withValues(alpha: 0.22),
              width: suggested ? 1 : 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (suggested)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      pair.confidence == null
                          ? 'Suggested'
                          : 'Suggested · ${(pair.confidence! * 100).round()}%',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                _EvidenceLine(
                  item: pair.from,
                  onTap: () => onEvidenceTap(pair.from),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Text(
                    suggested ? '↔' : '↓',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      color: suggested ? AppColors.textMuted : AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _EvidenceLine(
                  item: pair.to,
                  onTap: () => onEvidenceTap(pair.to),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  pair.label,
                  style: AppTextStyles.caption.copyWith(
                    color: suggested ? AppColors.textMuted : AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pair.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    pair.detail!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.item,
    required this.onTap,
  });

  final WorkspaceEvidenceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.isSupportingEvidence
        ? TimelineEvidenceLabels.supportingLabel(item)
        : TimelineEvidenceLabels.capturedLabel(item);
    final clock = WorkspaceEvidenceFormatters.evidenceClock(item.lastPreservedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: LivingEvidencePreview(
                      item: item,
                      uniformThumbnailSize: true,
                      suppressBorder: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.emphasisLabel,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clock,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
